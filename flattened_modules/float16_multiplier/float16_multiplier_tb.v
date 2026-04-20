`timescale 1ns / 1ps

module float16_multiplier_tb;

  localparam FLOAT_BIAS = 15;
  localparam DOUBLE_BIAS = 1023;

  reg  [15:0] float_a;
  reg  [15:0] float_b;
  wire [15:0] float_product;

  float16_multiplier dut (
      .float_a_i      (float_a),
      .float_b_i      (float_b),
      .float_product_o(float_product)
  );

  // Convert float16 to real
  // 1. Pull out the sign, exponent, and fraction fields
  // 2. Handle the special cases (zero, inf, nan)
  // 3. For a regular number, shift the fields into the 64-bit
  // double format and return the value as a real

  function real float_to_real(input [15:0] float_i);
    reg            float_sign;
    reg     [ 4:0] float_exp;
    reg     [ 9:0] float_frac;

    reg     [63:0] double_bits;
    reg     [10:0] double_exp;
    reg     [51:0] double_frac;

    reg     [ 9:0] denorm_shifted_frac;
    integer        denorm_lz;
    integer        denorm_true_exp;
    integer        k;
    reg            denorm_found;
    begin
      float_sign = float_i[15];
      float_exp  = float_i[14:10];
      float_frac = float_i[9:0];

      // zero
      if (float_exp == 5'd0 && float_frac == 10'd0) begin
        double_bits = {float_sign, 63'd0};
        // inf / nan
      end else if (float_exp == 5'd31) begin
        double_exp  = 11'd2047;
        double_frac = {float_frac, 42'd0};
        double_bits = {float_sign, double_exp, double_frac};
        // handle denormal case
      end else if (float_exp == 5'd0) begin
        denorm_lz    = 0;
        denorm_found = 1'b0;
        for (k = 9; k >= 0; k = k - 1) begin
          if (!denorm_found && float_frac[k]) denorm_found = 1'b1;
          else if (!denorm_found) denorm_lz = denorm_lz + 1;
        end

        denorm_true_exp     = (9 - denorm_lz) - 24;
        denorm_shifted_frac = float_frac << (denorm_lz + 1);
        double_exp          = denorm_true_exp + DOUBLE_BIAS;
        double_frac         = {denorm_shifted_frac, 42'd0};
        double_bits         = {float_sign, double_exp, double_frac};

        // normal
      end else begin
        double_exp  = float_exp - FLOAT_BIAS + DOUBLE_BIAS;
        double_frac = {float_frac, 42'd0};
        double_bits = {float_sign, double_exp, double_frac};
      end

      float_to_real = $bitstoreal(double_bits);
    end
  endfunction

  // Convert real to float16
  // 1. Pull out its sign, exponent, and fraction from double
  // 2. Re-bias the exponent for float16
  // 3. If it overflows the 5-bit exponent range, return inf.
  // If it underflows, return zero (no denormal support here
  // to keep the function simple for class use).
  // 4. Otherwise take the top 10 bits of the double's fraction and
  // do a simple round-to-nearest using the 11th bit as the
  // guard bit.

  function [15:0] real_to_float;
    input real double_i;
    reg     [63:0] double_bits;
    reg            double_sign;
    reg     [10:0] double_exp;
    reg     [51:0] double_frac;

    reg     [52:0] full_frac;
    reg     [52:0] shifted_frac;
    integer        shift_dist;

    integer        float_new_exp;
    reg     [ 4:0] float_exp;
    reg     [ 9:0] float_frac;

    reg     [10:0] rounding_frac;
    reg            sticky;
    reg            round_up;
    reg     [10:0] frac_carry_adder;
    begin
      double_bits = $realtobits(double_i);
      double_sign = double_bits[63];
      double_exp  = double_bits[62:52];
      double_frac = double_bits[51:0];

      // Zero in the input
      if (double_exp == 11'd0 && double_frac == 52'd0) begin
        real_to_float = {double_sign, 15'd0};
        // NaN or inf in the input
      end else if (double_exp == 11'd2047) begin
        if (double_frac == 52'd0) begin
          real_to_float = {double_sign, 5'b11111, 10'd0};  // inf
        end else begin
          real_to_float = {double_sign, 5'b11111, 10'h3FF};  // nan 
        end
      end else begin
        float_new_exp = double_exp - DOUBLE_BIAS + FLOAT_BIAS;
        full_frac     = (double_exp == 11'd0) ? {1'b0, double_frac} : {1'b1, double_frac};

        // saturate to inf
        if (float_new_exp >= 31) begin
          real_to_float = {double_sign, 5'b11111, 10'd0};
        end else if (float_new_exp <= 0) begin
          float_exp  = 5'd0;
          shift_dist = 1 - float_new_exp;

          if (shift_dist > 53) begin
            rounding_frac = 11'd0;
            sticky        = 1'b1;
          end else begin
            shifted_frac  = full_frac >> shift_dist;
            rounding_frac = shifted_frac[51:41];
            sticky        = (|shifted_frac[40:0]) | (|(full_frac << (53 - shift_dist)));
          end

          // round to nearest even
          round_up         = rounding_frac[0] & (rounding_frac[1] | sticky);
          frac_carry_adder = {1'b0, rounding_frac[10:1]} + round_up;
          float_frac       = frac_carry_adder[9:0];

          if (frac_carry_adder[10]) float_exp = 5'd1;

          real_to_float = {double_sign, float_exp, float_frac};

          // normal range: top 11 bits of double frac
        end else begin
          float_exp        = float_new_exp[4:0];
          rounding_frac    = double_frac[51:41];
          sticky           = |double_frac[40:0];

          round_up         = rounding_frac[0] & (rounding_frac[1] | sticky);
          frac_carry_adder = {1'b0, rounding_frac[10:1]} + round_up;
          float_frac       = frac_carry_adder[9:0];

          if (frac_carry_adder[10]) begin
            float_exp = float_exp + 5'd1;
            if (float_exp == 5'b11111) begin
              real_to_float = {double_sign, 5'b11111, 10'd0};  // rounded up to inf
            end else begin
              real_to_float = {double_sign, float_exp, 10'd0};
            end
          end else begin
            real_to_float = {double_sign, float_exp, float_frac};
          end
        end
      end
    end
  endfunction

  function automatic logic is_nan(input real val);
    return (val != val);
  endfunction

  integer pass_count;
  integer fail_count;

  task check;
    input reg [15:0] float16_a;
    input reg [15:0] float16_b;

    real        double_a;
    real        double_b;

    real        double_expected_unrounded;
    real        double_expected;
    reg  [15:0] float16_expected;
    real        double_actual;
    reg  [15:0] float16_actual;

    begin
      float_a = float16_a;
      float_b = float16_b;

      #2.5;

      double_a                  = float_to_real(float16_a);
      double_b                  = float_to_real(float16_b);
      double_expected_unrounded = double_a * double_b;
      float16_expected          = real_to_float(double_expected_unrounded);
      double_expected           = float_to_real(float16_expected);

      float16_actual            = float_product;
      double_actual             = float_to_real(float16_actual);

      // $display("Computing %f * %f: Expected %f (%h), Actual %f (%h)", double_a, double_b, double_expected,
      //          float16_expected, double_actual, float16_actual);

      if ((is_nan(double_actual) && is_nan(double_expected)) || double_actual == double_expected) begin
        pass_count = pass_count + 1;
      end else begin
        $display("Computing %f * %f: Expected %f (%h), Actual %f (%h)", double_a, double_b, double_expected,
                 float16_expected, double_actual, float16_actual);
        fail_count = fail_count + 1;
        $fatal(1, "Expected and actual don't match");
      end
    end
  endtask

  integer        i;
  reg     [15:0] rand_a;
  reg     [15:0] rand_b;

  initial begin
    $display("Starting float16_multiplier testbench");
    pass_count = 0;
    fail_count = 0;

    // directed tests 
    check(16'h3C00, 16'h3C00);  // 1.0   * 1.0
    check(16'h3E00, 16'h3E00);  // 1.5   * 1.5
    check(16'h4000, 16'h3800);  // 2.0   * 0.5
    check(16'hC200, 16'h4000);  // -3.0  * 2.0
    check(16'h3400, 16'h4400);  // 0.25  * 4.0
    check(16'h0000, 16'h4700);  // 0.0   * 7.0
    check(16'h5640, 16'h5640);  // 100.0 * 100.0

    // random tests
    $display("Starting 100,000,000 random tests");
    for (i = 0; i < 100000000; i = i + 1) begin
      rand_a = $random;
      rand_b = $random;
      check(rand_a, rand_b);
    end

    $display("Finished Testing: %0d passed, %0d failed", pass_count, fail_count);
    $finish;
  end

endmodule
