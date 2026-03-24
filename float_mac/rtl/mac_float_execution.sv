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
    input  logic [                          MANTISSA_W-1:0] norm_mant_a_i,
    input  logic [                          MANTISSA_W-1:0] norm_mant_b_i,
    output logic [                    FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_o
);

  // MANTISSA_W partial product rows + 1 row for aligned_c
  localparam NUM_WT_ROWS = MANTISSA_W + 1;

  logic [FULL_SUM_CARRY_W-1:0] partial_products[NUM_WT_ROWS];
  logic [FULL_SUM_CARRY_W-1:0] wt_sum;
  logic [FULL_SUM_CARRY_W-1:0] wt_carry;

  always_comb begin
    for (int i = 0; i < MANTISSA_W; i++) begin
      partial_products[i] = norm_mant_b_i[i] ? (FULL_SUM_CARRY_W'(norm_mant_a_i) << i) : '0;
    end
    // aligned_c sign-extended: can be negative when C is subtracted from the product
    partial_products[MANTISSA_W] = FULL_SUM_CARRY_W'($signed(aligned_c_i));
  end

  wallace_tree_recursive #(
      .DATA_W  (FULL_SUM_CARRY_W),
      .NUM_ROWS(NUM_WT_ROWS)
  ) wallace_tree_inst (
      .partial_sums(partial_products),
      .sum         (wt_sum),
      .carry       (wt_carry)
  );

  assign mantissa_sum_raw_o = wt_sum + wt_carry;

endmodule
