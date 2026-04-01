module mac_float_mixed #(
    parameter  EXP_IN_W   = 5,
    parameter  FRAC_IN_W  = 10,
    parameter  EXP_OUT_W  = 5,
    parameter  FRAC_OUT_W = 10,
    localparam DIN_W      = FRAC_IN_W + EXP_IN_W + 1,
    localparam DOUT_W     = FRAC_OUT_W + EXP_OUT_W + 1
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              valid_i,
    input  logic [ DIN_W-1:0] a,
    input  logic [ DIN_W-1:0] b,
    input  logic [ DIN_W-1:0] c,
    output logic              valid_o,
    output logic [DOUT_W-1:0] z
);

  import mac_float_pkg::*;

  localparam DECODE_PIPE_DEPTH    = 0;
  localparam EXECUTION_PIPE_DEPTH = 0;
  localparam ALGIN_OUT_PIPE_DEPTH = 0;
  localparam OUT_PIPE_DEPTH       = 1;

  localparam MANTISSA_IN_W  = FRAC_IN_W + MANTISSA_INT_W;
  localparam MANTISSA_OUT_W = FRAC_OUT_W + MANTISSA_INT_W;

  localparam PRODUCT_MANTISSA_W = 2 * MANTISSA_IN_W;
  localparam C_LOWER_SLICE_W    = PRODUCT_MANTISSA_W + FRAC_OUT_W - FRAC_IN_W;
  localparam C_UPPER_SLICE_W    = MANTISSA_OUT_W + 3;
  localparam FULL_SUM_CARRY_W   = C_LOWER_SLICE_W + MANTISSA_OUT_W + 4;
  localparam FULL_SUM_W         = FULL_SUM_CARRY_W - 1;
  localparam SIGNED_EXP_W       = EXP_IN_W + SIGN_W + 2 * CARRY_W;

  localparam SUM_FLOAT_FLAGS_W = $bits(sum_float_flags_t);

  typedef struct packed {
    logic sign;
    logic [EXP_IN_W-1:0] exp;
    logic [FRAC_IN_W-1:0] frac;
  } float_in_t;

  typedef struct packed {
    logic sign;
    logic [EXP_OUT_W-1:0] exp;
    logic [FRAC_OUT_W-1:0] frac;
  } float_out_t;

  float_in_t                               float_a;
  float_in_t                               float_b;
  float_in_t                               float_c;
  float_in_t                               float_c_2q;
  float_in_t                               float_c_3q;
  float_out_t                              float_c_upscaled;

  float_out_t                              float_z;

  sum_float_flags_t                        sum_float_flags;
  sum_float_flags_t                        sum_float_flags_2q;
  sum_float_flags_t                        sum_float_flags_3q;

  logic             [   MANTISSA_IN_W-1:0] norm_mant_a;
  logic             [   MANTISSA_IN_W-1:0] norm_mant_a_q;
  logic             [   MANTISSA_IN_W-1:0] norm_mant_b;
  logic             [   MANTISSA_IN_W-1:0] norm_mant_b_q;
  logic             [ C_LOWER_SLICE_W-1:0] c_lower_slice;
  logic             [ C_LOWER_SLICE_W-1:0] c_lower_slice_q;
  logic             [ C_UPPER_SLICE_W-1:0] c_upper_slice;
  logic             [ C_UPPER_SLICE_W-1:0] c_upper_slice_q;

  logic                                    product_sign;
  logic                                    product_sign_2q;
  logic signed      [    SIGNED_EXP_W-1:0] product_exp;
  logic signed      [    SIGNED_EXP_W-1:0] product_exp_2q;

  logic signed      [FULL_SUM_CARRY_W-1:0] mantissa_sum_raw;
  logic signed      [FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_q;
  logic             [FULL_SUM_CARRY_W-1:0] mantissa_sum_raw_neg;
  logic             [      FULL_SUM_W-1:0] unsigned_mantissa_sum;
  logic                                    sum_signed;

  float_out_t                              float_sum_rounded;
  float_out_t                              float_sum_rounded_q;

  logic                                    sum_rounded_exp_ovfl;
  logic                                    sum_rounded_exp_ovfl_q;
  logic                                    sum_rounded_exp_unfl;
  logic                                    sum_rounded_exp_unfl_q;

  logic                                    valid_decode_q;
  logic                                    valid_exec_q;
  logic                                    valid_round_q;
  logic                                    valid_final_q;

  always_comb begin
    float_a = float_in_t'(a);
    float_b = float_in_t'(b);
    float_c = float_in_t'(c);
  end

  mac_float_decode #(
      .float_t     (float_in_t),
      .SIGNED_EXP_W(SIGNED_EXP_W),
      .FRAC_IN_W   (FRAC_IN_W),
      .EXP_IN_W    (EXP_IN_W),
      .FRAC_OUT_W  (FRAC_OUT_W),
      .EXP_OUT_W   (EXP_OUT_W)
  ) mac_float_decode_inst (
      .float_a_i        (float_a),
      .float_b_i        (float_b),
      .float_c_i        (float_c),
      .sum_float_flags_o(sum_float_flags),
      .product_sign_o   (product_sign),
      .product_exp_o    (product_exp),
      .c_upper_slice_o  (c_upper_slice),
      .c_lower_slice_o  (c_lower_slice),
      .norm_mant_a_o    (norm_mant_a),
      .norm_mant_b_o    (norm_mant_b)
  );

  data_pipeline #(
      .DATA_W(1 + C_UPPER_SLICE_W + C_LOWER_SLICE_W + MANTISSA_IN_W + MANTISSA_IN_W),
      .PIPE_DEPTH(DECODE_PIPE_DEPTH),
      .RST_EN(1)
  ) decode_to_execution_pipe (
      .clk   (clk),
      .rst_n (rst_n),
      .clk_en('1),
      .data_i({valid_i, c_upper_slice, c_lower_slice, norm_mant_a, norm_mant_b}),
      .data_o({valid_decode_q, c_upper_slice_q, c_lower_slice_q, norm_mant_a_q, norm_mant_b_q})
  );

  data_pipeline #(
      .DATA_W    (1 + SUM_FLOAT_FLAGS_W + 1 + SIGNED_EXP_W + DIN_W),
      .PIPE_DEPTH(DECODE_PIPE_DEPTH + EXECUTION_PIPE_DEPTH),
      .RST_EN    (1)
  ) decode_to_round_pipe (
      .clk   (clk),
      .rst_n (rst_n),
      .clk_en('1),
      .data_i({valid_i, sum_float_flags, product_sign, product_exp, float_c}),
      .data_o({valid_round_q, sum_float_flags_2q, product_sign_2q, product_exp_2q, float_c_2q})
  );

  mac_float_execution #(
      .MANTISSA_W        (MANTISSA_IN_W),
      .PRODUCT_MANTISSA_W(PRODUCT_MANTISSA_W),
      .C_LOWER_SLICE_W   (C_LOWER_SLICE_W),
      .FULL_SUM_W        (FULL_SUM_W),
      .FULL_SUM_CARRY_W  (FULL_SUM_CARRY_W)
  ) mac_float_execution_inst (
      .c_upper_slice_i   (c_upper_slice_q),
      .c_lower_slice_i   (c_lower_slice_q),
      .norm_mant_a_i     (norm_mant_a_q),
      .norm_mant_b_i     (norm_mant_b_q),
      .mantissa_sum_raw_o(mantissa_sum_raw)
  );

  data_pipeline #(
      .DATA_W    (1 + FULL_SUM_CARRY_W),
      .PIPE_DEPTH(EXECUTION_PIPE_DEPTH),
      .RST_EN    (1)
  ) execution_to_round_pipe (
      .clk   (clk),
      .rst_n (rst_n),
      .clk_en('1),
      .data_i({valid_decode_q, mantissa_sum_raw}),
      .data_o({valid_exec_q, mantissa_sum_raw_q})
  );

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
      .EXP_IN_W   (EXP_IN_W),
      .FRAC_IN_W  (FRAC_IN_W),
      .EXP_OUT_W  (EXP_OUT_W),
      .FRAC_OUT_W (FRAC_OUT_W),
      .FULL_SUM_W (FULL_SUM_W),
      .float_in_t (float_in_t),
      .float_out_t(float_out_t)
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
      .DATA_W    (1 + DOUT_W + 1 + 1 + SUM_FLOAT_FLAGS_W + DIN_W),
      .PIPE_DEPTH(ALGIN_OUT_PIPE_DEPTH),
      .RST_EN    (1)
  ) round_to_output_pipe (
      .clk(clk),
      .rst_n(rst_n),
      .clk_en('1),
      .data_i({
        valid_round_q,
        float_sum_rounded,
        sum_rounded_exp_ovfl,
        sum_rounded_exp_unfl,
        sum_float_flags_2q,
        float_c_2q
      }),
      .data_o({
        valid_final_q,
        float_sum_rounded_q,
        sum_rounded_exp_ovfl_q,
        sum_rounded_exp_unfl_q,
        sum_float_flags_3q,
        float_c_3q
      })
  );

  upscale_float #(
      .EXP_IN_W  (EXP_IN_W),
      .FRAC_IN_W (FRAC_IN_W),
      .EXP_OUT_W (EXP_OUT_W),
      .FRAC_OUT_W(FRAC_OUT_W)
  ) upscale_float_inst (
      .float_i(float_c_3q),
      .float_o(float_c_upscaled)
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
    end else if (sum_float_flags_3q.c_dominates) begin
      float_z = float_c_upscaled;
    end
  end

  data_pipeline #(
      .DATA_W    (1 + DOUT_W),
      .PIPE_DEPTH(OUT_PIPE_DEPTH),
      .RST_EN    (1)
  ) output_pipe (
      .clk   (clk),
      .rst_n (rst_n),
      .clk_en('1),
      .data_i({valid_final_q, DOUT_W'(float_z)}),
      .data_o({valid_o, z})
  );

endmodule
