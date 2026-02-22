module align_addend #(
    parameter EXP_W  = 5,
    parameter FRAC_W = 9,

    localparam SIGN_BIT           = 1,
    localparam ROUND_BITS         = 2,
    localparam MANTISSA_W         = FRAC_W + 1,
    localparam UPPER_SLICE_W      = MANTISSA_W + SIGN_BIT + ROUND_BITS,
    localparam PRODUCT_EXP_W      = EXP_W + 2,
    localparam PRODUCT_MANTISSA_W = 2 * MANTISSA_W,

    parameter type unpacked_float_t = struct packed {
      logic                  sign;
      logic [EXP_W-1:0]      exp;
      logic [MANTISSA_W-1:0] mantissa;
    }
) (
    input  unpacked_float_t                          unpacked_c_i,
    input  logic signed     [     PRODUCT_EXP_W-1:0] product_exp_i,
    input  logic                                     product_sign_i,
    output logic            [     UPPER_SLICE_W-1:0] c_upper_slice_o,
    output logic            [PRODUCT_MANTISSA_W-1:0] csa_c_o,
    output logic                                     c_lower_sticky_o,
    output logic                                     c_dominates_o,
    output logic                                     cancel_round_even_o
);

  localparam C_SHIFT_RAW_W    = MANTISSA_W + PRODUCT_MANTISSA_W + UPPER_SLICE_W;
  localparam C_SHIFT_MAX      = PRODUCT_MANTISSA_W + UPPER_SLICE_W - SIGN_BIT;
  localparam C_SHIFT_FACTOR_W = $clog2(C_SHIFT_RAW_W);

  localparam PRODUCT_ZERO_POINT_OFFSET = FRAC_W;
  localparam SHIFT_ZERO_POINT_OFFSET   = MANTISSA_W;

  typedef struct packed {
    logic [1:0]                  ovfl;
    logic [C_SHIFT_FACTOR_W-1:0] exp;
  } c_shift_factor_t;

  typedef struct packed {
    logic [UPPER_SLICE_W-1:0]      upper_c;
    logic [PRODUCT_MANTISSA_W-1:0] product_aligned_c;
    logic [MANTISSA_W - 1:0]       rounding_c;
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
        + c_shift_factor_t'(PRODUCT_ZERO_POINT_OFFSET) + c_shift_factor_t'(SHIFT_ZERO_POINT_OFFSET);

    c_shift_unfl = &c_shift_amount.ovfl;
    c_shift_ovfl = (c_shift_amount > C_SHIFT_MAX) && !c_shift_unfl;

    subtract_c = (product_sign_i ^ unpacked_c_i.sign);
    c_wide_prep = C_SHIFT_RAW_W'(unpacked_c_i.mantissa);

    if (subtract_c) begin
      c_wide_prep = $unsigned(-$signed(c_wide_prep));
    end

    c_shifted_raw    = c_wide_prep << c_shift_amount;
    c_shifted_struct = c_shifted_raw;

    c_upper_slice_o  = '0;
    csa_c_o          = '0;

    if (c_shift_unfl) begin
      c_lower_sticky_o = |unpacked_c_i.mantissa;
      csa_c_o[0] = ($signed(c_shift_amount) == -1) && unpacked_c_i.mantissa[MANTISSA_W-1] &&
          c_lower_sticky_o;
      if (csa_c_o[0]) begin
        c_lower_sticky_o = 0;
        if (subtract_c) begin
          csa_c_o         = $unsigned(-$signed(csa_c_o));
          c_upper_slice_o = '1;
        end
      end
      c_lower_sticky_o = c_lower_sticky_o && !subtract_c;
    end else if (c_shift_ovfl) begin
      c_lower_sticky_o = '0;
    end else begin
      c_upper_slice_o  = c_shifted_struct.upper_c;
      csa_c_o          = c_shifted_struct.product_aligned_c;
      c_lower_sticky_o = |c_shifted_struct.rounding_c;
    end
  end
  assign c_dominates_o       = c_shift_ovfl;
  assign cancel_round_even_o = (c_shift_amount == 'b1) && subtract_c && unpacked_c_i.mantissa != 0;
endmodule
