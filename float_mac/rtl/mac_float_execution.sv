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
    input  logic [PARTIAL_SUM_HIGH_W+PRODUCT_MANTISSA_W-1:0] aligned_c_i,
    input  logic [                           MANTISSA_W-1:0] norm_mant_a_i,
    input  logic [                           MANTISSA_W-1:0] norm_mant_b_i,
    output logic [                     FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_o
);

  localparam NUM_WT_ROWS = MANTISSA_W + 1;

  logic [PRODUCT_MANTISSA_W-1:0] mult_result;

  always_comb begin
    mult_result        = norm_mant_a_i * norm_mant_b_i;
    mantissa_sum_raw_o = FULL_SUM_CARRY_W'(mult_result) + FULL_SUM_CARRY_W'($signed(aligned_c_i));
  end

endmodule
