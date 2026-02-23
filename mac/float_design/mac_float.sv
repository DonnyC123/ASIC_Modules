module mac_float #(
    parameter  EXP_W  = 5,
    parameter  FRAC_W = 10,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic              clk,
    input  logic [DATA_W-1:0] a,
    input  logic [DATA_W-1:0] b,
    input  logic [DATA_W-1:0] c,
    output logic [DATA_W-1:0] z
);
  import mac_float_pkg::*;

  localparam MANTISSA_W           = FRAC_W + MANTISSA_INT_W;
  localparam BIAS                 = (1 << (EXP_W - 1)) - 1;
  localparam NUM_PARTIAL_PRODUCTS = MANTISSA_W;
  localparam NUM_WALLACE_INPUTS   = NUM_PARTIAL_PRODUCTS + 1;

  localparam PRODUCT_MANTISSA_W = 2 * MANTISSA_W;
  localparam LOW_SUM_W          = PRODUCT_MANTISSA_W + CARRY_W;
  localparam FULL_SUM_W         = 3 * MANTISSA_W + SIGN_W + 2 * CARRY_W;
  localparam FULL_SUM_CARRY_W   = FULL_SUM_W + CARRY_W;

  localparam PARTIAL_SUM_LOW_W  = LOW_SUM_W + CARRY_W;
  localparam PARTIAL_SUM_HIGH_W = FULL_SUM_CARRY_W - PARTIAL_SUM_LOW_W + CARRY_W;

  localparam LZC_COUNT_W        = $clog2(FULL_SUM_W + 1);
  localparam LZC_COUNT_OVFL_W   = LZC_COUNT_W + 1;
  localparam SUM_EXP_ADD_OFFSET = FULL_SUM_W - PRODUCT_MANTISSA_W;

  localparam DENORMALIZED_IDX    = PRODUCT_MANTISSA_W + 2;
  localparam NORMAL_FRAC_LSB_IDX = FULL_SUM_W - 1 - FRAC_W;
  localparam GUARD_IDX           = NORMAL_FRAC_LSB_IDX - 1;

  localparam SIGNED_EXP_W = EXP_W + SIGN_W + 2 * CARRY_W;
  localparam EXP_OVFL_IDX = EXP_W + CARRY_W - 1;
  localparam EXP_SIGN_IDX = EXP_W + SIGN_W + CARRY_W - 1;


  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_t;

  float_t                                    float_a;
  float_t                                    float_b;
  float_t                                    float_c;
  float_t                                    float_z;

  sum_float_flags_t                          sum_float_flags;
  logic             [        MANTISSA_W-1:0] norm_mant_a;
  logic             [        MANTISSA_W-1:0] norm_mant_b;

  logic signed      [      SIGNED_EXP_W-1:0] product_exp;
  logic                                      product_sign;
  logic             [         LOW_SUM_W-1:0] partial_products        [NUM_PARTIAL_PRODUCTS];

  logic             [PRODUCT_MANTISSA_W-1:0] csa_c;
  logic             [         LOW_SUM_W-1:0] csa_summands            [  NUM_WALLACE_INPUTS];
  logic             [         LOW_SUM_W-1:0] csa_tree_sum;
  logic             [         LOW_SUM_W-1:0] csa_tree_carry;
  logic             [  PARTIAL_SUM_HIGH_W:0] upper_sum_temp;
  logic             [PARTIAL_SUM_HIGH_W-1:0] c_upper_slice;
  logic             [PARTIAL_SUM_HIGH_W-1:0] mantissa_sum_upper;
  logic             [ PARTIAL_SUM_LOW_W-1:0] mantissa_sum_lower;
  logic             [  FULL_SUM_CARRY_W-1:0] mantissa_sum_raw;
  logic             [  FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_neg;

  logic             [        FULL_SUM_W-1:0] unsigned_mantissa_sum;
  logic             [        FULL_SUM_W-1:0] normalized_mantissa;

  logic             [            FRAC_W-1:0] sum_frac_raw;
  logic             [        MANTISSA_W-1:0] sum_frac_carry;
  logic             [            FRAC_W-1:0] sum_frac_rounded;

  logic             [       LZC_COUNT_W-1:0] mantissa_sum_lz;
  logic             [       LZC_COUNT_W-1:0] mantissa_sum_shift;
  logic             [  LZC_COUNT_OVFL_W-1:0] mantissa_sum_shift_ovfl;

  logic signed      [      SIGNED_EXP_W-1:0] sum_exp;
  logic                                      sum_signed;
  logic                                      sum_rounded_signed;
  logic                                      sum_exp_ovfl;
  logic                                      sum_exp_unfl;

  logic signed      [      SIGNED_EXP_W-1:0] sum_rounded_exp;
  logic                                      sum_rounded_exp_ovfl;
  logic                                      sum_rounded_exp_unfl;

  logic                                      sticky_sum;
  logic                                      guard;
  logic                                      round_mantissa;
  logic                                      sum_zero;

  always_comb begin
    float_a = float_t'(a);
    float_b = float_t'(b);
    float_c = float_t'(c);
  end

  mac_float_decode #(
      .float_t           (float_t),
      .SIGNED_EXP_W      (SIGNED_EXP_W),
      .MANTISSA_W        (MANTISSA_W),
      .PARTIAL_SUM_HIGH_W(PARTIAL_SUM_HIGH_W),
      .PRODUCT_MANTISSA_W(PRODUCT_MANTISSA_W)
  ) mac_float_decode_inst (
      .float_a_i        (float_a),
      .float_b_i        (float_b),
      .float_c_i        (float_c),
      .sum_float_flags_o(sum_float_flags),
      .product_sign_o   (product_sign),
      .product_exp_o    (product_exp),
      .c_upper_slice_o  (c_upper_slice),
      .csa_c_o          (csa_c),
      .norm_mant_a      (norm_mant_a),
      .norm_mant_b      (norm_mant_b)
  );

  always_comb begin
    foreach (partial_products[i]) begin
      logic [MANTISSA_W-1:0] partial_product;
      partial_product     = norm_mant_a & {MANTISSA_W{norm_mant_b[i]}};
      partial_products[i] = {{(MANTISSA_W + 1) {1'b0}}, partial_product} << i;
    end

    for (int i = 0; i < NUM_PARTIAL_PRODUCTS; i++) begin
      csa_summands[i] = partial_products[i];
    end
    csa_summands[NUM_WALLACE_INPUTS-1] = {1'b0, csa_c};
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
    upper_sum_temp = {c_upper_slice[PARTIAL_SUM_HIGH_W-1], c_upper_slice}
                   + (PARTIAL_SUM_HIGH_W + 1)'(mantissa_sum_lower[PARTIAL_SUM_LOW_W-1 : PARTIAL_SUM_LOW_W-2]);

    mantissa_sum_upper = upper_sum_temp[PARTIAL_SUM_HIGH_W:1];
    mantissa_sum_raw = {
      mantissa_sum_upper, upper_sum_temp[0], mantissa_sum_lower[PARTIAL_SUM_LOW_W-3:0]
    };

    sum_signed = product_sign;
    unsigned_mantissa_sum = mantissa_sum_raw[FULL_SUM_W-1:0];

    mantissa_sum_raw_neg = $unsigned(-$signed(mantissa_sum_raw));
    if (mantissa_sum_raw[FULL_SUM_CARRY_W-1]) begin
      unsigned_mantissa_sum = mantissa_sum_raw_neg[FULL_SUM_W-1:0];
      sum_signed            = ~product_sign;
    end
  end

  leading_zero_counter_top #(
      .DATA_W          (FULL_SUM_W),
      .LZC_DATA_BLOCK_W(4)
  ) leading_zero_counter_top_inst (
      .data_i              (unsigned_mantissa_sum),
      .leading_zero_count_o(mantissa_sum_lz)
  );

  always_comb begin
    sum_rounded_signed = sum_signed;

    sum_exp = product_exp - $signed({1'b0, mantissa_sum_lz}) + (SUM_EXP_ADD_OFFSET) +
        (MANTISSA_W - FRAC_W);
    sum_exp_ovfl = sum_exp[EXP_OVFL_IDX] && !sum_exp[EXP_SIGN_IDX];
    sum_exp_unfl = sum_exp[EXP_OVFL_IDX] && sum_exp[EXP_SIGN_IDX];

    sum_zero = 0;
    mantissa_sum_shift_ovfl = $unsigned(product_exp + LZC_COUNT_OVFL_W'(SUM_EXP_ADD_OFFSET) +
                                        LZC_COUNT_OVFL_W'(MANTISSA_W - FRAC_W));

    if (sum_exp_unfl) begin
      mantissa_sum_shift = mantissa_sum_shift_ovfl[LZC_COUNT_W-1:0];
      sum_zero           = mantissa_sum_shift_ovfl[LZC_COUNT_OVFL_W-1];
    end else begin
      mantissa_sum_shift = mantissa_sum_lz;
    end

    normalized_mantissa = unsigned_mantissa_sum << mantissa_sum_shift;
    sum_frac_raw        = normalized_mantissa[FULL_SUM_W-1-MANTISSA_INT_W-:FRAC_W];
    sticky_sum          = |normalized_mantissa[GUARD_IDX-1:0];
    guard               = normalized_mantissa[GUARD_IDX];

    if (sum_float_flags.c_dominates) begin
      sum_frac_raw       = float_c.frac;
      sticky_sum         = '0;
      guard              = '0;
      sum_exp            = $signed({2'b0, float_c.exp});
      sum_rounded_signed = float_c.sign;
    end else if (sum_exp_unfl || sum_exp == 0) begin
      sum_frac_raw = normalized_mantissa[FULL_SUM_W-1-:FRAC_W];
      sticky_sum   = |normalized_mantissa[GUARD_IDX:0];
      guard        = normalized_mantissa[GUARD_IDX+1];
    end

    round_mantissa = guard && (sticky_sum || sum_float_flags.sticky_c || (sum_frac_raw[0] && !sum_float_flags.ignore_round_even));
    sum_frac_carry = sum_frac_raw + FRAC_W'(round_mantissa);

    sum_rounded_exp = (sum_frac_carry[MANTISSA_W-1] && !sum_exp_ovfl) ? sum_exp + 1 : sum_exp;

    sum_rounded_exp_ovfl = sum_rounded_exp[EXP_OVFL_IDX] && !sum_exp[EXP_SIGN_IDX];
    sum_rounded_exp_unfl = sum_rounded_exp[EXP_OVFL_IDX] && sum_exp[EXP_SIGN_IDX];
    sum_frac_rounded = sum_frac_carry[FRAC_W-1:0];
  end

  always_comb begin
    float_z.sign = sum_rounded_signed;
    float_z.exp  = sum_rounded_exp[EXP_W-1:0];
    float_z.frac = sum_frac_rounded;

    if (sum_float_flags.nan) begin
      float_z.exp  = '1;
      float_z.frac = '1;
    end
    else if (sum_float_flags.inf || sum_rounded_exp_ovfl || (sum_rounded_exp[EXP_W-1:0] == '1)) begin
      float_z.exp  = '1;
      float_z.frac = '0;

      if (sum_float_flags.inf) begin
        float_z.sign = sum_float_flags.sign;
      end
    end else if (sum_rounded_exp_unfl) begin
      float_z.exp  = '0;
      float_z.frac = sum_frac_rounded;
    end
  end

  always_ff @(posedge clk) begin
    z <= float_z;
  end
endmodule

