module product_normalizer #(
    parameter PRODUCT_W       = 22,
    parameter PRODUCT_EXP_W   = 6,
    parameter MANTISSA_W      = 11,
    parameter UNROUNDED_EXP_W = 6
) (
  input  wire [21:0] product_i,
  input  wire [ 5:0] product_exp_i,
  output wire [10:0] unrounded_product_mantissa_o,
  output wire [ 5:0] unrounded_product_exp_o,
  output wire        round_product_o
);

  localparam EXP_BIAS_ADJUST = 1;

  wire        [ 4:0] leading_zero_count;
  wire signed [ 6:0] unrounded_product_exp;
  wire        [21:0] shifted_product_mantissa;

  wire               guard;
  wire               sticky;
  wire               mantissa_msb;

  leading_zero_counter leading_zero_counter_inst (
      .data_i              (product_i),
      .leading_zero_count_o(leading_zero_count)
  );

  assign unrounded_product_exp = $signed({1'b0, product_exp_i}) + 7'sd1 - $signed({2'b00, leading_zero_count});

  assign unrounded_product_exp_o = (unrounded_product_exp >= 0) ? unrounded_product_exp[5:0] : 6'b0;

  assign shifted_product_mantissa = product_i << leading_zero_count;

  assign unrounded_product_mantissa_o = (unrounded_product_exp >= 0) ?
                                          shifted_product_mantissa[PRODUCT_W-1:PRODUCT_W-MANTISSA_W] :
                                          {MANTISSA_W{1'b0}};

  assign mantissa_msb = shifted_product_mantissa[PRODUCT_W-MANTISSA_W];
  assign guard = shifted_product_mantissa[PRODUCT_W-MANTISSA_W-1];
  assign sticky = |shifted_product_mantissa[PRODUCT_W-MANTISSA_W-2:0];

  assign round_product_o = guard && (mantissa_msb || sticky);

endmodule
