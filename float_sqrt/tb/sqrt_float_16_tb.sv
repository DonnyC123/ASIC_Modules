`timescale 1ns / 1ps

module tb_root_float;

  import float_16_tb_pkg::*;

  localparam EXP_W  = 5;
  localparam FRAC_W = 10;
  localparam DATA_W = EXP_W + FRAC_W + 1;

  logic              clk;
  logic              rst_n;
  logic              rad_valid_i;
  logic [DATA_W-1:0] rad_i;
  logic [DATA_W-1:0] root_o;
  logic              root_valid_o;

  root_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) dut (
      .clk         (clk),
      .rst_n       (rst_n),
      .rad_valid_i (rad_valid_i),
      .rad_i       (rad_i),
      .root_o      (root_o),
      .root_valid_o(root_valid_o)
  );

  real real_rad, real_root_dut, real_root_ref;
  integer i;
  integer errors = 0;

  initial clk = 0;
  always #5 clk = ~clk;

  task check_result(input string name, input logic [DATA_W-1:0] test_val);
    real               expected;
    logic [DATA_W-1:0] expected_bits;
    bit                check_pass;
    int                timeout;

    @(posedge clk);
    rad_i       = test_val;
    rad_valid_i = 1'b1;
    @(posedge clk);
    rad_valid_i = 1'b0;

    real_rad    = upscale_to_double(test_val);

    if (real_rad < 0.0) begin
      expected = -1.0;
    end else begin
      expected = $sqrt(real_rad);
    end
    expected_bits = downscale_double(expected);

    timeout       = 0;
    while (!root_valid_o && timeout < 100) begin
      @(posedge clk);
      timeout++;
    end

    if (timeout >= 100) begin
      $error("[%s] FAIL: Timeout waiting for root_valid_o!", name);
      errors++;
      return;
    end

    // 4. Extract DUT Result and Compare
    real_root_dut = upscale_to_double(root_o);
    real_root_ref = upscale_to_double(expected_bits);

    check_pass    = 0;

    // Check conditions: Exact 0.0, Exact Match, or Both are NaN
    if ((real_root_dut == 0.0 && real_root_ref == 0.0) || 
        (real_root_dut == real_root_ref) || 
        (is_nan(
            real_root_dut
        ) && (is_nan(
            real_root_ref
        ) || real_rad < 0.0))) begin
      check_pass = 1;
    end

    if (!check_pass) begin
      $error("[%s] FAIL: RAD=%f | DUT=%f (0x%h) REF=%f (0x%h)", name, real_rad, real_root_dut,
             root_o, real_root_ref, expected_bits);
      errors++;
      $stop();
    end else begin
    end
  endtask

  initial begin
    $display("=== STARTING PARAMETERIZED SQRT TEST (Exp=%0d, Frac=%0d) ===", EXP_W, FRAC_W);

    rst_n       = 0;
    rad_valid_i = 0;
    rad_i       = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    // Explicit Basic Tests
    check_result("Sqrt(4.0)", downscale_double(4.0));
    check_result("Sqrt(2.0)", downscale_double(2.0));
    check_result("Sqrt(0.25)", downscale_double(0.25));
    check_result("Sqrt(0.0)", downscale_double(0.0));
    check_result("Sqrt(-1.0)", downscale_double(-1.0));

    check_result("Hex 0x3C00 (1.0)", 16'h3C00);

    $display("--- Random Stress Test ---");
    for (i = 0; i < 100000; i++) begin
      logic [DATA_W-1:0] rand_val;
      void'(std::randomize(rand_val));

      if (i % 10 != 0) begin
        rand_val[DATA_W-1] = 1'b0;
      end

      if (i % 10000 == 0) $display("Processing Test Case %0d...", i);
      check_result($sformatf("Rand #%0d", i), rand_val);
    end

    if (errors == 0) begin
      $display("=== SUCCESS! ALL TESTS PASSED ===");
    end else begin
      $display("=== TEST COMPLETED. Total Errors: %0d ===", errors);
    end
    $finish;
  end

endmodule
