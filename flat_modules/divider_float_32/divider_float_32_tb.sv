`timescale 1ns / 1ps

module divider_float_tb;

  import float_32_tb_pkg::*;

  logic clk;
  logic rst_n;

  logic [FLOAT_W-1:0] a, b;
  logic [FLOAT_W-1:0] z;
  logic               start;
  logic               z_valid;

  divider_float_32_top divider_float_inst (
      .clk    (clk),
      .clk_en (1'b1),
      .rst_n  (rst_n),
      .start_i(start),
      .a      (a),
      .b      (b),
      .z      (z),
      .z_valid(z_valid)
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

    expected      = (real_a / real_b);
    expected_bits = downscale_double(expected);

    start <= 1;
    @(posedge clk);
    start <= 0;
    @(posedge clk);

    wait (z_valid == 1'b1);

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

    @(posedge clk);

  endtask

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    start = 0;
    repeat (3) @(posedge clk);
    rst_n = 1;
    repeat (1) @(posedge clk);

    $display("=== STARTING PARAMETERIZED DIVIDER TEST (Exp=%0d, Frac=%0d) ===", EXP_W, FRAC_W);

    a = downscale_double(1.5);
    b = downscale_double(2.0);

    check_result("Test Divide 1");

    a = downscale_double(1.0);
    b = downscale_double(1.0);

    check_result("Test Divide 2");

    a = 32'h6B6b;
    b = 32'h0801;

    check_result("Test Divide 3");

    a = 32'hEDCD;
    b = 32'h8000;

    check_result("Test Divide 4");

    a = 32'hBBFF;
    b = 32'h7400;

    check_result("Test Divide 5");

    a = 32'h626F;
    b = 32'h7aef;

    check_result("Past Error Case 1");

    $display("--- Random Stress Test ---");
    for (i = 0; i < 100000000; i++) begin
      void'(std::randomize(a, b));

      if (i % 100000 == 0) $display("Test Case %0d", i);
      check_result($sformatf("Rand #%0d", i));
    end

    $display("=== TEST COMPLETED. Total Errors: %0d ===", errors);
    $finish;
  end

endmodule
