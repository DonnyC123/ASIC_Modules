// Aligns the 22-bit raw mantissa product in to an unrounded fraction
// when the exponent would underflow, and produces flag if mantissa should be
// rounded up
module product_normalizer (
  input  wire        [21:0] product_i,
  input  wire signed [ 6:0] product_exp_i,
  output wire        [10:0] unrounded_product_mantissa_o,
  output wire        [ 5:0] unrounded_product_exp_o,
  output wire               round_product_o
);

  wire        [ 4:0] leading_zero_count;
  wire signed [ 6:0] unrounded_product_exp;
  wire        [21:0] normalized_mantissa;
  wire        [21:0] shifted_product_mantissa;

  wire               is_denormal;
  wire signed [ 6:0] denorm_shift_amount;
  wire        [ 4:0] denorm_shift;
  wire        [21:0] denorm_shift_mask;
  wire               denorm_sticky;

  wire               guard;
  wire               sticky;
  wire               mantissa_lsb;

  // count leading zeros to find how far to shift the product left
  leading_zero_counter leading_zero_counter_inst (
      .data_i              (product_i),
      .leading_zero_count_o(leading_zero_count)
  );

  // adjust the exponent: +1 for the extra integer bit from the mantissa
  // multiply, then subtract the amount the mantissa needs to be left-shifted
  assign unrounded_product_exp = product_exp_i + 7'sd1 - $signed({2'b00, leading_zero_count});

  // left-shift the product so the leading one lands in bit 21
  assign normalized_mantissa = product_i << leading_zero_count;

  // denormal output when the biased exp would be zero or negative
  // right-shift by (1 - exp) so the effective true exp becomes -14
  assign is_denormal = (unrounded_product_exp <= 0);
  assign denorm_shift_amount = 7'sd1 - unrounded_product_exp;
  assign denorm_shift = is_denormal ? ((denorm_shift_amount > 7'sd21) ? 5'd21 : denorm_shift_amount[4:0]) : 5'd0;

  assign shifted_product_mantissa = normalized_mantissa >> denorm_shift;

  // bits that fell off the bottom of the denormal right-shift still
  // contribute to sticky for rounding
  assign denorm_shift_mask = (22'd1 << denorm_shift) - 22'd1;
  assign denorm_sticky = |(normalized_mantissa & denorm_shift_mask);

  assign unrounded_product_mantissa_o = shifted_product_mantissa[21:11];

  assign unrounded_product_exp_o = is_denormal ? 6'd0 : unrounded_product_exp[5:0];

  // guard, sticky, and mantissa lsb for round-to-nearest-even
  assign mantissa_lsb = shifted_product_mantissa[11];
  assign guard = shifted_product_mantissa[10];
  assign sticky = |shifted_product_mantissa[9:0] | denorm_sticky;

  // round up when guard is set and either the lsb or sticky forces it
  assign round_product_o = guard && (mantissa_lsb || sticky);

endmodule
