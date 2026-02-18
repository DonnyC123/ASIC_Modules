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

  localparam PROD_EXP_W          = EXP_W + 1;
  localparam GUARD_W             = 1;
  localparam MANTISSA_W          = 1 + FRAC_W;
  localparam PRODUCT_MANTISSA_W  = 2 * MANTISSA_W;
  localparam PRODUCT_LOW_SUM_W   = PRODUCT_MANTISSA_W + 1;
  localparam C_SHIFTED_W         = 3 * MANTISSA_W;
  localparam C_SHIFT_RAW_W       = 4 * MANTISSA_W + GUARD_W;
  localparam C_SHIFT_MAX         = 3 * MANTISSA_W + GUARD_W;
  localparam C_SHIFT_FACTOR_W    = $clog2(C_SHIFT_RAW_W);
  localparam MANTISSA_SUM_W      = C_SHIFTED_W + 1;
  localparam SUM_EXP_ADD         = MANTISSA_SUM_W - PRODUCT_MANTISSA_W + 1;
  localparam MANTISSA_SUM_LOW_W  = PRODUCT_MANTISSA_W + 1;
  localparam MANTISSA_SUM_HIGH_W = MANTISSA_W + 1;
  localparam NUM_PARTIAL_PRODUCT = MANTISSA_W;
  localparam MANTISSA_SUM_LZ_W   = $clog2(MANTISSA_SUM_W + 1);
  localparam NUM_CSA_TREE_ROWS   = NUM_PARTIAL_PRODUCT + 1;
  localparam BIAS                = (1 << (EXP_W - 1)) - 1;

  typedef struct packed {
    logic                        msb;
    logic [C_SHIFT_FACTOR_W-1:0] exp;
  } c_shift_factor_t;

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

  float_t                                    float_a;
  float_t                                    float_b;
  float_t                                    float_c;
  float_t                                    float_z;

  logic            [         MANTISSA_W-1:0] mantissa_a;
  logic            [         MANTISSA_W-1:0] mantissa_b;
  logic            [         MANTISSA_W-1:0] mantissa_c;

  logic            [              EXP_W-1:0] exp_a;
  logic            [              EXP_W-1:0] exp_b;
  logic            [              EXP_W-1:0] exp_c;

  ext_exp_t                                  product_exp;
  c_shift_factor_t                           c_shift_amount;

  logic                                      product_sign;
  logic            [  PRODUCT_LOW_SUM_W-1:0] partial_products      [NUM_PARTIAL_PRODUCT];

  logic                                      c_shift_ovfl;
  logic                                      c_shift_unfl;
  logic                                      subtract_c;

  logic            [      C_SHIFT_RAW_W-1:0] c_shifted_raw;
  logic            [     MANTISSA_SUM_W-1:0] c_shifted_eff;
  logic            [  PRODUCT_LOW_SUM_W-1:0] csa_c;
  logic            [  PRODUCT_LOW_SUM_W-1:0] csa_summands          [  NUM_CSA_TREE_ROWS];
  logic            [  PRODUCT_LOW_SUM_W-1:0] csa_tree_sum;
  logic            [  PRODUCT_LOW_SUM_W-1:0] csa_tree_carry;

  logic            [MANTISSA_SUM_HIGH_W-1:0] mantissa_sum_upper;
  logic            [ MANTISSA_SUM_LOW_W-1:0] mantissa_sum_lower;
  logic            [     MANTISSA_SUM_W-1:0] mantissa_sum;
  logic            [     MANTISSA_SUM_W-1:0] unsigned_mantissa_sum;
  logic            [     MANTISSA_SUM_W-1:0] normalized_mantissa;

  logic            [  MANTISSA_SUM_LZ_W-1:0] mantissa_sum_lz;
  logic            [  MANTISSA_SUM_LZ_W-1:0] mantissa_sum_shift;
  logic                                      sum_signed;
  sum_exp_t                                  sum_exp;
  logic                                      sum_exp_ovfl;
  logic                                      sum_exp_unfl;

  function automatic void unpack_float(input float_t float_i, output logic [EXP_W-1:0] exp_o,
                                       output logic [MANTISSA_W-1:0] mantissa_o);
    mantissa_o = {1'b1, float_i.frac};
    exp_o      = float_i.exp;

    if (float_i.exp == '0) begin
      exp_o[0]                 = 1'b1;
      mantissa_o[MANTISSA_W-1] = 1'b0;
    end
  endfunction

  always_comb begin
    float_a = float_t'(a);
    float_b = float_t'(b);
    float_c = float_t'(c);

    unpack_float(float_a, exp_a, mantissa_a);
    unpack_float(float_b, exp_b, mantissa_b);
    unpack_float(float_c, exp_c, mantissa_c);
  end

  always_comb begin
    product_sign = float_a.sign ^ float_b.sign;
    product_exp = (exp_a + exp_b) - $unsigned(EXP_W'(BIAS));

    c_shift_amount = c_shift_factor_t'(float_c.exp) - c_shift_factor_t'(product_exp) + c_shift_factor_t'(FRAC_W) + c_shift_factor_t'(MANTISSA_W);

    c_shift_unfl = product_exp[EXP_W-1] && c_shift_amount.msb;
    c_shift_ovfl = (c_shift_amount > C_SHIFT_MAX) && !c_shift_unfl;
    subtract_c = (product_sign ^ float_c.sign) && !c_shift_unfl;
  end


  always_comb begin
    c_shifted_raw = (C_SHIFT_RAW_W'(mantissa_c) << c_shift_amount);
    c_shifted_eff =  {~{MANTISSA_SUM_W{c_shift_unfl}}}
                  & (subtract_c
                  ? ~ c_shifted_raw[C_SHIFT_RAW_W-1:MANTISSA_W] 
                  : c_shifted_raw[C_SHIFT_RAW_W-1:MANTISSA_W]);

    csa_c = {1'b0, c_shifted_eff[PRODUCT_MANTISSA_W-1:0]};


    foreach (partial_products[i]) begin
      logic [MANTISSA_W-1:0] partial_product;

      partial_product     = mantissa_a & {MANTISSA_W{mantissa_b[i]}};
      partial_products[i] = {{MANTISSA_W + 1{1'b0}}, partial_product} << i;  // get rid of + 1
    end

    for (int i = 0; i < NUM_PARTIAL_PRODUCT; i++) begin
      csa_summands[i] = partial_products[i];
    end

    csa_summands[NUM_CSA_TREE_ROWS-1] = csa_c;
  end

  wallace_tree_recursive #(
      .DATA_W  (PRODUCT_LOW_SUM_W),
      .NUM_ROWS(NUM_CSA_TREE_ROWS)
  ) wallace_tree_inst (
      .partial_sums(csa_summands),
      .sum         (csa_tree_sum),
      .carry       (csa_tree_carry)
  );

  always_comb begin
    mantissa_sum_lower = csa_tree_sum + {csa_tree_carry[PRODUCT_MANTISSA_W-1:1], subtract_c};
    mantissa_sum_upper = MANTISSA_SUM_HIGH_W'(c_shifted_eff[C_SHIFTED_W-1 : PRODUCT_MANTISSA_W])
                       + MANTISSA_SUM_HIGH_W'(mantissa_sum_lower[MANTISSA_SUM_LOW_W-1]);

    mantissa_sum = {mantissa_sum_upper, mantissa_sum_lower[PRODUCT_MANTISSA_W-1:0]};
    sum_signed = product_sign;
    unsigned_mantissa_sum = mantissa_sum;

    if (mantissa_sum[MANTISSA_SUM_W-1]) begin
      unsigned_mantissa_sum = -mantissa_sum;
      sum_signed            = ~product_sign;
    end
  end

  leading_zero_counter_top #(
      .DATA_W          (MANTISSA_SUM_W),
      .LZC_DATA_BLOCK_W(4)
  ) leading_zero_counter_top_inst (
      .data_i              (unsigned_mantissa_sum),
      .leading_zero_count_o(mantissa_sum_lz)
  );

  always_comb begin
    sum_exp      = sum_exp_t'(product_exp) - sum_exp_t'(mantissa_sum_lz) + sum_exp_t'(SUM_EXP_ADD);
    sum_exp_ovfl = exp_a[EXP_W-1] && |sum_exp.msb;
    sum_exp_unfl = !exp_a[EXP_W-1] && |sum_exp.msb;
  end

  always_comb begin
    if (sum_exp_unfl) begin
      mantissa_sum_shift = product_exp[MANTISSA_SUM_LZ_W-1:0];
    end else begin
      mantissa_sum_shift = mantissa_sum_lz;
    end
    normalized_mantissa = unsigned_mantissa_sum << mantissa_sum_shift;
  end

  always_comb begin
    float_z.sign = product_sign;
    float_z.exp  = sum_exp.exp[EXP_W-1:0];
    float_z.frac = normalized_mantissa[MANTISSA_SUM_W-2-:FRAC_W];

    if (c_shift_ovfl) begin
      float_z = float_c;
    end else begin
      if (sum_exp_ovfl) begin  // Wanted to add unique0 here
        float_z.exp  = '1;
        float_z.frac = '0;
      end else if (sum_exp_unfl) begin
        float_z.exp  = '0;
        float_z.frac = normalized_mantissa[MANTISSA_SUM_W-2-:FRAC_W];
      end
    end
  end

  assign z = float_z;

endmodule

