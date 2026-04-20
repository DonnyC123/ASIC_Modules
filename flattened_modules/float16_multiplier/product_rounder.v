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
  wire        product_inf;

  assign product_mantissa_rounded_raw = product_mantissa_unrouned_i + 1;

  assign round_ovfl = product_mantissa_rounded_raw[11];

  assign product_mantissa_rounded     = round_ovfl ?
                                        product_mantissa_rounded_raw[11:1] :
                                        product_mantissa_rounded_raw[10:0];

  assign product_exp_rounded = round_ovfl ? product_exp_unrouned_i + 1 : product_exp_unrouned_i;


  assign product_mantissa = round_product_i ? product_mantissa_rounded : product_mantissa_unrouned_i;
  assign product_exp = round_product_i ? product_exp_rounded : product_exp_unrouned_i;


  assign product_inf = product_exp[5] || product_exp[4:0] == 5'b11111;

  assign product_o[15] = product_sign_unrouned_i;

  assign product_o[14:10] = product_inf ? 5'b11111 : product_exp[4:0];
  assign product_o[9:0] = product_inf ? 10'b0 : product_mantissa[9:0];
endmodule
