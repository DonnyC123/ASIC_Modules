module mac_float_execution
  import mac_float_pkg::*;
#(
    parameter  MANTISSA_W         = 11,
    parameter  PRODUCT_MANTISSA_W = 2 * MANTISSA_W,
    parameter  C_LOWER_SLICE_W    = PRODUCT_MANTISSA_W,
    parameter  FULL_SUM_W         = 3 * MANTISSA_W + SIGN_W + 2 * CARRY_W,
    parameter  FULL_SUM_CARRY_W   = FULL_SUM_W + CARRY_W,
    localparam LOW_SUM_W          = C_LOWER_SLICE_W + CARRY_W,
    localparam PARTIAL_SUM_LOW_W  = LOW_SUM_W + CARRY_W,
    localparam C_UPPER_SLICE_W    = FULL_SUM_CARRY_W - PARTIAL_SUM_LOW_W + CARRY_W
) (
    input  logic        [ C_LOWER_SLICE_W-1:0] c_lower_slice_i,
    input  logic        [      MANTISSA_W-1:0] norm_mant_a_i,
    input  logic        [      MANTISSA_W-1:0] norm_mant_b_i,
    input  logic        [ C_UPPER_SLICE_W-1:0] c_upper_slice_i,
    output logic signed [FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_o
);

  logic [PRODUCT_MANTISSA_W-1:0] mult_result;
  logic [ PARTIAL_SUM_LOW_W-1:0] mantissa_sum_lower;
  logic [   C_UPPER_SLICE_W : 0] upper_sum_temp;
  logic [   C_UPPER_SLICE_W-1:0] mantissa_sum_upper;

  always_comb begin
    mult_result = norm_mant_a_i * norm_mant_b_i;

    mantissa_sum_lower = {2'b00, mult_result, {(C_LOWER_SLICE_W-PRODUCT_MANTISSA_W){1'b0}}} + PARTIAL_SUM_LOW_W'(c_lower_slice_i);

    upper_sum_temp = {c_upper_slice_i[C_UPPER_SLICE_W-1], c_upper_slice_i}
                   + (C_UPPER_SLICE_W + 1)'(mantissa_sum_lower[PARTIAL_SUM_LOW_W-1 : PARTIAL_SUM_LOW_W-2]);

    mantissa_sum_upper = upper_sum_temp[C_UPPER_SLICE_W:1];

    mantissa_sum_raw_o =
        $signed({mantissa_sum_upper, upper_sum_temp[0], mantissa_sum_lower[PARTIAL_SUM_LOW_W-3:0]});
  end

endmodule
