`timescale 1ns / 1ps

module tb_mac_float;

  localparam EXP_W  = 5;
  localparam FRAC_W = 10;
  localparam DATA_W = FRAC_W + EXP_W + 1;

  localparam BIAS = (1 << (EXP_W - 1)) - 1;

  logic [DATA_W-1:0] a, b, c;
  logic [DATA_W-1:0] z;

  real real_a, real_b, real_c, real_z_dut, real_z_ref;

  mac_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) dut (
      .a(a),
      .b(b),
      .c(c),
      .z(z)
  );

  function automatic logic [DATA_W-1:0] real2bits(input real val);
    logic              sign;
    logic [      10:0] exp_raw;
    logic [      51:0] mant_raw;
    logic [      63:0] double_bits;
    logic [ EXP_W-1:0] new_exp;
    logic [FRAC_W-1:0] new_frac;

    double_bits = $realtobits(val);
    sign        = double_bits[63];
    exp_raw     = double_bits[62:52];
    mant_raw    = double_bits[51:0];

    if (val == 0.0) return '0;

    if ($signed(exp_raw) - 1023 + BIAS <= 0) begin
      new_exp  = '0;
      new_frac = '0;
    end else if ($signed(exp_raw) - 1023 + BIAS >= (1 << EXP_W) - 1) begin
      new_exp  = '1;
      new_frac = '0;
    end else begin
      new_exp  = exp_raw - 1023 + BIAS;
      new_frac = mant_raw[51-:FRAC_W];
    end

    return DATA_W'({sign, new_exp, new_frac});
  endfunction

  function automatic real bits2real(input logic [DATA_W-1:0] val);
    logic              sign;
    logic [ EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
    real               res;

    frac = val[FRAC_W-1:0];
    exp  = val[FRAC_W+EXP_W-1:FRAC_W];
    sign = val[FRAC_W+EXP_W];

    if (exp == '0) return 0.0;
    if (exp == '1) return (sign ? -1.0 / 0.0 : 1.0 / 0.0);  // Infinity

    res = (1.0 + (real'(frac) / (2.0 ** FRAC_W))) * (2.0 ** (int'(exp) - BIAS));
    return sign ? -res : res;
  endfunction

  integer i;
  integer errors = 0;

  task check_result(input string name);
    real               expected;
    logic [DATA_W-1:0] expected_bits;
    logic [DATA_W-1:0] diff;

    real_a        = bits2real(a);
    real_b        = bits2real(b);
    real_c        = bits2real(c);

    expected      = (real_a * real_b) + real_c;
    expected_bits = real2bits(expected);

    real_z_dut    = bits2real(z);
    real_z_ref    = expected;

    if (z > expected_bits) diff = z - expected_bits;
    else diff = expected_bits - z;

    if (diff > 1 && z != expected_bits) begin
      $error("[%s] Mismatch! A=%f B=%f C=%f | DUT=%f (0x%h) REF=%f (0x%h)", name, real_a, real_b,
             real_c, real_z_dut, z, real_z_ref, expected_bits);
      errors++;
    end else begin
      $display("[%s] PASS: %f * %f + %f = %f", name, real_a, real_b, real_c, real_z_dut);
    end
  endtask

  initial begin

    $display("=== STARTING FLOATING POINT MAC TEST ===");

    a = real2bits(1.5);
    b = real2bits(2.0);
    c = real2bits(0.0);
    #10;
    check_result("Simple Mult");

    a = real2bits(1.0);
    b = real2bits(1.0);
    c = real2bits(3.5);
    #10;
    check_result("Simple Add");

    a = real2bits(2.0);
    b = real2bits(1.5);
    c = real2bits(-1.0);
    #10;
    check_result("Subtraction Pos");

    a = real2bits(1.0);
    b = real2bits(1.0);
    c = real2bits(-5.0);
    #10;
    check_result("Subtraction Neg");

    a = real2bits(1000.0);
    b = real2bits(1000.0);
    c = real2bits(0.0);
    #10;
    check_result("Overflow");

    a = real2bits(0.0001);
    b = real2bits(0.0001);
    c = real2bits(0.0);
    #10;
    check_result("Underflow");

    $display("--- Starting Random Stress Test ---");
    for (i = 0; i < 100; i++) begin
      void'(std::randomize(
          a
      ) with {
        a[DATA_W-2:FRAC_W] > 5;
        a[DATA_W-2:FRAC_W] < 25;
      });
      void'(std::randomize(
          b
      ) with {
        b[DATA_W-2:FRAC_W] > 5;
        b[DATA_W-2:FRAC_W] < 25;
      });
      void'(std::randomize(
          c
      ) with {
        c[DATA_W-2:FRAC_W] > 5;
        c[DATA_W-2:FRAC_W] < 25;
      });

      #10;
      check_result($sformatf("Rand #%0d", i));
    end

    $display("=== TEST COMPLETED. Total Errors: %0d ===", errors);
    $finish;
  end

endmodule
