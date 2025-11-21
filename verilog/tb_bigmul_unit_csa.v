// tb_bigmul_unit_csa.v
`timescale 1ns/1ps

module tb_bigmul_unit_csa();

    reg clk, rst_n, start;
    wire busy, done;
    wire [63:0] cycles_out;

    bigmul_unit_csa #(.NUM_LIMBS(64), .PARALLEL(25)) uut(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .busy(busy),
        .done(done),
        .cycles_out(cycles_out)
    );

    integer i;

    // clock: 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; start = 0;
        #20 rst_n = 1;

        // Clear operands
        for (i = 0; i < 64; i = i + 1) begin
            uut.A[i] = 64'd0;
            uut.B[i] = 64'd0;
        end

        // Simple test: A = large number (limb0 = all 1s, limb1 = 1)
        // B = small (16)
        for (i = 0; i<64; i = i + 1) begin
            uut.A[i] = 64'h7fffffffffffffff;
            uut.B[i] = 64'h7fffffffffffffff;
        end

        #20;
        $display("TB: asserting start at time %0t", $time);
        start = 1;
        #10 start = 0;

        wait(done);

        #10;
        $display("TB: BIGMUL done. cycles_out = %0d", cycles_out);
        $display("TB: result limbs R[0..15]:");
        for (i = 0; i < 16; i = i + 1) begin
            $display("R[%0d] = 0x%016x", i, uut.R[i]);
        end

        $finish;
    end

endmodule
