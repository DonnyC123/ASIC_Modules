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

  localparam DECODE_PIPE_DEPTH    = 0;
  localparam EXECUTION_PIPE_DEPTH = 0;
  localparam ALGIN_OUT_PIPE_DEPTH = 0;
  localparam OUT_PIPE_DEPTH       = 1;

  localparam MANTISSA_W = FRAC_W + MANTISSA_INT_W;

  localparam PRODUCT_MANTISSA_W = 2 * MANTISSA_W;
  localparam FULL_SUM_W         = 3 * MANTISSA_W + SIGN_W + 2 * CARRY_W;
  localparam FULL_SUM_CARRY_W   = FULL_SUM_W + CARRY_W;
  localparam LOW_SUM_W          = PRODUCT_MANTISSA_W + CARRY_W;
  localparam PARTIAL_SUM_LOW_W  = LOW_SUM_W + CARRY_W;
  localparam PARTIAL_SUM_HIGH_W = FULL_SUM_CARRY_W - PARTIAL_SUM_LOW_W + CARRY_W;
  localparam SIGNED_EXP_W       = EXP_W + SIGN_W + 2 * CARRY_W;

  localparam SUM_FLOAT_FLAGS_W = $bits(sum_float_flags_t);

  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_t;

  float_t                                    float_a;
  float_t                                    float_b;
  float_t                                    float_c;
  float_t                                    float_c_2q;
  float_t                                    float_z;


  sum_float_flags_t                          sum_float_flags;
  sum_float_flags_t                          sum_float_flags_2q;
  sum_float_flags_t                          sum_float_flags_3q;

  logic             [        MANTISSA_W-1:0] norm_mant_a;
  logic             [        MANTISSA_W-1:0] norm_mant_a_q;
  logic             [        MANTISSA_W-1:0] norm_mant_b;
  logic             [        MANTISSA_W-1:0] norm_mant_b_q;
  logic             [PRODUCT_MANTISSA_W-1:0] csa_c;
  logic             [PRODUCT_MANTISSA_W-1:0] csa_c_q;

  logic             [PARTIAL_SUM_HIGH_W-1:0] c_upper_slice;
  logic             [PARTIAL_SUM_HIGH_W-1:0] c_upper_slice_q;

  logic                                      product_sign;
  logic                                      product_sign_2q;
  logic signed      [      SIGNED_EXP_W-1:0] product_exp;
  logic signed      [      SIGNED_EXP_W-1:0] product_exp_2q;

  logic             [  FULL_SUM_CARRY_W-1:0] mantissa_sum_raw;
  logic             [  FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_q;
  logic             [  FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_neg;

  logic             [        FULL_SUM_W-1:0] unsigned_mantissa_sum;
  logic                                      sum_signed;

  float_t                                    float_sum_rounded;
  float_t                                    float_sum_rounded_q;
  logic                                      sum_rounded_exp_ovfl;
  logic                                      sum_rounded_exp_ovfl_q;
  logic                                      sum_rounded_exp_unfl;
  logic                                      sum_rounded_exp_unfl_q;


  always_comb begin
    float_a = float_t'(a);
    float_b = float_t'(b);
    float_c = float_t'(c);
  end

  mac_float_decode #(
      .float_t           (float_t),
      .SIGNED_EXP_W      (SIGNED_EXP_W),
      .MANTISSA_W        (MANTISSA_W),
      .EXP_W             (EXP_W),
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
      .norm_mant_a_o    (norm_mant_a),
      .norm_mant_b_o    (norm_mant_b)
  );


  data_pipeline #(
      .DATA_W    (MANTISSA_W + MANTISSA_W + PRODUCT_MANTISSA_W + PARTIAL_SUM_HIGH_W),
      .PIPE_DEPTH(DECODE_PIPE_DEPTH),
      .RST_EN    (0)
  ) decode_to_execution_pipe (
      .clk   (clk),
      .rst_n (1'b1),
      .data_i({c_upper_slice, csa_c, norm_mant_a, norm_mant_b}),
      .data_o({c_upper_slice_q, csa_c_q, norm_mant_a_q, norm_mant_b_q})
  );

  data_pipeline #(
      .DATA_W    (1 + SIGNED_EXP_W + SUM_FLOAT_FLAGS_W + DATA_W),
      .PIPE_DEPTH(DECODE_PIPE_DEPTH + EXECUTION_PIPE_DEPTH),
      .RST_EN    (0)
  ) decode_to_round_pipe (
      .clk   (clk),
      .rst_n (1'b1),
      .data_i({sum_float_flags, product_sign, product_exp, float_c}),
      .data_o({sum_float_flags_2q, product_sign_2q, product_exp_2q, float_c_2q})
  );

  mac_float_execution #(
      .MANTISSA_W        (MANTISSA_W),
      .PRODUCT_MANTISSA_W(PRODUCT_MANTISSA_W),
      .FULL_SUM_W        (FULL_SUM_W),
      .FULL_SUM_CARRY_W  (FULL_SUM_CARRY_W)
  ) mac_float_execution_inst (
      .c_upper_slice_i   (c_upper_slice_q),
      .csa_c_i           (csa_c_q),
      .norm_mant_a_i     (norm_mant_a_q),
      .norm_mant_b_i     (norm_mant_b_q),
      .mantissa_sum_raw_o(mantissa_sum_raw)
  );

  data_pipeline #(
      .DATA_W    (FULL_SUM_CARRY_W),
      .PIPE_DEPTH(EXECUTION_PIPE_DEPTH),
      .RST_EN    (0)
  ) execution_to_round_pipe (
      .clk   (clk),
      .rst_n (1'b1),
      .data_i(mantissa_sum_raw),
      .data_o(mantissa_sum_raw_q)
  );
  // Might be better to move before flip_flop

  always_comb begin
    unsigned_mantissa_sum = mantissa_sum_raw_q[FULL_SUM_W-1:0];
    sum_signed            = product_sign_2q;
    mantissa_sum_raw_neg  = $unsigned(-$signed(mantissa_sum_raw_q));
    if (mantissa_sum_raw_q[FULL_SUM_CARRY_W-1]) begin
      unsigned_mantissa_sum = mantissa_sum_raw_neg[FULL_SUM_W-1:0];
      sum_signed            = ~product_sign_2q;
    end
  end

  mac_float_align_round_sum #(
      .EXP_W       (EXP_W),
      .FRAC_W      (FRAC_W),
      .FULL_SUM_W  (FULL_SUM_W),
      .SIGNED_EXP_W(SIGNED_EXP_W),
      .float_t     (float_t)
  ) mac_float_align_round_sum_inst (
      .float_c_i              (float_c_2q),
      .sum_float_flags_i      (sum_float_flags_2q),
      .sum_signed_i           (sum_signed),
      .product_exp_i          (product_exp_2q),
      .unsigned_mantissa_sum_i(unsigned_mantissa_sum),
      .float_sum_rounded      (float_sum_rounded),
      .sum_rounded_exp_ovfl_o (sum_rounded_exp_ovfl),
      .sum_rounded_exp_unfl_o (sum_rounded_exp_unfl)
  );

  data_pipeline #(
      .DATA_W    (1 + 1 + DATA_W + SUM_FLOAT_FLAGS_W),
      .PIPE_DEPTH(ALGIN_OUT_PIPE_DEPTH),
      .RST_EN    (0)
  ) round_to_output_pipe (
      .clk(clk),
      .rst_n(1'b1),
      .data_i({float_sum_rounded, sum_rounded_exp_ovfl, sum_rounded_exp_unfl, sum_float_flags_2q}),
      .data_o({
        float_sum_rounded_q, sum_rounded_exp_ovfl_q, sum_rounded_exp_unfl_q, sum_float_flags_3q
      })
  );

  always_comb begin
    float_z = float_sum_rounded_q;

    if (sum_float_flags_3q.nan) begin
      float_z.exp  = '1;
      float_z.frac = '1;
    end else if (sum_rounded_exp_unfl_q) begin
      float_z.exp = '0;
    end else if (sum_float_flags_3q.inf || sum_rounded_exp_ovfl_q || (float_sum_rounded_q.exp == '1)) begin
      float_z.exp  = '1;
      float_z.frac = '0;
      if (sum_float_flags_3q.inf) begin
        float_z.sign = sum_float_flags_3q.sign;
      end
    end
    z = float_z;
  end


  data_pipeline #(
      .DATA_W    (DATA_W),
      .PIPE_DEPTH(OUT_PIPE_DEPTH),
      .RST_EN    (0),
      .CLK_EN    (0)
  ) output_pipe (
      .clk   (clk),
      .clk_en(),
      .rst_n (1'b1),
      .data_i(float_z),
      .data_o(z)
  );
endmodule

