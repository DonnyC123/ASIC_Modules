module sqrt_float #(
    parameter  EXP_W  = 5,
    parameter  FRAC_W = 10,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              rad_valid_i,
    input  logic [DATA_W-1:0] rad_i,
    output logic [DATA_W-1:0] root_o,
    output logic              root_valid_o
);

  import sqrt_float_pkg::*;

  localparam MANTISSA_INT_W  = 1;
  localparam GUARD_W         = 1;
  localparam SIGN_W          = 1;
  localparam MANTISSA_W      = FRAC_W + MANTISSA_INT_W;
  localparam ROOT_EXTENDED_W = FRAC_W + 1 + GUARD_W;
  localparam SIGNED_EXP_W    = EXP_W + SIGN_W;

  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_t;

  float_t                             float_rad;
  float_t                             float_root_unpacked;

  float_flags_t                       root_float_flags;
  logic         [  FLOAT_FLAGS_W-1:0] root_float_flags_raw;

  logic         [     MANTISSA_W-1:0] norm_mant_rad;
  logic signed  [   SIGNED_EXP_W-1:0] root_exp_signed;

  logic         [     MANTISSA_W-1:0] norm_mant_rad_q;
  logic                               decode_valid_q;

  float_flags_t                       root_float_flags_q2;
  logic         [  FLOAT_FLAGS_W-1:0] root_float_flags_q2_raw;
  logic signed  [   SIGNED_EXP_W-1:0] root_exp_signed_q2;
  logic         [ROOT_EXTENDED_W-1:0] root_extended_q;
  logic                               sticky_rem_q;
  logic                               mantissa_valid_q;

  logic         [ROOT_EXTENDED_W-1:0] root_extended;
  logic                               sticky_rem;
  logic                               mantissa_valid;
  logic                               flags_exp_valid_q2;  // Parallel valid signal

  assign float_rad = float_t'(rad_i);

  sqrt_float_decoder #(
      .EXP_W     (EXP_W),
      .MANTISSA_W(MANTISSA_W)
  ) sqrt_float_decoder_inst (
      .float_rad_i    (float_rad),
      .root_flags_o   (root_float_flags),
      .norm_mant_rad_o(norm_mant_rad),
      .root_exp_o     (root_exp_signed)
  );

  data_status_pipeline #(
      .DATA_W    (MANTISSA_W),
      .STATUS_W  (1),
      .PIPE_DEPTH(1),
      .CLOCK_GATE(1)
  ) decode_to_mantissa_pipe (
      .clk     (clk),
      .rst_n   (rst_n),
      .data_i  (norm_mant_rad),
      .status_i(rad_valid_i),
      .data_o  (norm_mant_rad_q),
      .status_o(decode_valid_q)
  );

  assign root_float_flags_raw = FLOAT_FLAGS_W'(root_float_flags);

  data_status_pipeline #(
      .DATA_W    (SIGNED_EXP_W + FLOAT_FLAGS_W),
      .STATUS_W  (1),
      .PIPE_DEPTH(2)
  ) flags_exp_delay_pipe (
      .clk     (clk),
      .rst_n   (rst_n),
      .data_i  ({root_exp_signed, root_float_flags_raw}),
      .status_i(rad_valid_i),
      .data_o  ({root_exp_signed_q2, root_float_flags_q2_raw}),
      .status_o(flags_exp_valid_q2)
  );

  assign root_float_flags_q2 = float_flags_t'(root_float_flags_q2_raw);

  sqrt_mantissa #(
      .MANTISSA_W     (MANTISSA_W),
      .ROOT_EXTENDED_W(ROOT_EXTENDED_W),
      .PIPELINE_STAGES(1)
  ) sqrt_mantissa_inst (
      .clk            (clk),
      .rst_n          (rst_n),
      .mantissa_rad_i (norm_mant_rad_q),
      .valid_i        (decode_valid_q),
      .root_extended_o(root_extended),
      .sticky_rem_o   (sticky_rem),
      .valid_o        (mantissa_valid)
  );

  data_status_pipeline #(
      .DATA_W    (ROOT_EXTENDED_W + 1),
      .STATUS_W  (1),
      .PIPE_DEPTH(1)
  ) engine_to_round_pipe (
      .clk     (clk),
      .rst_n   (rst_n),
      .data_i  ({root_extended, sticky_rem}),
      .status_i(mantissa_valid),
      .data_o  ({root_extended_q, sticky_rem_q}),
      .status_o(mantissa_valid_q)
  );

  root_rounder #(
      .FRAC_W         (FRAC_W),
      .EXP_W          (EXP_W),
      .SIGNED_EXP_W   (SIGNED_EXP_W),
      .ROOT_EXTENDED_W(ROOT_EXTENDED_W),
      .float_t        (float_t)
  ) root_rounder_inst (
      .float_root_flags_i(root_float_flags_q2),
      .root_exp_i        (root_exp_signed_q2),
      .root_raw_i        (root_extended_q),
      .sticky_i          (sticky_rem_q),
      .root_o            (float_root_unpacked)
  );

  data_status_pipeline #(
      .DATA_W    (DATA_W),
      .STATUS_W  (1),
      .PIPE_DEPTH(1)
  ) round_to_out_pipe (
      .clk     (clk),
      .rst_n   (rst_n),
      .data_i  (float_root_unpacked),
      .status_i(mantissa_valid_q),     // Fixed: Use valid signal from rounder input stage
      .data_o  (root_o),
      .status_o(root_valid_o)
  );

endmodule
