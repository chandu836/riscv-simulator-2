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
        operand_size = 61;

        // Initializing caches with simple test data
//         dut.write_cacheA(0,  64'h7ABCDEF012345678);
// dut.write_cacheA(1,  64'h0123456789ABCDEF);
// dut.write_cacheA(2,  64'h1234567890ABCDEF);
// dut.write_cacheA(3,  64'h234567890ABCDEF0);
// dut.write_cacheA(4,  64'h34567890ABCDEF01);
// dut.write_cacheA(5,  64'h4567890ABCDEF012);
// dut.write_cacheA(6,  64'h567890ABCDEF0123);
// dut.write_cacheA(7,  64'h67890ABCDEF01234);
// dut.write_cacheA(8,  64'h7890ABCDEF012345);
// dut.write_cacheA(9,  64'h790ABCDEF0123456);
// dut.write_cacheA(10, 64'h70ABCDEF01234567);
// dut.write_cacheA(11, 64'h0ABCDEF012345678);
// dut.write_cacheA(12, 64'h1BCDEF0123456789);
// dut.write_cacheA(13, 64'h2CDEF01234567890);
// dut.write_cacheA(14, 64'h3DEF012345678901);
// dut.write_cacheA(15, 64'h4EF0123456789012);
// dut.write_cacheA(16, 64'h5F01234567890123);
// dut.write_cacheA(17, 64'h6012345678901234);
// dut.write_cacheA(18, 64'h7123456789012345);
// dut.write_cacheA(19, 64'h7234567890123456);
// dut.write_cacheA(20, 64'h7345678901234567);
// dut.write_cacheA(21, 64'h7456789012345678);
// dut.write_cacheA(22, 64'h7567890123456789);
// dut.write_cacheA(23, 64'h7678901234567890);
// dut.write_cacheA(24, 64'h7789012345678901);
// dut.write_cacheA(25, 64'h7890123456789012);
// dut.write_cacheA(26, 64'h7901234567890123);
// dut.write_cacheA(27, 64'h0123456789012345);
// dut.write_cacheA(28, 64'h1234567890123456);
// dut.write_cacheA(29, 64'h2345678901234567);
// dut.write_cacheA(30, 64'h3456789012345678);
// dut.write_cacheA(31, 64'h4567890123456789);
// dut.write_cacheA(32, 64'h5678901234567890);

// dut.write_cacheB(0,  64'h13579BDF02468ACE);
// dut.write_cacheB(1,  64'h2468ACE13579BDF0);
// dut.write_cacheB(2,  64'h3579BDF02468ACE1);
// dut.write_cacheB(3,  64'h468ACE13579BDF02);
// dut.write_cacheB(4,  64'h579BDF02468ACE13);
// dut.write_cacheB(5,  64'h68ACE13579BDF024);
// dut.write_cacheB(6,  64'h79BDF02468ACE135);
// dut.write_cacheB(7,  64'h7ACE13579BDF0246);
// dut.write_cacheB(8,  64'h7BDF02468ACE1357);
// dut.write_cacheB(9,  64'h7CE13579BDF02468);
// dut.write_cacheB(10, 64'h7DF02468ACE13579);
// dut.write_cacheB(11, 64'h7E13579BDF02468A);
// dut.write_cacheB(12, 64'h7F02468ACE13579B);
// dut.write_cacheB(13, 64'h713579BDF02468AC);
// dut.write_cacheB(14, 64'h702468ACE13579BD);
// dut.write_cacheB(15, 64'h02468ACE13579BDF);

// dut.write_cacheB(16, 64'h13579BDF02468ACE);
// dut.write_cacheB(17, 64'h2468ACE13579BDF0);
// dut.write_cacheB(18, 64'h3579BDF02468ACE1);
// dut.write_cacheB(19, 64'h468ACE13579BDF02);
// dut.write_cacheB(20, 64'h579BDF02468ACE13);
// dut.write_cacheB(21, 64'h68ACE13579BDF024);
// dut.write_cacheB(22, 64'h79BDF02468ACE135);
// dut.write_cacheB(23, 64'h7ACE13579BDF0246);
// dut.write_cacheB(24, 64'h7BDF02468ACE1357);
// dut.write_cacheB(25, 64'h7CE13579BDF02468);
// dut.write_cacheB(26, 64'h7DF02468ACE13579);
// dut.write_cacheB(27, 64'h7E13579BDF02468A);
// dut.write_cacheB(28, 64'h7F02468ACE13579B);
// dut.write_cacheB(29, 64'h713579BDF02468AC);
// dut.write_cacheB(30, 64'h702468ACE13579BD);
// dut.write_cacheB(31, 64'h02468ACE13579BDF);


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

        $display("Printing first 16 result words (hex, zero-padded):");
        for (i = 0; i < 128; i = i + 1) begin
            $display("res[%0d] = %016h", i, dut.read_result(i));
        end

        $display("Simulation finished.");
        $finish;
    end

endmodule
