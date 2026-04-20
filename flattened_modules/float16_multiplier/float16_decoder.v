// Splits a float16 value into sign, exponent, and full mantissa, and
// flags the inf/nan/zero special cases
module float16_decoder (
  input  wire [15:0] float_i,
  output wire        float_sign_o,
  output wire [ 4:0] float_exp_o,
  output wire [10:0] float_mantissa_o,
  output wire        float_inf_o,
  output wire        float_nan_o,
  output wire        float_zero_o
);

  wire [9:0] float_frac;
  wire       float_denorm;
  wire       float_exp_ones;
  wire       float_exp_zeros;
  wire       float_frac_zeros;

  assign float_sign_o     = float_i[15];
  assign float_frac       = float_i[9:0];

  // denormal when the stored exponent field is zero
  assign float_denorm     = float_i[14:10] == 5'b0 ? 1'b1 : 1'b0;

  // force exp to 1 for denormals
  assign float_exp_o      = float_denorm ? 5'b1 : float_i[14:10];

  // prepend the leading bit (0 for denorms, 1 for normals)
  assign float_mantissa_o = float_denorm ? {1'b0, float_frac} : {1'b1, float_frac};

  // check if exp is all ones
  assign float_exp_ones   = float_i[14:10] == 5'b11111;
  assign float_exp_zeros  = float_i[14:10] == 5'b0;
  // check if float frac is all zeros
  assign float_frac_zeros = float_frac == 10'b0;

  // exp all ones with zero frac -> inf
  assign float_inf_o      = float_exp_ones && float_frac_zeros;
  // exp all ones with nonzero frac -> nan
  assign float_nan_o      = float_exp_ones && !float_frac_zeros;
  // exp all zeros with zero frac -> zero
  assign float_zero_o     = float_exp_zeros && float_frac_zeros;

endmodule
