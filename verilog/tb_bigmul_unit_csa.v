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

    // Instantiate DUT
    bigmul_unit_csa dut (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .busy(busy),
        .compute_done(compute_done)
    );

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

        // Initializing caches with simple test data
        for (i = 0; i < 64; i = i + 1) begin
            dut.write_cacheA(i, 64'h7FFFFFFFFFFFFFFF);           // A[i] = (i+1)
            dut.write_cacheB(i, 64'h7FFFFFFFFFFFFFFF);     // B[i] = 2*(i+1)
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

        $display("Printing first 16 result words (hex, zero-padded):");
        for (i = 0; i < 128; i = i + 1) begin
            $display("res[%0d] = %016h", i, dut.read_result(i));
        end

        $display("Simulation finished.");
        $finish;
    end

endmodule
