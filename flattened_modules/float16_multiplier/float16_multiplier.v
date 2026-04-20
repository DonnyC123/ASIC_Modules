// Multiplies two IEEE-754 float16 values
module float16_multiplier (
  input  wire [15:0] float_a_i,
  input  wire [15:0] float_b_i,
  output wire [15:0] float_product_o
);

  localparam BIAS = 15;

  wire               float_a_sign;
  wire               float_a_inf;
  wire               float_a_nan;
  wire               float_a_zero;
  wire        [ 4:0] float_a_exp;
  wire        [10:0] float_a_mantissa;

  wire               float_b_sign;
  wire               float_b_inf;
  wire               float_b_nan;
  wire               float_b_zero;
  wire        [ 4:0] float_b_exp;
  wire        [10:0] float_b_mantissa;

  wire               product_sign;
  wire               product_inf;
  wire               product_nan;
  wire               product_zero;

  wire        [21:0] product_mantissa_raw;
  wire signed [ 6:0] product_exp_raw;

  wire        [10:0] product_mantissa_unrounded;
  wire        [ 5:0] product_exp_unrounded;
  wire               round_product;

  wire        [15:0] float_product_rounded;
  reg         [15:0] float_product;

  // decode each operand into sign, exp, mantissa, and special flags
  float16_decoder float_a_decoder_inst (
      .float_i         (float_a_i),
      .float_sign_o    (float_a_sign),
      .float_exp_o     (float_a_exp),
      .float_mantissa_o(float_a_mantissa),
      .float_inf_o     (float_a_inf),
      .float_nan_o     (float_a_nan),
      .float_zero_o    (float_a_zero)
  );

  float16_decoder float_b_decoder_inst (
      .float_i         (float_b_i),
      .float_sign_o    (float_b_sign),
      .float_exp_o     (float_b_exp),
      .float_mantissa_o(float_b_mantissa),
      .float_inf_o     (float_b_inf),
      .float_nan_o     (float_b_nan),
      .float_zero_o    (float_b_zero)
  );


  assign product_sign = float_a_sign ^ float_b_sign;

  // nan if either is nan or if inf * zero
  assign product_nan = float_a_nan || float_b_nan || (float_a_inf && float_b_zero) || (float_b_inf && float_a_zero);

  // inf if either is inf
  assign product_inf = float_a_inf || float_b_inf;
  assign product_zero = float_a_zero || float_b_zero;

  // multiply full mantissas
  assign product_mantissa_raw = float_a_mantissa * float_b_mantissa;
  // add exponents and subtract bias. multiplying exponetials is the same as
  // adding them
  assign product_exp_raw = $signed({2'b0, float_a_exp}) + $signed({2'b0, float_b_exp}) - 7'sd15;

  // shift the raw product to align the leading one, extract the top 10 bits
  // of fraction, and compute if it needs to be rounded
  product_normalizer product_normalizer_inst (
      .product_i                   (product_mantissa_raw),
      .product_exp_i               (product_exp_raw),
      .unrounded_product_mantissa_o(product_mantissa_unrounded),
      .unrounded_product_exp_o     (product_exp_unrounded),
      .round_product_o             (round_product)
  );

  // round the mantissa, and pack the 16-bit float result
  product_rounder product_rounder_inst (
      .product_sign_unrouned_i    (product_sign),
      .product_exp_unrouned_i     (product_exp_unrounded),
      .product_mantissa_unrouned_i(product_mantissa_unrounded),
      .round_product_i            (round_product),
      .product_o                  (float_product_rounded)
  );


  // mux the rounded result against the special-case values
  always @(*) begin
    if (product_nan) begin
      // nan: sign=1, exp all ones, mantissa not all zeros
      float_product[15]    = 1'b1;
      float_product[14:10] = 5'h1F;
      float_product[9:0]   = 10'h3FF;
    end else if (product_inf) begin
      // signed infinity
      float_product[15]    = product_sign;
      float_product[14:10] = 5'h1F;
      float_product[9:0]   = 10'h0;
    end else if (product_zero) begin
      // signed zero
      float_product[15]    = product_sign;
      float_product[14:10] = 5'h0;
      float_product[9:0]   = 10'h0;
    end else begin
      // normal result from the rounder
      float_product = float_product_rounded;
    end
  end

  assign float_product_o = float_product;

endmodule
