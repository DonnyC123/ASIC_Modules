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

  // MANTISSA_W partial product rows + 1 row for csa_c
  localparam NUM_WT_ROWS = MANTISSA_W + 1;

  // Wallace tree runs at PARTIAL_SUM_LOW_W (not PRODUCT_MANTISSA_W) so that
  // carry shifts within carry_save_row_adder cannot overflow: product + csa_c
  // can sum to PRODUCT_MANTISSA_W+1 bits, which fits in PARTIAL_SUM_LOW_W.
  logic [PARTIAL_SUM_LOW_W-1:0] partial_products[NUM_WT_ROWS];
  logic [PARTIAL_SUM_LOW_W-1:0] wt_sum;
  logic [PARTIAL_SUM_LOW_W-1:0] wt_carry;
  logic [ PARTIAL_SUM_LOW_W-1:0] mantissa_sum_lower;
  logic [  PARTIAL_SUM_HIGH_W:0] upper_sum_temp;
  logic [PARTIAL_SUM_HIGH_W-1:0] mantissa_sum_upper;

  always_comb begin
    for (int i = 0; i < MANTISSA_W; i++) begin
      partial_products[i] = norm_mant_b_i[i] ? (PARTIAL_SUM_LOW_W'(norm_mant_a_i) << i) : '0;
    end
    // csa_c folded into the tree — tool now sees one N+1 input reduction
    // instead of a black-box multiplier output feeding a separate adder
    partial_products[MANTISSA_W] = PARTIAL_SUM_LOW_W'(csa_c_i);
  end

  wallace_tree_recursive #(
      .DATA_W  (PARTIAL_SUM_LOW_W),
      .NUM_ROWS(NUM_WT_ROWS)
  ) wallace_tree_inst (
      .partial_sums(partial_products),
      .sum         (wt_sum),
      .carry       (wt_carry)
  );

  always_comb begin
    // Single final carry-propagate adder for the lower portion
    mantissa_sum_lower = wt_sum + wt_carry;

    upper_sum_temp = {c_upper_slice_i[PARTIAL_SUM_HIGH_W-1], c_upper_slice_i}
                   + (PARTIAL_SUM_HIGH_W + 1)'(mantissa_sum_lower[PARTIAL_SUM_LOW_W-1 : PARTIAL_SUM_LOW_W-2]);

    mantissa_sum_upper = upper_sum_temp[PARTIAL_SUM_HIGH_W:1];

    mantissa_sum_raw_o = {
      mantissa_sum_upper, upper_sum_temp[0], mantissa_sum_lower[PARTIAL_SUM_LOW_W-3:0]
    };
  end

endmodule
