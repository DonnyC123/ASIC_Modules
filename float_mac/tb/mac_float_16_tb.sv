`timescale 1ns / 1ps

module tb_mac_float;

  import float_16_tb_pkg::*;

  localparam EXP_W   = 5;
  localparam FRAC_W  = 10;
  localparam FLOAT_W = EXP_W + FRAC_W + 1;

  localparam PIPELINE_STAGES = 4;

  logic               clk;
  logic               rst_n;
  logic [FLOAT_W-1:0] a;
  logic [FLOAT_W-1:0] b;
  logic [FLOAT_W-1:0] c;
  logic [FLOAT_W-1:0] z;

  mac_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) dut (
      .clk(clk),
      // .rst_n(rst_n),
      .a  (a),
      .b  (b),
      .c  (c),
      .z  (z)
  );

  logic   [FLOAT_W-1:0] expected_queue[$];
  string                name_queue    [$];

  integer               i;
  integer               errors = 0;

  initial clk = 0;
  always #5 clk = ~clk;

  task send_stimulus(input string name, input logic [FLOAT_W-1:0] test_a,
                     input logic [FLOAT_W-1:0] test_b, input logic [FLOAT_W-1:0] test_c);
    real real_a, real_b, real_c, expected;
    logic [FLOAT_W-1:0] expected_bits;

    real_a        = upscale_to_double(test_a);
    real_b        = upscale_to_double(test_b);
    real_c        = upscale_to_double(test_c);

    expected      = (real_a * real_b) + real_c;
    expected_bits = downscale_double(expected);

    expected_queue.push_back(expected_bits);
    name_queue.push_back(name);

    a = test_a;
    b = test_b;
    c = test_c;

    @(posedge clk);
  endtask

  initial begin : checker_thread
    logic  [FLOAT_W-1:0] expected_bits;
    string               test_name;
    real real_z_dut, real_z_ref;
    bit check_pass;

    forever begin
      @(posedge clk);

      if (expected_queue.size() > PIPELINE_STAGES) begin

        expected_bits = expected_queue.pop_front();
        test_name     = name_queue.pop_front();

        real_z_dut    = upscale_to_double(z);
        real_z_ref    = upscale_to_double(expected_bits);

        check_pass    = 0;
        if ((real_z_dut == 0.0 && real_z_ref == 0.0) || (real_z_dut == real_z_ref) || (is_nan(
                real_z_dut
            ) && is_nan(
                real_z_ref
            ))) begin
          check_pass = 1;
        end

        if (!check_pass) begin
          $error("[%s] FAIL: DUT=%f (0x%h) REF=%f (0x%h)", test_name, real_z_dut, z, real_z_ref,
                 expected_bits);
          errors++;
          $stop();
        end
      end
    end
  end

  initial begin
    $display("=== STARTING PIPELINED MAC TEST (Exp=%0d, Frac=%0d) ===", EXP_W, FRAC_W);

    rst_n = 0;
    a     = 0;
    b     = 0;
    c     = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    send_stimulus("Simple Mult", downscale_double(1.5), downscale_double(2.0), downscale_double(0.0
                  ));
    send_stimulus("Simple Add", downscale_double(1.0), downscale_double(1.0), downscale_double(3.5
                  ));

    send_stimulus("Previous Error 1", 16'h6B6b, 16'h0801, 16'h01AB);
    send_stimulus("Previous Error 2", 16'hEDCD, 16'h8000, 16'h0679);

    $display("--- Random Stress Test ---");
    for (i = 0; i < 1000000; i++) begin
      logic [FLOAT_W-1:0] rand_a, rand_b, rand_c;
      void'(std::randomize(rand_a, rand_b, rand_c));

      if (i % 10 == 0) rand_c = 0;

      if (i % 10000000 == 0) $display("Driving Test Case %0d...", i);

      send_stimulus($sformatf("Rand #%0d", i), rand_a, rand_b, rand_c);
    end

    repeat (PIPELINE_STAGES + 2) @(posedge clk);

    if (errors == 0 && expected_queue.size() == 0) begin
      $display("=== SUCCESS! ALL TESTS PASSED ===");
    end else begin
      $display("=== TEST COMPLETED. Total Errors: %0d (Unchecked items: %0d) ===", errors,
               expected_queue.size());
    end

    $finish;
  end

endmodule
