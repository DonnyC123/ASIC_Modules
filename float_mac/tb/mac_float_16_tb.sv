`timescale 1ns / 1ps

module tb_mac_float;

  import float_16_tb_pkg::*;

  localparam EXP_W   = 5;
  localparam FRAC_W  = 10;
  localparam FLOAT_W = EXP_W + FRAC_W + 1;

  localparam PIPELINE_STAGES = 4;

  logic clk;
  logic rst_n;
  logic valid_i;
  logic [FLOAT_W-1:0] a, b, c;
  logic               valid_o;
  logic [FLOAT_W-1:0] z;

  mac_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) dut (
      .clk    (clk),
      .rst_n  (rst_n),
      .valid_i(valid_i),
      .a      (a),
      .b      (b),
      .c      (c),
      .valid_o(valid_o),
      .z      (z)
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

    a       = test_a;
    b       = test_b;
    c       = test_c;
    valid_i = 1'b1;  // Signal that this input is valid

    @(posedge clk);
    valid_i = 1'b0;  // Pull valid low if you want to test non-back-to-back
  endtask

  initial begin : checker_thread
    logic  [FLOAT_W-1:0] expected_bits;
    string               test_name;
    real real_z_dut, real_z_ref;
    bit check_pass;

    forever begin
      @(posedge clk);

      if (valid_o) begin
        if (expected_queue.size() == 0) begin
          $error("FAIL: valid_o asserted but expected_queue is empty!");
          errors++;
        end else begin
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
  end

  initial begin
    $display("=== STARTING PIPELINED MAC TEST WITH VALID SIGNALS ===");

    rst_n   = 0;
    valid_i = 0;
    a       = 0;
    b       = 0;
    c       = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    // Directed Tests
    send_stimulus("Simple Mult", downscale_double(1.5), downscale_double(2.0), 16'h0000);
    send_stimulus("Simple Add", downscale_double(1.0), downscale_double(1.0), downscale_double(3.5
                  ));

    send_stimulus("Previous Error 1", 16'h6B6b, 16'h0801, 16'h01AB);
    send_stimulus("Previous Error 2", 16'hEDCD, 16'h8000, 16'h0679);

    $display("--- Random Stress Test (Back-to-Back) ---");
    for (i = 0; i < 1000000; i++) begin
      logic [FLOAT_W-1:0] ra, rb, rc;
      void'(std::randomize(ra, rb, rc));
      if (i % 10 == 0) rc = 0;

      // Drive valid_i high every cycle for back-to-back testing
      a       = ra;
      b       = rb;
      c       = rc;
      valid_i = 1'b1;

      // Calculate and push reference
      expected_queue.push_back(
          downscale_double((upscale_to_double(ra) * upscale_to_double(rb)) + upscale_to_double(rc)
          ));
      name_queue.push_back($sformatf("Rand #%0d", i));

      if (i % 100000 == 0) $display("Driving Test Case %0d...", i);
      @(posedge clk);
    end
    valid_i = 1'b0;

    wait (expected_queue.size() == 0);
    repeat (5) @(posedge clk);

    if (errors == 0) begin
      $display("=== SUCCESS! ALL TESTS PASSED ===");
    end else begin
      $display("=== TEST COMPLETED. Total Errors: %0d ===", errors);
    end

    $finish;
  end

endmodule
