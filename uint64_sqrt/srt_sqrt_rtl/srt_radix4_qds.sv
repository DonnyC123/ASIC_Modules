module srt_radix4_qds
  import srt_sqrt_pkg::*;
#(
    parameter int DATA_W = 72,
    parameter int RAD_W  = 64,
    // Carry-free digit selection: inspect only the QDS_W highest bits of the
    // redundant remainder. Truncation error is bounded and absorbed by the
    // radix-4 digit-set redundancy (rho = 2/3). QDS_W = 9 keeps TABLE_SHIFT
    // at 0 for both FP16 and FP32 instantiations.
    parameter int QDS_W  = 9
) (
    input  logic signed [   DATA_W-1:0] rem_sum_shift_i,
    input  logic signed [   DATA_W-1:0] rem_carry_shift_i,
    input  logic        [  Q_IDX_W-1:0] q_idx_i,
    output logic signed [Q_DIGIT_W-1:0] q_digit_o
);

  localparam int ESTIMATE_CS_LSB = RAD_W - RADIX_W - 1;
  localparam int FULL_CS_W       = DATA_W - ESTIMATE_CS_LSB;
  localparam int TRUNC_LSB       = FULL_CS_W - QDS_W;
  localparam int ESTIMATE_W      = QDS_W + 1;
  localparam int TABLE_SHIFT     = (RAD_W - 1 - ESTIMATE_CS_LSB) - TRUNC_LSB;

  logic        [       QDS_W-1:0] sum_trunc;
  logic        [       QDS_W-1:0] carry_trunc;

  logic signed [  ESTIMATE_W-1:0] estimate_rem;
  logic signed [  ESTIMATE_W-1:0] lower_sel_const;
  logic signed [  ESTIMATE_W-1:0] upper_sel_const;

  assign sum_trunc   = rem_sum_shift_i  [DATA_W-1 -: QDS_W];
  assign carry_trunc = rem_carry_shift_i[DATA_W-1 -: QDS_W];

  always_comb begin
    estimate_rem    = $signed({sum_trunc[QDS_W-1], sum_trunc}) +
                      $signed({carry_trunc[QDS_W-1], carry_trunc});

    lower_sel_const = ESTIMATE_W'($signed({1'b0, LOWER_SEL_CONST_TABLE[q_idx_i]})) <<< TABLE_SHIFT;
    upper_sel_const = ESTIMATE_W'($signed({1'b0, UPPER_SEL_CONST_TABLE[q_idx_i]})) <<< TABLE_SHIFT;

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
