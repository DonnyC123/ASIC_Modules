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
  logic [ PARTIAL_SUM_LOW_W-1:0] mantissa_sum_lower;
  logic [  PARTIAL_SUM_HIGH_W:0] upper_sum_temp;
  logic [PARTIAL_SUM_HIGH_W-1:0] mantissa_sum_upper;

  always_comb begin
    mult_result = norm_mant_a_i * norm_mant_b_i;

    mantissa_sum_lower = PARTIAL_SUM_LOW_W'(mult_result) + PARTIAL_SUM_LOW_W'(csa_c_i);

    upper_sum_temp = {c_upper_slice_i[PARTIAL_SUM_HIGH_W-1], c_upper_slice_i}
                   + (PARTIAL_SUM_HIGH_W + 1)'(mantissa_sum_lower[PARTIAL_SUM_LOW_W-1 : PARTIAL_SUM_LOW_W-2]);

    mantissa_sum_upper = upper_sum_temp[PARTIAL_SUM_HIGH_W:1];

    mantissa_sum_raw_o = {
      mantissa_sum_upper, upper_sum_temp[0], mantissa_sum_lower[PARTIAL_SUM_LOW_W-3:0]
    };
  end

endmodule
