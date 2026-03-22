module srt_sqrt #(
    parameter  int DIN_W  = 64,
    localparam int DOUT_W = DIN_W / 2
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic [ DIN_W-1:0] rad_i,
    input  logic              valid_i,
    output logic [DOUT_W-1:0] root_o,
    output logic              valid_o
);
  import srt_sqrt_pkg::*;

  localparam FRAC_BITS   = DIN_W + RADIX_W;
  localparam DATA_W      = INT_W + FRAC_BITS;
  localparam ITERATIONS  = DOUT_W / 2 - 2;
  localparam DIN_PAIRS_W = DIN_W / 2;

  localparam LZ_PAIR_COUNT_W = $clog2(DIN_PAIRS_W);
  localparam LZ_RAD_COUNT_W  = LZ_PAIR_COUNT_W + 1;

  localparam Q_SQ_PAD_W   = FRAC_BITS - SQ_INT_W;
  localparam Q_SEED_PAD_W = FRAC_BITS - SEED_IDX_W;
  localparam SHIFT_OUT_W  = FRAC_BITS - DOUT_W;

  logic        [    DIN_PAIRS_W-1:0] rad_or_pairs;
  logic        [LZ_PAIR_COUNT_W-1:0] pair_leading_zero_count;
  logic        [ LZ_RAD_COUNT_W-1:0] rad_leading_zero_count;

  logic        [          DIN_W-1:0] norm_rad;
  logic        [     SEED_IDX_W-1:0] seed_idx;
  logic        [     SEED_IDX_W-1:0] root_seed;
  logic        [       SQ_INT_W-1:0] root_sq_seed;

  logic        [         DATA_W-1:0] norm_rad_padded;
  logic        [         DATA_W-1:0] root_sq_padded;
  logic signed [         DATA_W-1:0] rem_sum_init;

  logic signed [         DATA_W-1:0] rem_sum_stage           [ITERATIONS+1];
  logic signed [         DATA_W-1:0] rem_carry_stage         [ITERATIONS+1];
  logic signed [         DATA_W-1:0] root_q_stage            [ITERATIONS+1];
  logic signed [         DATA_W-1:0] root_qm_stage           [ITERATIONS+1];

  logic signed [         DATA_W-1:0] rem_sum_stage_next      [ITERATIONS+1];
  logic signed [         DATA_W-1:0] rem_carry_stage_next    [ITERATIONS+1];
  logic signed [         DATA_W-1:0] root_q_stage_next       [ITERATIONS+1];
  logic signed [         DATA_W-1:0] root_qm_stage_next      [ITERATIONS+1];
  logic                              valid_stage             [ITERATIONS+1];
  logic        [LZ_PAIR_COUNT_W-1:0] pair_lz_count_stage     [ITERATIONS+1];
  logic                              is_zero_stage           [ITERATIONS+1];

  logic        [         DATA_W-1:0] full_final_rem;
  logic signed [         DATA_W-1:0] final_root_vec;
  logic        [         DATA_W-1:0] root_raw;

  always_comb begin
    for (int i = 0; i < DIN_PAIRS_W; i++) begin
      rad_or_pairs[i] = |rad_i[2*i+:2];
    end
  end

  leading_zero_counter_top #(
      .DATA_W          (DIN_PAIRS_W),
      .LZC_DATA_BLOCK_W(8)
  ) rad_in_lzc_inst (
      .data_i              (rad_or_pairs),
      .leading_zero_count_o(pair_leading_zero_count)
  );

  always_comb begin
    rad_leading_zero_count = {pair_leading_zero_count, 1'b0};
    norm_rad               = rad_i << rad_leading_zero_count;
    seed_idx               = norm_rad[DIN_W-1 : DIN_W-SEED_IDX_W];
  end

  srt_radix4_seed srt_radix4_seed_inst (
      .seed_idx_i    (seed_idx),
      .root_seed_o   (root_seed),
      .root_sq_seed_o(root_sq_seed)
  );

  always_comb begin
    norm_rad_padded        = {{INT_W{1'b0}}, norm_rad, 2'b0};
    root_sq_padded         = {{INT_W{1'b0}}, root_sq_seed, {Q_SQ_PAD_W{1'b0}}};
    rem_sum_init           = $signed((norm_rad_padded - root_sq_padded) << 4);

    rem_sum_stage[0]       = rem_sum_init;
    rem_carry_stage[0]     = '0;
    root_q_stage[0]        = $signed(DATA_W'(root_seed) << Q_SEED_PAD_W);
    root_qm_stage[0]       = root_q_stage[0] - (DATA_W'(1) << 62);
    valid_stage[0]         = valid_i;

    is_zero_stage[0]       = rad_i == 0;
    pair_lz_count_stage[0] = pair_leading_zero_count;
  end

  genvar stage_idx;
  generate
    for (stage_idx = 0; stage_idx < ITERATIONS; stage_idx++) begin : gen_stages
      srt_sqrt_stage #(
          .DATA_W   (DATA_W),
          .FRAC_BITS(FRAC_BITS),
          .RAD_W    (DIN_W),
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

      if (is_pipeline_stage(stage_idx)) begin
        data_status_pipeline #(
            .DATA_W    (4 * DATA_W + LZ_PAIR_COUNT_W + 1),
            .STATUS_W  (1),
            .PIPE_DEPTH(1),
            .CLOCK_GATE(1)
        ) data_status_pipeline_inst (
            .clk(clk),
            .rst_n(rst_n),
            .data_i({
              rem_carry_stage_next[stage_idx],
              rem_sum_stage_next[stage_idx],
              root_q_stage_next[stage_idx],
              root_qm_stage_next[stage_idx],
              pair_lz_count_stage[stage_idx],
              is_zero_stage[stage_idx]
            }),
            .status_i(valid_stage[stage_idx]),
            .data_o({
              rem_carry_stage[stage_idx+1],
              rem_sum_stage[stage_idx+1],
              root_q_stage[stage_idx+1],
              root_qm_stage[stage_idx+1],
              pair_lz_count_stage[stage_idx+1],
              is_zero_stage[stage_idx+1]
            }),
            .status_o(valid_stage[stage_idx+1])
        );
      end else begin
        always_comb begin
          rem_carry_stage[stage_idx+1]     = rem_carry_stage_next[stage_idx];
          rem_sum_stage[stage_idx+1]       = rem_sum_stage_next[stage_idx];
          root_q_stage[stage_idx+1]        = root_q_stage_next[stage_idx];
          root_qm_stage[stage_idx+1]       = root_qm_stage_next[stage_idx];
          valid_stage[stage_idx+1]         = valid_stage[stage_idx];
          pair_lz_count_stage[stage_idx+1] = pair_lz_count_stage[stage_idx];
          is_zero_stage[stage_idx+1]       = is_zero_stage[stage_idx];
        end
      end
    end
  endgenerate

  always_comb begin
    full_final_rem = rem_sum_stage[ITERATIONS] + rem_carry_stage[ITERATIONS];
    final_root_vec = (full_final_rem[DATA_W-1]) ? root_qm_stage[ITERATIONS] : root_q_stage[ITERATIONS];

    if (is_zero_stage[ITERATIONS]) begin
      root_raw = '0;
    end else begin
      root_raw = (final_root_vec[FRAC_BITS-1:0] >>
                  ($unsigned(SHIFT_OUT_W) + pair_lz_count_stage[ITERATIONS]));
    end
  end

  data_status_pipeline #(
      .DATA_W    (DIN_W),
      .STATUS_W  (1),
      .PIPE_DEPTH(1),
      .CLOCK_GATE(1)
  ) data_status_pipeline_inst (
      .clk     (clk),
      .rst_n   (rst_n),
      .data_i  (root_raw[DOUT_W-1:0]),
      .status_i(valid_stage[ITERATIONS]),
      .data_o  (root_o),
      .status_o(valid_o)
  );

endmodule

