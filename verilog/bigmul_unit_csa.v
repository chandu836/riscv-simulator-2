// bigmul_unit_csa.v
// 4096-bit BIGMUL accelerator (Verilog-2001, Icarus compatible)
// Implements a full CSA tree reduction of partial products.
// - NUM_LIMBS limbs of 64 bits (4096-bit operands)
// - PARALLEL partial 64x64 multipliers per cycle
// Interface: clk, rst_n, start, busy, done, cycles_out
`timescale 1ns/1ps

module bigmul_unit_csa #(
    parameter NUM_LIMBS = 64,
    parameter PARALLEL  = 25
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output reg  busy,
    output reg  done,
    output reg [63:0] cycles_out
);

    // Memories
    reg [63:0] A [0:NUM_LIMBS-1];
    reg [63:0] B [0:NUM_LIMBS-1];
    reg [63:0] R [0:(2*NUM_LIMBS)-1];

    // FSM states
    reg [1:0] state, next_state;
    localparam S_IDLE   = 2'b00;
    localparam S_DIAG   = 2'b01;
    localparam S_GROUP  = 2'b10;
    localparam S_FIN   = 2'b11;

    // diag indices and counters
    integer diag;
    integer i_min, i_max;
    integer products_in_diag;
    integer idx_in_diag;

    // partial products and operand reduction
    // Each partial product is 128-bit (64x64)
    reg [127:0] prod [0:PARALLEL-1];

    // operands list for CSA reduction (max partials per diagonal = NUM_LIMBS)
    // We keep capacity NUM_LIMBS (<=64)
    reg [127:0] operands [0:NUM_LIMBS-1];
    integer operand_count;

    // Cycle counter
    reg [63:0] cycle_count;

    // loop indices, temporaries
    integer p, k, i, j;
    reg [127:0] a, b, c, sum128, carry128, tmp128;
    reg [127:0] two_op_sum;

    // Synchronous registers + cycle counting
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 0;
            done <= 0;
            cycles_out <= 0;
            cycle_count <= 0;
            diag <= 0;
            idx_in_diag <= 0;
            operand_count <= 0;
            // clear memories
            for (i = 0; i < NUM_LIMBS; i = i + 1) begin
                A[i] <= 64'd0;
                B[i] <= 64'd0;
            end
            for (i = 0; i < 2*NUM_LIMBS; i = i + 1) R[i] <= 64'd0;
        end else begin
            state <= next_state;
            // increment cycle counter if busy (in operation)
            if (state != S_IDLE) cycle_count <= cycle_count + 1;
            // else keep cycle_count until start resets it in IDLE handling
        end
    end

    // Next-state logic (simple)
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: if (start) next_state = S_DIAG;
            S_DIAG: next_state = S_GROUP;
            S_GROUP: begin
                // if groups completed and all partials produced and operand_count reduced to <=2,
                // move to FIN when last diag done. We handle transitions inside sequential always as
                // combinationally computing next_state is tricky with variables updated in seq block.
                // Keep simple: move to DIAG repeatedly until diag finishes, and FIN at end via seq.
                next_state = S_GROUP;
            end
            S_FIN: next_state = S_IDLE;
        endcase
    end

    // Main behavior: compute products, CSA reduce, final CPA add into R
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // initialization already done above
        end else begin
            case (state)
                // ---------------- IDLE ----------------
                S_IDLE: begin
                    done <= 0;
                    busy <= 0;
                    cycles_out <= cycle_count;
                    // when start asserted, initialize
                    if (start) begin
                        busy <= 1;
                        cycle_count <= 1;
                        diag <= 0;
                        idx_in_diag <= 0;
                        operand_count <= 0;
                        // clear result
                        for (i = 0; i < 2*NUM_LIMBS; i = i + 1) R[i] <= 64'd0;
                    end
                end

                // ---------------- DIAG ----------------
                S_DIAG: begin
                    // compute i_min and i_max for this diagonal
                    if (diag >= (NUM_LIMBS - 1)) i_min = diag - (NUM_LIMBS - 1);
                    else i_min = 0;
                    if (diag <= (NUM_LIMBS - 1)) i_max = diag;
                    else i_max = NUM_LIMBS - 1;
                    products_in_diag = i_max - i_min + 1;
                    idx_in_diag <= 0;
                    operand_count <= 0; // start fresh for this diagonal
                end

                // ---------------- GROUP ----------------
                S_GROUP: begin
                    integer remaining, group_size;
                    // determine remaining partials for this diagonal
                    if (diag >= (NUM_LIMBS - 1)) i_min = diag - (NUM_LIMBS - 1);
                    else i_min = 0;
                    if (diag <= (NUM_LIMBS - 1)) i_max = diag;
                    else i_max = NUM_LIMBS - 1;
                    products_in_diag = i_max - i_min + 1;
                    remaining = products_in_diag - idx_in_diag;
                    if (remaining <= 0) group_size = 0;
                    else if (remaining > PARALLEL) group_size = PARALLEL;
                    else group_size = remaining;

                    // compute up to PARALLEL partial products this cycle
                    for (p = 0; p < group_size; p = p + 1) begin
                        k = idx_in_diag + p;
                        i = i_min + k;
                        j = diag - i;
                        prod[p] = A[i] * B[j];
                    end
                    for (p = group_size; p < PARALLEL; p = p + 1)
                        prod[p] = 128'd0;

                    // append the new prods to operands list
                    for (p = 0; p < group_size; p = p + 1) begin
                        operands[operand_count + p] <= prod[p];
                    end
                    operand_count <= operand_count + group_size;
                    idx_in_diag <= idx_in_diag + group_size;

                    // Perform CSA reduction fully (reduce until <= 2 operands)
                    // Repeat while operand_count >= 3: take first 3 operands and replace with sum and carry<<1
                    while (operand_count >= 3) begin
                        // take first three
                        a = operands[0];
                        b = operands[1];
                        c = operands[2];

                        sum128  = a ^ b ^ c;
                        carry128 = ((a & b) | (b & c) | (a & c)) << 1;

                        // shift remaining operands down by 3 positions
                        for (i = 3; i < operand_count; i = i + 1) begin
                            operands[i-3] <= operands[i];
                        end
                        // place sum and carry at end
                        operands[operand_count-3] <= sum128;
                        operands[operand_count-2] <= carry128;
                        operand_count = operand_count - 1; // 3 -> 2 reduces count by 1
                    end

                    // If we have finished producing all partials for this diagonal
                    if (idx_in_diag >= products_in_diag) begin
                        // Now operand_count is <= 2 (by reduction above)
                        if (operand_count == 0) begin
                            // nothing to add
                        end else if (operand_count == 1) begin
                            // add single operand into result R at limb diag
                            // operand is 128-bit -> split into 3 chunks of 64 bits (low, mid, high)
                            reg [63:0] chunk0, chunk1, chunk2;
                            reg [127:0] sum128a;
                            reg [63:0] carry64;
                            chunk0 = operands[0][63:0];
                            chunk1 = operands[0][127:64];
                            chunk2 = 64'd0; // should be zero for 128-bit, but keep generic

                            // add chunk0 to R[diag]
                            sum128a = {64'd0, R[diag]} + {64'd0, chunk0};
                            R[diag] <= sum128a[63:0];
                            carry64 = sum128a[127:64];

                            // add chunk1 + carry to R[diag+1]
                            sum128a = {64'd0, R[diag+1]} + {64'd0, chunk1} + {64'd0, carry64};
                            R[diag+1] <= sum128a[63:0];
                            carry64 = sum128a[127:64];

                            // add chunk2 + carry to R[diag+2]
                            sum128a = {64'd0, R[diag+2]} + {64'd0, chunk2} + {64'd0, carry64};
                            R[diag+2] <= sum128a[63:0];
                            carry64 = sum128a[127:64];

                            // propagate carry if any
                            i = diag + 3;
                            while (carry64 != 0 && i < 2*NUM_LIMBS) begin
                                sum128a = {64'd0, R[i]} + {64'd0, carry64};
                                R[i] <= sum128a[63:0];
                                carry64 = sum128a[127:64];
                                i = i + 1;
                            end
                        end else begin
                            // operand_count == 2: final CPA then add into R
                            reg [255:0] final_sum;
                            reg [63:0] chunk0, chunk1, chunk2, carry64;
                            final_sum = operands[0] + operands[1]; // up to 129 bits but stored in 256 for safety

                            chunk0 = final_sum[63:0];
                            chunk1 = final_sum[127:64];
                            chunk2 = final_sum[191:128]; // possibly zero
                            carry64 = 64'd0;

                            // add chunk0 to R[diag]
                            sum128 = {64'd0, R[diag]} + {64'd0, chunk0};
                            R[diag] <= sum128[63:0];
                            carry64 = sum128[127:64];

                            // add chunk1 + carry to R[diag+1]
                            sum128 = {64'd0, R[diag+1]} + {64'd0, chunk1} + {64'd0, carry64};
                            R[diag+1] <= sum128[63:0];
                            carry64 = sum128[127:64];

                            // add chunk2 + carry to R[diag+2]
                            sum128 = {64'd0, R[diag+2]} + {64'd0, chunk2} + {64'd0, carry64};
                            R[diag+2] <= sum128[63:0];
                            carry64 = sum128[127:64];

                            // propagate carry
                            i = diag + 3;
                            while (carry64 != 0 && i < 2*NUM_LIMBS) begin
                                sum128 = {64'd0, R[i]} + {64'd0, carry64};
                                R[i] <= sum128[63:0];
                                carry64 = sum128[127:64];
                                i = i + 1;
                            end
                        end

                        // finished this diagonal: advance or finish all diagonals
                        if (diag < (2*NUM_LIMBS - 2)) begin
                            diag <= diag + 1;
                            idx_in_diag <= 0;
                            operand_count <= 0;
                        end else begin
                            // final diagonal done
                            state <= S_FIN;
                        end
                    end
                    // else: more groups remain for this diagonal; remain in S_GROUP and continue next cycle
                end // S_GROUP

                // ---------------- FIN ----------------
                S_FIN: begin
                    busy <= 0;
                    done <= 1;
                    cycles_out <= cycle_count;
                    // go back to IDLE (state update will handle)
                end

            endcase
        end
    end // always

endmodule
