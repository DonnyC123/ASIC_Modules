module mac_float #(
    parameter  EXP_W  = 5,
    parameter  FRAC_W = 10,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic [DATA_W-1:0] a,
    input  logic [DATA_W-1:0] b,
    input  logic [DATA_W-1:0] c,
    output logic [DATA_W-1:0] z
);
  localparam CARRY_W              = 1;  // Previously OVFL_BI
  localparam MANTISSA_INT_W       = 1;
  localparam GUARD_W              = 1;
  localparam MANTISSA_W           = FRAC_W + MANTISSA_INT_W;
  localparam BIAS                 = (1 << (EXP_W - 1)) - 1;
  localparam NUM_PARTIAL_PRODUCTS = MANTISSA_W;
  localparam NUM_WALLACE_INPUTS   = NUM_PARTIAL_PRODUCTS + 1;

  localparam PRODUCT_MANTISSA_W = 2 * MANTISSA_W;
  localparam LOW_SUM_W          = PRODUCT_MANTISSA_W + CARRY_W;  // Previously LOW_SUM_W

  localparam FULL_SUM_W       = 3 * MANTISSA_W + CARRY_W;  // Previously FULL_SUM_W
  localparam FULL_SUM_CARRY_W = FULL_SUM_W + CARRY_W;  // Previously FULL_SUM_CARRY_W

  localparam PARTIAL_SUM_LOW_W    = LOW_SUM_W + CARRY_W;
  localparam PARTIAL_SUM_HIGH_W   = FULL_SUM_CARRY_W - PARTIAL_SUM_LOW_W + CARRY_W; // Prev PARTIAL_SUM_HIGH

  localparam LZC_COUNT_W        = $clog2(FULL_SUM_W + 1);  // Previously LZC_COUNT_W
  localparam SUM_EXP_ADD_OFFSET = FULL_SUM_W - PRODUCT_MANTISSA_W;  // Previously SUM_EXP_ADD_OFFSET

  localparam DENORMALIZED_IDX    = PRODUCT_MANTISSA_W + 2;
  localparam NORMAL_FRAC_LSB_IDX = FULL_SUM_W - 1 - FRAC_W;
  localparam GUARD_IDX           = NORMAL_FRAC_LSB_IDX - 1;

  typedef struct packed {
    logic             msb;
    logic [EXP_W-1:0] exp;
  } ext_exp_t;

  typedef struct packed {
    logic [1:0]       msb;
    logic [EXP_W-1:0] exp;
  } sum_exp_t;

  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_t;

  typedef struct packed {
    logic                  sign;
    logic [EXP_W-1:0]      exp;
    logic [MANTISSA_W-1:0] mantissa;
  } unpacked_float_t;

  float_t                                   float_a;
  float_t                                   float_b;
  float_t                                   float_c;
  float_t                                   float_z;

  unpacked_float_t                          unpacked_a;
  unpacked_float_t                          unpacked_b;
  unpacked_float_t                          unpacked_c;

  ext_exp_t                                 product_exp;

  logic                                     product_sign;
  logic            [         LOW_SUM_W-1:0] partial_products      [NUM_PARTIAL_PRODUCTS];
  logic            [PRODUCT_MANTISSA_W-1:0] csa_c;
  logic                                     c_dominates;

  logic            [         LOW_SUM_W-1:0] csa_summands          [  NUM_WALLACE_INPUTS];
  logic            [         LOW_SUM_W-1:0] csa_tree_sum;
  logic            [         LOW_SUM_W-1:0] csa_tree_carry;
  logic            [  PARTIAL_SUM_HIGH_W:0] upper_sum_temp;
  logic            [PARTIAL_SUM_HIGH_W-1:0] c_upper_slice;
  logic            [PARTIAL_SUM_HIGH_W-1:0] mantissa_sum_upper;
  logic            [ PARTIAL_SUM_LOW_W-1:0] mantissa_sum_lower;
  logic            [  FULL_SUM_CARRY_W-1:0] mantissa_sum_raw;
  logic            [  FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_neg;

  logic            [        FULL_SUM_W-1:0] unsigned_mantissa_sum;
  logic            [        FULL_SUM_W-1:0] normalized_mantissa;

  logic            [            FRAC_W-1:0] sum_frac_raw;
  logic            [        MANTISSA_W-1:0] sum_frac_carry;
  logic            [            FRAC_W-1:0] sum_frac_rounded;

  logic            [       LZC_COUNT_W-1:0] mantissa_sum_lz;
  logic            [       LZC_COUNT_W-1:0] mantissa_sum_shift;

  sum_exp_t                                 sum_exp;
  logic                                     sum_signed;
  logic                                     sum_exp_ovfl;
  logic                                     sum_exp_unfl;

  sum_exp_t                                 sum_rounded_exp;
  logic                                     sum_rounded_exp_ovfl;
  logic                                     sum_rounded_exp_unfl;

  logic                                     sum_inf;
  logic                                     sum_inf_sign;
  logic                                     sum_nan;
  logic                                     sticky_c;
  logic                                     sticky_sum;
  logic                                     guard;
  logic                                     round_mantissa;

  function automatic unpacked_float_t unpack_float(input float_t float_i);
    unpacked_float_t unpacked_o;

    unpacked_o.sign     = float_i.sign;
    unpacked_o.exp      = float_i.exp;
    unpacked_o.mantissa = {1'b1, float_i.frac};

    if (float_i.exp == '0) begin
      unpacked_o.exp[0]                 = 1'b1;
      unpacked_o.mantissa[MANTISSA_W-1] = 1'b0;
    end

    return unpacked_o;
  endfunction

  always_comb begin
    float_a    = float_t'(a);
    float_b    = float_t'(b);
    float_c    = float_t'(c);

    unpacked_a = unpack_float(float_a);
    unpacked_b = unpack_float(float_b);
    unpacked_c = unpack_float(float_c);
  end

  special_float_handler #(
      .float_t(float_t)
  ) special_float_handler_inst (
      .float_a_i (float_a),
      .float_b_i (float_b),
      .float_c_i (float_c),
      .inf_o     (sum_inf),
      .inf_sign_o(sum_inf_sign),
      .nan_o     (sum_nan)
  );

  always_comb begin
    product_sign = float_a.sign ^ float_b.sign;
    product_exp  = (unpacked_a.exp + unpacked_b.exp) - $unsigned(EXP_W'(BIAS));

    foreach (partial_products[i]) begin
      logic [MANTISSA_W-1:0] partial_product;

      partial_product     = unpacked_a.mantissa & {MANTISSA_W{unpacked_b.mantissa[i]}};
      partial_products[i] = {{MANTISSA_W + 1{1'b0}}, partial_product} << i;
    end
  end



  align_addend #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) align_addend_inst (
      .unpacked_c_i    (unpacked_c),
      .product_exp_i   (product_exp),
      .product_sign_i  (product_sign),
      .c_upper_slice_o (c_upper_slice),
      .csa_c_o         (csa_c),
      .c_lower_sticky_o(sticky_c),
      .c_dominates_o   (c_dominates)
  );

  always_comb begin
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
    sum_exp      = sum_exp_t'({product_exp.msb, product_exp}) - sum_exp_t'(mantissa_sum_lz) + sum_exp_t'(SUM_EXP_ADD_OFFSET) + sum_exp_t'(MANTISSA_W-FRAC_W);
    sum_exp_ovfl = unpacked_a.exp[EXP_W-1] && |sum_exp.msb;
    sum_exp_unfl = !unpacked_a.exp[EXP_W-1] && |sum_exp.msb;
  end


  always_comb begin
    if (sum_exp_unfl) begin
      mantissa_sum_shift = 0;
    end else begin
      mantissa_sum_shift = mantissa_sum_lz;
    end

    normalized_mantissa = unsigned_mantissa_sum << mantissa_sum_shift;

    sum_frac_raw        = normalized_mantissa[FULL_SUM_W-1-MANTISSA_INT_W-:FRAC_W];
    sticky_sum          = |normalized_mantissa[GUARD_IDX-1:0];
    guard               = normalized_mantissa[GUARD_IDX];

    if (sum_exp_unfl) begin
      sum_frac_raw = normalized_mantissa[DENORMALIZED_IDX-1-:FRAC_W];
      sticky_sum   = |normalized_mantissa[DENORMALIZED_IDX-1-FRAC_W-2:0];
      guard        = normalized_mantissa[DENORMALIZED_IDX-1-FRAC_W-1];
    end

    round_mantissa       = guard && (sticky_sum || sticky_c || sum_frac_raw[0]);
    sum_frac_carry       = sum_frac_raw + FRAC_W'(round_mantissa);

    sum_rounded_exp      = sum_exp + sum_exp_t'((sum_frac_carry[MANTISSA_W-1] && !sum_exp_ovfl));
    sum_rounded_exp_ovfl = unpacked_a.exp[EXP_W-1] && |sum_rounded_exp.msb;
    sum_rounded_exp_unfl = !unpacked_a.exp[EXP_W-1] && |sum_rounded_exp.msb;
    sum_frac_rounded     = sum_frac_carry[FRAC_W-1:0];
  end

  always_comb begin
    float_z.sign = sum_signed;
    float_z.exp  = sum_rounded_exp[EXP_W-1:0];
    float_z.frac = sum_frac_rounded;
    if (float_z.exp == '1) begin
      float_z.frac = '0;
    end

    if (sum_nan) begin  // Wanted to add unique0 here
      float_z.exp  = '1;
      float_z.frac = '1;
    end else if (sum_inf) begin
      float_z.sign = sum_inf_sign;
      float_z.exp  = '1;
      float_z.frac = '0;
    end else begin
      if (sum_rounded_exp_ovfl) begin
        float_z.exp  = '1;
        float_z.frac = '0;
      end else if (c_dominates) begin
        float_z = float_c;
      end else if (sum_rounded_exp_unfl) begin  // This is the normalization case. Figure out if its incorrect
        float_z.exp  = '0;
        float_z.frac = sum_frac_rounded;
      end
    end
  end

  assign z = float_z;
endmodule

