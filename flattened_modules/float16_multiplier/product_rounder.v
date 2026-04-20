// applys rounding decision to the product 
module product_rounder (
  input  wire        product_sign_unrouned_i,
  input  wire [ 5:0] product_exp_unrouned_i,
  input  wire [10:0] product_mantissa_unrouned_i,
  input  wire        round_product_i,
  output wire [15:0] product_o
);

  wire [11:0] product_mantissa_rounded_raw;
  wire [10:0] product_mantissa_rounded;
  wire [ 5:0] product_exp_rounded;

  wire [10:0] product_mantissa;
  wire [ 5:0] product_exp;

  wire        round_ovfl;
  wire        denorm_promote;
  wire        product_inf;

  // add 1 to the mantissa, using msb to catch rounding overflow
  assign product_mantissa_rounded_raw = product_mantissa_unrouned_i + 1;

  assign round_ovfl = product_mantissa_rounded_raw[11];

  // denormal promoted to smallest normal: pre-round bit 10 was zero and
  // rounding set it, but the add didn't carry past bit 11
  assign denorm_promote = round_product_i
                       && ~product_mantissa_unrouned_i[10]
                       &&  product_mantissa_rounded_raw[10]
                       && ~round_ovfl;

  // on overflow, shift right by 1 and increment exponent
  assign product_mantissa_rounded     = round_ovfl ?
                                        product_mantissa_rounded_raw[11:1] :
                                        product_mantissa_rounded_raw[10:0];

  assign product_exp_rounded = (round_ovfl || denorm_promote) ? product_exp_unrouned_i + 1 : product_exp_unrouned_i;

  // pick rounded or unrounded value
  assign product_mantissa = round_product_i ? product_mantissa_rounded : product_mantissa_unrouned_i;
  assign product_exp = round_product_i ? product_exp_rounded : product_exp_unrouned_i;

  // check for inf
  assign product_inf = product_exp[5] || product_exp[4:0] == 5'h1F;

  // pack sign, exponent, and mantissa (force inf encoding when overflowed)
  assign product_o[15] = product_sign_unrouned_i;
  assign product_o[14:10] = product_inf ? 5'b11111 : product_exp[4:0];
  assign product_o[9:0] = product_inf ? 10'b0 : product_mantissa[9:0];
endmodule
