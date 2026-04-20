// Testbench for float16_multiplier.

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
  // 2. Handle the special cases (zero, inf/nan) directly
  // 3. For a normal number, shift the fields into the 64-bit
  // double format and return the value as a real

  function real float_to_real(input [15:0] float_i);
    reg        float_sign;
    reg [ 4:0] float_exp;
    reg [ 9:0] float_frac;

    reg [63:0] double_bits;
    reg [10:0] double_exp;
    reg [51:0] double_frac;
    begin
      float_sign = float_i[15];
      float_exp  = float_i[14:10];
      float_frac = float_i[9:0];

      if (float_exp == 5'd0 && float_frac == 10'd0) begin
        double_bits = {float_sign, 63'd0};
      end else if (float_exp == 5'd31) begin
        double_exp  = 11'd2047;  // all ones exponent 
        double_frac = {float_frac, 42'd0};
        double_bits = {float_sign, double_exp, double_frac};
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
  // 3. If it overflows the 5-bit exponent range, return +/- inf.
  // If it underflows, return +/- zero (no denormal support here
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

    integer        float_new_exp;  // may go negative -> use integer
    reg     [ 4:0] float_exp;
    reg     [ 9:0] float_frac;
    reg            float_guard;
    reg     [10:0] float_frac_rounded;  // 11 bits to catch round-up overflow
    begin
      double_bits = $realtobits(double_i);
      double_sign = double_bits[63];
      double_exp  = double_bits[62:52];
      double_frac = double_bits[51:0];

      if (double_exp == 11'd0 && double_frac == 52'd0) begin
        real_to_float = {double_sign, 15'd0};
      end  // NaN or infinity in the input
      else if (double_exp == 11'd2047) begin
        if (double_frac == 52'd0) real_to_float = {double_sign, 5'b11111, 10'd0};  // inf
        else real_to_float = {double_sign, 5'b11111, 10'h3FF};  // NaN
      end else begin
        float_new_exp = double_exp - DOUBLE_BIAS + FLOAT_BIAS;

        // saturate to inf
        if (float_new_exp >= 31) begin
          real_to_float = {double_sign, 5'b11111, 10'd0};

          // flush to zero
        end else if (float_new_exp <= 0) begin
          real_to_float = {double_sign, 15'd0};
          // convert to float16
        end else begin
          float_frac         = double_frac[51:42];
          float_guard        = double_frac[41];

          float_frac_rounded = {1'b0, float_frac} + float_guard;

          if (float_frac_rounded[10]) begin
            float_exp  = float_new_exp[4:0] + 5'd1;
            float_frac = 10'd0;
            if (float_exp == 5'b11111) begin
              real_to_float = {double_sign, 5'b11111, 10'd0};  // rounded up to inf
            end else begin
              real_to_float = {double_sign, float_exp, float_frac};
            end
          end else begin
            float_exp     = float_new_exp[4:0];
            float_frac    = float_frac_rounded[9:0];
            real_to_float = {double_sign, float_exp, float_frac};
          end
        end
      end
    end
  endfunction

  task check;
    input real double_a;
    input real double_b;
    real        double_expected;
    real        double_got;
    reg  [15:0] float_got;
    begin
      float_a = real_to_float(double_a);
      float_b = real_to_float(double_b);
      #1;
      float_got       = float_product;
      double_got      = float_to_real(float_got);
      double_expected = double_a * double_b;
      $display("%f * %f = %f (expected %f, bits=%h)", double_a, double_b, double_got, double_expected, float_got);
    end
  endtask

  initial begin
    $display("Starting float16_multiplier testbench");

    check(1.0, 1.0);
    check(1.5, 1.5);
    check(2.0, 0.5);
    check(-3.0, 2.0);
    check(0.25, 4.0);
    check(0.0, 7.0);
    check(100.0, 100.0);

    $display("Done");
    $finish;
  end

endmodule
