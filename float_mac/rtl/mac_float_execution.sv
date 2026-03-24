module mac_float_execution
  import mac_float_pkg::*;
#(
    parameter MANTISSA_W         = 11,
    parameter PRODUCT_MANTISSA_W = 2 * MANTISSA_W,
    parameter FULL_SUM_W         = 3 * MANTISSA_W + SIGN_W + 2 * CARRY_W,
    parameter FULL_SUM_CARRY_W   = FULL_SUM_W + CARRY_W,
    parameter LOW_SUM_W          = PRODUCT_MANTISSA_W + CARRY_W,
    parameter PARTIAL_SUM_LOW_W  = LOW_SUM_W + CARRY_W,
    parameter PARTIAL_SUM_HIGH_W = FULL_SUM_CARRY_W - PARTIAL_SUM_LOW_W + CARRY_W
) (
    input  logic [PRODUCT_MANTISSA_W-1:0] csa_c_i,
    input  logic [        MANTISSA_W-1:0] norm_mant_a_i,
    input  logic [        MANTISSA_W-1:0] norm_mant_b_i,
    input  logic [PARTIAL_SUM_HIGH_W-1:0] c_upper_slice_i,
    output logic [  FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_o
);

  logic [PRODUCT_MANTISSA_W-1:0] mult_result;

  always_comb begin
    mult_result = norm_mant_a_i * norm_mant_b_i;

    // Single full-width 3-input sum: eliminates the lower/upper split and the
    // part-select that was blocking CSA optimization (CSAGEN-QOR warning).
    // Equivalent to the original split: sign-extend c_upper_slice by 1 bit,
    // left-shift by PARTIAL_SUM_LOW_W, then add mult_result and csa_c_i.
    // c_upper_slice sits at bits [36:22] of the output (shifted by PRODUCT_MANTISSA_W=22).
    mantissa_sum_raw_o =
        FULL_SUM_CARRY_W'({c_upper_slice_i[PARTIAL_SUM_HIGH_W-1],
                           c_upper_slice_i,
                           {PRODUCT_MANTISSA_W{1'b0}}})
      + FULL_SUM_CARRY_W'(mult_result)
      + FULL_SUM_CARRY_W'(csa_c_i);
  end

endmodule
