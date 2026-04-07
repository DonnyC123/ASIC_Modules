module align_addend #(
    parameter  FRAC_IN_W          = 10,
    parameter  EXP_IN_W           = 5,
    parameter  FRAC_OUT_W         = 10,
    parameter  EXP_OUT_W          = 8,
    localparam MANTISSA_IN_W      = FRAC_IN_W + 1,
    localparam MANTISSA_OUT_W     = FRAC_OUT_W + 1,
    localparam UPPER_SLICE_W      = MANTISSA_OUT_W + SIGN_BIT + ROUND_BITS,
    localparam PRODUCT_EXP_W      = EXP_IN_W + 3,
    localparam PRODUCT_MANTISSA_W = 2 * MANTISSA_IN_W,
    localparam LOWER_SLICE_W      = PRODUCT_MANTISSA_W + FRAC_OUT_W - FRAC_IN_W,

    parameter type unpacked_float_t = struct packed {
      logic                      sign;
      logic [EXP_OUT_W-1:0]      exp;
      logic [MANTISSA_OUT_W-1:0] mantissa;
    }
) (
    input  unpacked_float_t                     unpacked_c_i,
    input  logic signed     [PRODUCT_EXP_W-1:0] product_exp_i,
    input  logic                                product_sign_i,
    output logic            [UPPER_SLICE_W-1:0] c_upper_slice_o,
    output logic            [LOWER_SLICE_W-1:0] c_lower_slice_o,
    output logic                                c_lower_sticky_o,
    output logic                                c_dominates_o,
    output logic                                ignore_round_even_o
);

  localparam C_SHIFT_RAW_W    = MANTISSA_IN_W + LOWER_SLICE_W + UPPER_SLICE_W;
  localparam C_SHIFT_MAX      = LOWER_SLICE_W + UPPER_SLICE_W - SIGN_BIT;
  localparam C_SHIFT_FACTOR_W = $clog2(C_SHIFT_RAW_W);

  localparam PRODUCT_ZERO_POINT_OFFSET = FRAC_IN_W;
  localparam SHIFT_ZERO_POINT_OFFSET   = MANTISSA_IN_W;

  typedef struct packed {
    logic [2:0]                  ovfl;
    logic [C_SHIFT_FACTOR_W-1:0] exp;
  } c_shift_factor_t;

  typedef struct packed {
    logic [UPPER_SLICE_W-1:0] upper_c;
    logic [LOWER_SLICE_W-1:0] product_aligned_c;
    logic [MANTISSA_IN_W-1:0] rounding_c;
  } shifted_c_t;

  c_shift_factor_t c_shift_amount;
  shifted_c_t      c_wide_prep;
  shifted_c_t      c_shifted_raw;
  shifted_c_t      c_shifted_struct;

  logic            c_shift_unfl;
  logic            c_shift_ovfl;
  logic            subtract_c;

  always_comb begin
    c_shift_amount = c_shift_factor_t'(unpacked_c_i.exp) - c_shift_factor_t'(product_exp_i)
        + c_shift_factor_t'(PRODUCT_ZERO_POINT_OFFSET) + c_shift_factor_t'(SHIFT_ZERO_POINT_OFFSET) + c_shift_factor_t'(FRAC_OUT_W - FRAC_IN_W);

    c_shift_unfl = &c_shift_amount.ovfl[2:1];
    c_shift_ovfl = (c_shift_amount > c_shift_factor_t'(C_SHIFT_MAX));

    subtract_c = (product_sign_i ^ unpacked_c_i.sign);
    c_wide_prep = C_SHIFT_RAW_W'(unpacked_c_i.mantissa);

    if (subtract_c) begin
      c_wide_prep = $unsigned(-$signed(c_wide_prep));
    end

    c_shifted_raw    = c_wide_prep << c_shift_amount;
    c_shifted_struct = c_shifted_raw;

    c_upper_slice_o  = '0;
    c_lower_slice_o  = '0;

    if (c_shift_unfl) begin
      c_lower_sticky_o = |unpacked_c_i.mantissa;
      c_lower_sticky_o = c_lower_sticky_o && !subtract_c;
    end else if (c_shift_ovfl) begin
      c_lower_sticky_o = '0;
    end else begin
      c_upper_slice_o  = c_shifted_struct.upper_c;
      c_lower_slice_o  = c_shifted_struct.product_aligned_c;
      c_lower_sticky_o = |c_shifted_struct.rounding_c;
    end
  end
  assign c_dominates_o       = c_shift_ovfl;
  assign ignore_round_even_o = c_shift_unfl && subtract_c && unpacked_c_i.mantissa != 0;
endmodule
