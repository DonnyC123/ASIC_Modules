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

  localparam NUM_PARTIAL_PRODUCTS = MANTISSA_W;
  localparam NUM_WALLACE_INPUTS   = NUM_PARTIAL_PRODUCTS + 1;



  logic [         LOW_SUM_W-1:0] partial_products   [NUM_PARTIAL_PRODUCTS];
  logic [         LOW_SUM_W-1:0] csa_summands       [  NUM_WALLACE_INPUTS];
  logic [         LOW_SUM_W-1:0] csa_tree_sum;
  logic [         LOW_SUM_W-1:0] csa_tree_carry;
  logic [  PARTIAL_SUM_HIGH_W:0] upper_sum_temp;
  logic [PARTIAL_SUM_HIGH_W-1:0] mantissa_sum_upper;
  logic [ PARTIAL_SUM_LOW_W-1:0] mantissa_sum_lower;

  always_comb begin
    foreach (partial_products[i]) begin
      logic [MANTISSA_W-1:0] partial_product;
      partial_product     = norm_mant_a_i & {MANTISSA_W{norm_mant_b_i[i]}};
      partial_products[i] = {{(MANTISSA_W + 1) {1'b0}}, partial_product} << i;
    end

    for (int i = 0; i < NUM_PARTIAL_PRODUCTS; i++) begin
      csa_summands[i] = partial_products[i];
    end
    csa_summands[NUM_WALLACE_INPUTS-1] = {1'b0, csa_c_i};
  end

  wallace_tree_recursive #(
      .DATA_W  (LOW_SUM_W),
      .NUM_ROWS(NUM_WALLACE_INPUTS)
  ) wallace_tree_inst (
      .partial_sums(csa_summands),
      .sum         (csa_tree_sum),
      .carry       (csa_tree_carry)
  );

  always_comb begin
    mantissa_sum_lower = csa_tree_sum + {csa_tree_carry[PARTIAL_SUM_LOW_W-2:1], 1'b0};
    upper_sum_temp = {c_upper_slice_i[PARTIAL_SUM_HIGH_W-1], c_upper_slice_i}
                   + (PARTIAL_SUM_HIGH_W + 1)'(mantissa_sum_lower[PARTIAL_SUM_LOW_W-1 : PARTIAL_SUM_LOW_W-2]);

    mantissa_sum_upper = upper_sum_temp[PARTIAL_SUM_HIGH_W:1];
    mantissa_sum_raw_o = {
      mantissa_sum_upper, upper_sum_temp[0], mantissa_sum_lower[PARTIAL_SUM_LOW_W-3:0]
    };

  end

endmodule
