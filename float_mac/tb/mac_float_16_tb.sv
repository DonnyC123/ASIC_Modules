`timescale 1ns / 1ps

module tb_mac_float;

  import float_16_tb_pkg::*;

  localparam PIPELINE_STAGES = 4;

  logic [FLOAT_W-1:0] a, b, c;
  logic [FLOAT_W-1:0] z;
  logic               clk;

  mac_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) dut (
      .clk(clk),
      .a  (a),
      .b  (b),
      .c  (c),
      .z  (z)
  );

  real real_a, real_b, real_c, real_z_dut, real_z_ref;
  integer i;
  integer errors = 0;

  task check_result(input string name);
    real                expected;
    logic [FLOAT_W-1:0] expected_bits;
    logic [FLOAT_W-1:0] diff;
    bit                 check_pass;

    real_a        = upscale_to_double(a);
    real_b        = upscale_to_double(b);
    real_c        = upscale_to_double(c);

    expected      = (real_a * real_b) + real_c;
    expected_bits = downscale_double(expected);

    repeat (PIPELINE_STAGES) @(posedge clk);
    #0.1;

    real_z_dut = upscale_to_double(z);
    real_z_ref = upscale_to_double(expected_bits);

    check_pass = 0;

    if ((real_z_dut == 0.0 && real_z_ref == 0.0) || (real_z_dut == real_z_ref) || (is_nan(
            real_z_dut
        ) && is_nan(
            real_z_ref
        ))) begin
      check_pass = 1;
    end else begin
      check_pass = 0;
    end

    if (!check_pass) begin
      $error("[%s] FAIL: A=%f B=%f C=%f | DUT=%f (0x%h) REF=%f (0x%h)", name, real_a, real_b,
             real_c, real_z_dut, z, real_z_ref, expected_bits);
      errors++;
      $stop();
    end else begin
    end
  endtask

  initial clk = 0;
  always #PIPELINE_STAGES clk = ~clk;

  initial begin
    $display("=== STARTING PARAMETERIZED MAC TEST (Exp=%0d, Frac=%0d) ===", EXP_W, FRAC_W);

    a = downscale_double(1.5);
    b = downscale_double(2.0);
    c = downscale_double(0.0);

    check_result("Simple Mult");

    a = downscale_double(1.0);
    b = downscale_double(1.0);
    c = downscale_double(3.5);

    check_result("Simple Add");

    a = 16'h6B6b;
    b = 16'h0801;
    c = 16'h01AB;

    check_result("Previous Error 1");

    a = 16'hEDCD;
    b = 16'h8000;
    c = 16'h0679;

    check_result("Previous Error 2");

    $display("--- Random Stress Test ---");
    for (i = 0; i < 100000000; i++) begin
      void'(std::randomize(a, b, c));

      if (i % 10 == 0) c = 0;
      if (i % 100000 == 0) $display("Test Case %0d", i);
      check_result($sformatf("Rand #%0d", i));
    end

    $display("=== TEST COMPLETED. Total Errors: %0d ===", errors);
    $finish;
  end

endmodule
