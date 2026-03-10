module srt_radix4_qds
  import srt_sqrt_pkg::*;
#(
    parameter int DATA_W = 72,
    parameter int RAD_W  = 64
) (
    input  logic signed [   DATA_W-1:0] rem_sum_shift_i,
    input  logic signed [   DATA_W-1:0] rem_carry_shift_i,
    input  logic        [  Q_IDX_W-1:0] q_idx_i,
    output logic signed [Q_DIGIT_W-1:0] q_digit_o
);
  localparam ESTIMATE_CS_W = DATA_W - ESTIMATE_CS_LSB;
  localparam ESTIMATE_W    = ESTIMATE_CS_W + 1;

  localparam TABLE_SHIFT = (RAD_W - 1 - ESTIMATE_CS_LSB);

  logic signed [   ESTIMATE_W-1:0] estimate_rem_raw;
  logic signed [   ESTIMATE_W-1:0] estimate_rem;
  logic signed [   ESTIMATE_W-1:0] lower_sel_const;
  logic signed [   ESTIMATE_W-1:0] upper_sel_const;

  logic        [ESTIMATE_CS_W-1:0] carry_estimate;
  logic        [ESTIMATE_CS_W-1:0] sum_estimate;

  assign sum_estimate   = rem_sum_shift_i[DATA_W-1-:ESTIMATE_CS_W];
  assign carry_estimate = rem_carry_shift_i[DATA_W-1-:ESTIMATE_CS_W];

  always_comb begin
    estimate_rem_raw = $signed({sum_estimate[ESTIMATE_CS_W-1], sum_estimate}) +
        $signed({carry_estimate[ESTIMATE_CS_W-1], carry_estimate});

    estimate_rem = estimate_rem_raw;
    if (estimate_rem_raw < -ESTIMATE_W'($signed(1 << (ESTIMATE_W - 3)))) begin
      estimate_rem = estimate_rem_raw ^ (ESTIMATE_W'(1) << (ESTIMATE_W - 1));
    end
  end

  always_comb begin
    lower_sel_const = $signed(LOWER_SEL_CONST_TABLE[q_idx_i]) << TABLE_SHIFT;
    upper_sel_const = $signed(UPPER_SEL_CONST_TABLE[q_idx_i]) << TABLE_SHIFT;
  end

  always_comb begin
    q_digit_o = 3'sd0;
    if (estimate_rem >= lower_sel_const) begin
      q_digit_o = 3'sd1;
      if (estimate_rem >= upper_sel_const) begin
        q_digit_o = 3'sd2;
      end
    end else if (estimate_rem <= ~lower_sel_const) begin
      q_digit_o = -3'sd1;
      if (estimate_rem <= ~upper_sel_const) begin
        q_digit_o = -3'sd2;
      end
    end
  end

endmodule
