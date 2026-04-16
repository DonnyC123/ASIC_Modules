module sqrt_srt_mantissa #(
    parameter int MANTISSA_W      = 12,
    parameter int ROOT_EXTENDED_W = 13,
    parameter int PIPELINE_STAGES = 1
) (
    input  logic                       clk,
    input  logic                       clk_en,
    input  logic                       rst_n,
    input  logic [     MANTISSA_W-1:0] mantissa_rad_i,
    input  logic                       valid_i,
    output logic [ROOT_EXTENDED_W-1:0] root_extended_o,
    output logic                       sticky_rem_o,
    output logic                       valid_o
);

  import srt_sqrt_pkg::*;

  localparam BITS_PER_ITERATION  = 2;
  localparam SEED_ROOT_BITS      = 4;
  localparam REMAINING_ROOT_BITS = ROOT_EXTENDED_W - SEED_ROOT_BITS;
  localparam ITERATIONS          = (REMAINING_ROOT_BITS + (RADIX_W - 1)) / RADIX_W;
  localparam STAGE_STEPS         = ITERATIONS + 1 / (PIPELINE_STAGES + 1);

  localparam FRAC_BITS = MANTISSA_W + RADIX_W;
  localparam DATA_W    = INT_W + FRAC_BITS;

  localparam Q_SQ_PAD_W   = FRAC_BITS - SQ_INT_W;
  localparam Q_SEED_PAD_W = FRAC_BITS - INT_W;
  localparam SHIFT_OUT_W  = FRAC_BITS - ROOT_EXTENDED_W;

  logic        [   INT_W-1:0] seed_idx;
  logic        [   INT_W-1:0] root_seed;
  logic        [SQ_INT_W-1:0] root_sq_seed;

  logic        [  DATA_W-1:0] norm_rad_padded;
  logic        [  DATA_W-1:0] root_sq_padded;
  logic signed [  DATA_W-1:0] rem_sum_init;

  logic signed [  DATA_W-1:0] rem_sum_stage       [ITERATIONS];
  logic signed [  DATA_W-1:0] rem_carry_stage     [ITERATIONS];
  logic signed [  DATA_W-1:0] root_q_stage        [ITERATIONS];
  logic signed [  DATA_W-1:0] root_qm_stage       [ITERATIONS];

  logic signed [  DATA_W-1:0] rem_sum_stage_next  [ITERATIONS];
  logic signed [  DATA_W-1:0] rem_carry_stage_next[ITERATIONS];
  logic signed [  DATA_W-1:0] root_q_stage_next   [ITERATIONS];
  logic signed [  DATA_W-1:0] root_qm_stage_next  [ITERATIONS];

  logic                       valid               [ITERATIONS];

  logic signed [  DATA_W-1:0] full_final_rem;
  logic signed [  DATA_W-1:0] final_root_vec;

  assign seed_idx = mantissa_rad_i[MANTISSA_W-1 : MANTISSA_W-INT_W];

  srt_radix4_seed srt_radix4_seed_inst (
      .seed_idx_i    (seed_idx),
      .root_seed_o   (root_seed),
      .root_sq_seed_o(root_sq_seed)
  );

  always_comb begin
    norm_rad_padded    = {{INT_W{1'b0}}, mantissa_rad_i, 2'b0};
    root_sq_padded     = {{INT_W{1'b0}}, root_sq_seed, {Q_SQ_PAD_W{1'b0}}};
    rem_sum_init       = $signed((norm_rad_padded - root_sq_padded) << 4);

    rem_sum_stage[0]   = rem_sum_init;
    rem_carry_stage[0] = '0;
    root_q_stage[0]    = $signed(DATA_W'(root_seed) << Q_SEED_PAD_W);
    root_qm_stage[0]   = root_q_stage[0] - (DATA_W'(1) << (MANTISSA_W - RADIX_W));

    valid[0]           = valid_i;
  end

  genvar stage_idx;
  generate
    for (stage_idx = 0; stage_idx < ITERATIONS; stage_idx++) begin : gen_stages
      srt_sqrt_stage #(
          .DATA_W   (DATA_W),
          .FRAC_BITS(FRAC_BITS),
          .RAD_W    (MANTISSA_W),
          .STAGE    (stage_idx + 3),
          .USE_ADDER(stage_idx == 0)
      ) srt_sqrt_stage_inst (
          .rem_sum_i  (rem_sum_stage[stage_idx]),
          .rem_carry_i(rem_carry_stage[stage_idx]),
          .root_q_i   (root_q_stage[stage_idx]),
          .root_qm_i  (root_qm_stage[stage_idx]),
          .rem_sum_o  (rem_sum_stage_next[stage_idx]),
          .rem_carry_o(rem_carry_stage_next[stage_idx]),
          .root_q_o   (root_q_stage_next[stage_idx]),
          .root_qm_o  (root_qm_stage_next[stage_idx])
      );

      if (stage_idx < ITERATIONS - 1) begin : prop_signal
        if ((stage_idx + 1) % STAGE_STEPS == 0) begin : reg_signal
          data_status_pipeline #(
              .DATA_W    (4 * DATA_W),
              .STATUS_W  (1),
              .PIPE_DEPTH(1),
              .CLK_EN    (1)
          ) data_pipe_inst (
              .clk(clk),
              .clk_en(clk_en),
              .rst_n(rst_n),
              .data_i({
                rem_sum_stage_next[stage_idx],
                rem_carry_stage_next[stage_idx],
                root_q_stage_next[stage_idx],
                root_qm_stage_next[stage_idx]
              }),
              .status_i(valid[stage_idx]),
              .data_o({
                rem_sum_stage[stage_idx+1],
                rem_carry_stage[stage_idx+1],
                root_q_stage[stage_idx+1],
                root_qm_stage[stage_idx+1]
              }),
              .status_o(valid[stage_idx+1])
          );
        end else begin
          always_comb begin
            rem_sum_stage[stage_idx+1]   = rem_sum_stage_next[stage_idx];
            rem_carry_stage[stage_idx+1] = rem_carry_stage_next[stage_idx];
            root_q_stage[stage_idx+1]    = root_q_stage_next[stage_idx];
            root_qm_stage[stage_idx+1]   = root_qm_stage_next[stage_idx];

            valid[stage_idx+1]           = valid[stage_idx];
          end
        end
      end
    end
  endgenerate

  always_comb begin
    full_final_rem = rem_sum_stage_next[ITERATIONS-1] + rem_carry_stage_next[ITERATIONS-1];
    final_root_vec = (full_final_rem[DATA_W-1]) ? root_qm_stage_next[ITERATIONS-1] : root_q_stage_next[ITERATIONS-1];
  end

  assign root_extended_o = final_root_vec[ROOT_EXTENDED_W+SHIFT_OUT_W-1 : SHIFT_OUT_W];
  assign sticky_rem_o    = (full_final_rem != 0);
  assign valid_o         = valid[ITERATIONS-1];

endmodule
