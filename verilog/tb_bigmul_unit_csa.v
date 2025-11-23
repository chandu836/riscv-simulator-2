// tb_bigmul_unit_csa.v
`timescale 1ns/1ps
module tb_bigmul_unit_csa;

    reg clk;
    reg rstn;
    reg start;
    wire busy;
    wire compute_done;

    integer i;
    integer cycle_count;
    integer MAX_CYCLES;
    reg [31:0] operand_size;


    // Instantiate DUT
    bigmul_unit_csa dut (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .busy(busy),
        .compute_done(compute_done),
        .operand_size(operand_size)
    );

    initial begin
    $dumpfile("bigmul_unit.vcd");    // Name of the output VCD file
    $dumpvars(0, tb_bigmul_unit_vcd); // top_module is your testbench's top-level module
end

    // clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        MAX_CYCLES = 100000;
    end

    // stimulus
    initial begin
        // reset
        rstn = 0;
        start = 0;
        cycle_count = 0;
        #20;
        rstn = 1;
        #20;
        operand_size = 64;

        for (i = 0; i < 64; i = i + 1) begin
            dut.write_cacheA(i, 64'h7fffffffffffffff);           // A[i] = (i+1)
            dut.write_cacheB(i, 64'h7fffffffffffffff);     // B[i] = 2*(i+1)
        end
        for (i = 64; i < operand_size; i = i + 1) begin
            dut.write_cacheA(i, 64'h0);           // A[i] = (i+1)
            dut.write_cacheB(i, 64'h0);     // B[i] = 2*(i+1)
        end

        $display("cacheA[0..7] and cacheB[0..7] (zero padded):");
        for (i = 0; i < 8; i = i + 1) begin
            $display("A[%0d]=%016h  B[%0d]=%016h",
                     i, dut.cacheA[i], i, dut.cacheB[i]);
        end

        // pulse start
        #10;
        start = 1;
        #10;
        start = 0;

        // Count cycles until done, with watchdog
        cycle_count = 0;
        while (compute_done == 0) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (cycle_count > MAX_CYCLES) begin
                $display("ERROR: Timeout after %0d cycles. Aborting simulation.", cycle_count);
                $finish;
            end
        end

        $display("--------------------------------------------------");
        $display(" BIGMUL FINISHED in %0d cycles", cycle_count);
        $display("--------------------------------------------------");

        $display("Printing first result dwords:");
        for (i = 0; i < 128; i = i + 1) begin
            $display("res[%0d] = %016h", i, dut.read_result(i));
        end

        $display("Simulation finished.");
        $finish;
    end

endmodule
