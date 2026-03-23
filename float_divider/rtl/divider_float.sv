module divider_float #(
    parameter  EXP_W  = 5,
    parameter  FRAC_W = 10,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start_i,
    input  logic [DATA_W-1:0] a,
    input  logic [DATA_W-1:0] b,
    output logic [DATA_W-1:0] z,
    output logic              z_valid
);

  import divider_float_pkg::*;

  localparam DECODE_PIPE_DEPTH  = 0;
  localparam DIVIDER_PIPE_DEPTH = 0;
  localparam OUT_PIPE_DEPTH     = 1;

  localparam MANTISSA_W     = FRAC_W + 1;
  localparam SIGNED_EXP_W   = EXP_W + SIGN_W + 2 * CARRY_W;
  localparam QUOTIENT_RAW_W = OFFSET_BIT_W + MANTISSA_W + GUARD_W;

  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_t;

  float_t                                     float_a;
  float_t                                     float_b;
  float_t                                     float_quotient;
  float_t                                     float_z;

  quotient_float_flags_t                      float_quotient_flags_d;
  quotient_float_flags_t                      float_quotient_flags_q;

  logic                  [    MANTISSA_W-1:0] norm_mant_a;
  logic                  [    MANTISSA_W-1:0] norm_mant_a_q;
  logic                  [    MANTISSA_W-1:0] norm_mant_b;
  logic                  [    MANTISSA_W-1:0] norm_mant_b_q;

  logic signed           [  SIGNED_EXP_W-1:0] quotient_exp_d;
  logic signed           [  SIGNED_EXP_W-1:0] quotient_exp_q;

  logic                                       start_divider_q;

  logic                                       divider_done;
  logic                                       divider_done_q;

  logic                  [QUOTIENT_RAW_W-1:0] quotient_raw;
  logic                  [QUOTIENT_RAW_W-1:0] quotient_raw_q;


  always_comb begin
    float_a = float_t'(a);
    float_b = float_t'(b);
  end

  divider_float_decoder #(
      .EXP_W       (EXP_W),
      .MANTISSA_W  (MANTISSA_W),
      .SIGNED_EXP_W(SIGNED_EXP_W),
      .float_t     (float_t)
  ) divider_float_decoder_inst (
      .float_a_i             (float_a),
      .float_b_i             (float_b),
      .norm_mant_a_o         (norm_mant_a),
      .norm_mant_b_o         (norm_mant_b),
      .float_quotient_flags_o(float_quotient_flags_d),
      .quotient_exp_o        (quotient_exp_d)
  );


  data_status_pipeline #(
      .DATA_W    (MANTISSA_W + MANTISSA_W),
      .STATUS_W  (1),
      .PIPE_DEPTH(DECODE_PIPE_DEPTH)
  ) decode_to_divider_pipe (
      .clk     (clk),
      .rst_n   (rst_n),
      .data_i  ({norm_mant_a, norm_mant_b, float_quotient_flags_d, quotient_exp_d}),
      .status_i(start_i),
      .data_o  ({norm_mant_a_q, norm_mant_b_q, float_quotient_flags_q, quotient_exp_q}),
      .status_o(start_divider_q)
  );

  mantissa_divider_pipe #(
      .MANTISSA_W(MANTISSA_W)
  ) mantissa_divider_inst (
      .dividend_i    (norm_mant_a_q),
      .divisor_i     (norm_mant_b_q),
      .quotient_raw_o(quotient_raw),
      .sticky_o      (sticky)
  );

  data_status_pipeline #(
      .DATA_W    (QUOTIENT_RAW_W + 1),
      .STATUS_W  (1),
      .PIPE_DEPTH(DIVIDER_PIPE_DEPTH)
  ) divider_to_round_pipe (
      .clk     (clk),
      .rst_n   (rst_n),
      .data_i  ({quotient_raw, sticky}),
      .status_i(start_divider_q),
      .data_o  ({quotient_raw_q, sticky_q}),
      .status_o(divider_done_q)
  );

  quotient_rounder #(
      .FRAC_W      (FRAC_W),
      .EXP_W       (EXP_W),
      .SIGNED_EXP_W(SIGNED_EXP_W),
      .float_t     (float_t)
  ) quotient_rounder_inst (
      .float_quotient_flags_i(float_quotient_flags_q),
      .quotient_exp_i        (quotient_exp_q),
      .quotient_raw_i        (quotient_raw_q),
      .sticky_i              (sticky_q),
      .quotient_o            (float_quotient)
  );

  data_status_pipeline #(
      .DATA_W    (DATA_W),
      .STATUS_W  (1),
      .PIPE_DEPTH(OUT_PIPE_DEPTH)
  ) round_to_out_pipe (
      .clk     (clk),
      .rst_n   (rst_n),
      .data_i  (float_quotient),
      .status_i(divider_done_q),
      .data_o  (z),
      .status_o(z_valid)
  );

endmodule
