`timescale 1ns/1ps
module bigmul_unit_csa (
    input  wire        clk,
    input  wire        rstn,        // active low reset
    input  wire        start,       // pulse to start
    output reg         busy,        // true while computing
    output reg         compute_done, // true when computation is done
    input  wire [31:0] operand_size  // in dwords
);

    localparam BATCH = 25;
    localparam NWORDS = 64;
    localparam NDIAGS = 128;
    localparam TOTAL_PARTIALS = NWORDS * NWORDS;

    // caches (64 x 64b)
    reg [63:0] cacheA [0:NWORDS-1];
    reg [63:0] cacheB [0:NWORDS-1];

    // result cache 128 x 64b
    reg [63:0] resultCache [0:NDIAGS-1];

    // accumulator 192-bit: acc2:acc1:acc0 (high->low)
    reg [63:0] acc0, acc1, acc2;


    // diagonal computation control
    integer s_diag;
    integer i_min, i_max;
    integer k_iter; // next i to process for current diagonal

    integer produced_total; // number of partial products generated in total
    integer retired_total;  // number of partial products that have been merged

    // helpers for accumulation
    task acc_clear; begin acc0 = 0; acc1 = 0; acc2 = 0; end endtask
    task acc_shr_64; begin acc0 = acc1; acc1 = acc2; acc2 = 64'h0; end endtask

    task acc_add_u192(input [63:0] lo, input [63:0] hi, input [63:0] hi2);
        // add 192-bit value (hi2:hi:lo) to acc2:acc1:acc0
        reg [191:0] old;
        reg [191:0] sum;
        begin
            old = {acc2, acc1, acc0};
            sum = old + {hi2, hi, lo};
            acc0 = sum[63:0];
            acc1 = sum[127:64];
            acc2 = sum[191:128];
        end
    endtask

    // TB helper tasks
    task write_cacheA(input integer addr, input [63:0] val);
    begin
        if (addr >= 0 && addr < NWORDS) cacheA[addr] = val;
    end
    endtask

    task write_cacheB(input integer addr, input [63:0] val);
    begin
        if (addr >= 0 && addr < NWORDS) cacheB[addr] = val;
    end
    endtask

    function [63:0] read_result(input integer addr);
    begin
        if (addr >= 0 && addr < NDIAGS) read_result = resultCache[addr];
        else read_result = 64'hx;
    end
    endfunction

    integer i, j, t;
    initial begin
        // zero memories and state for begining
        for (i = 0; i < NWORDS; i = i + 1) begin
            cacheA[i] = 64'h0;
            cacheB[i] = 64'h0;
        end
        for (i = 0; i < NDIAGS; i = i + 1) resultCache[i] = 64'h0;
        acc_clear();
        s_diag = 0; i_min = 0; i_max = 0; k_iter = 0;
        busy = 0; compute_done = 0;
        produced_total = 0; retired_total = 0;
    end

    reg [63:0] Ai; reg [63:0] Bj;
    reg [127:0] prod;
    reg [127:0] t0;
    reg [127:0] t1;
    reg [63:0] c1;
    reg [63:0] c0;
    reg [63:0] lo; reg [63:0] hi;
    // Main sequential behavior: at each posedge if busy: do up to BATCH GEN+LOAD+MUL and update accumulator.
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            acc_clear();
            s_diag <= 0; i_min <= 0; i_max <= 0; k_iter <= 0;
            busy <= 0; compute_done <= 0;
            produced_total <= 0; retired_total <= 0;
            for (i = 0; i < NDIAGS; i = i + 1) resultCache[i] <= 64'h0;
        end else begin
            // start pulse: initialize
            if (start && !busy) begin
                s_diag <= 0;
                i_min <= 0; i_max <= 0; // only (0,0)
                k_iter <= 0;
                acc_clear();
                busy <= 1;
                compute_done <= 0;
                produced_total <= 0;
                retired_total <= 0;
                // clear resultCache
                for (i = 0; i < NDIAGS; i = i + 1) resultCache[i] <= 64'h0;
            end

            if (!busy) begin
                // idle
            end else begin
                // Process up to BATCH pairs for current diagonal
                integer processed;
                reg [63:0] b0; reg [63:0] b1; reg [63:0] b2;
                processed = 0;
                b0 = 64'h0; b1 = 64'h0; b2 = 64'h0;
                while ((processed < BATCH) && (k_iter <= i_max)) begin
                    integer ii, jj;
                    ii = k_iter;
                    jj = s_diag - ii;
                    // load
                    
                    Ai = cacheA[ii];
                    Bj = cacheB[jj];

                    // 64x64 -> 128
                    
                    prod = Ai * Bj;
                    
                    lo = prod[63:0];
                    hi = prod[127:64];

                    // add to local 192-bit b2:b1:b0
                    // b0 += lo
                    
                    t0 = ( {64'h0, b0} + {64'h0, lo} );
                    b0 = t0[63:0];
                    
                    c0 = t0[127:64];

                    // b1 += hi + c0
                    
                    t1 = ( {64'h0, b1} + {64'h0, hi} + {127'h0, c0} );
                    b1 = t1[63:0];
                    
                    c1 = t1[127:64];

                    b2 = b2 + c1;

                    // move to next diagonal
                    k_iter = k_iter + 1;
                    processed = processed + 1;
                    produced_total = produced_total + 1;
                end

                
                if (processed > 0) begin
                    acc_add_u192(b0, b1, b2);
                    retired_total = retired_total + processed;
                end

                // Check if current diagonal finished
                if (k_iter > i_max) begin
                    resultCache[s_diag] <= acc0;
                    acc_shr_64();

                    // check final diagonal condition
                    if (s_diag == operand_size*2) begin
                        resultCache[2*operand_size + 1] <= acc0;
                        busy <= 0;
                        compute_done <= 1;
                    end else begin
                        s_diag <= s_diag + 1;
                        // computing i_min/i_max for next diag
                        if ((s_diag + 1) > operand_size-1) i_min <= (s_diag + 1) - (operand_size-1); else i_min <= 0;
                        if ((s_diag + 1) < operand_size-1) i_max <= s_diag + 1; else i_max <= (operand_size-1);
                        // set k_iter to i_min for next diagonal
                        k_iter <= ((s_diag + 1) > (operand_size-1)) ? ((s_diag + 1) - (operand_size-1)) : 0;
                    end
                end
            end
        end
    end

endmodule
