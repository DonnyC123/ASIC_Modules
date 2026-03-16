module sqrt_non_restoring #(
    parameter  int DIN_W           = 64,
    parameter  int PIPELINE_STAGES = 4,
    localparam     DOUT_W          = DIN_W / 2
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic [ DIN_W-1:0] rad_i,
    input  logic              valid_i,
    output logic [DOUT_W-1:0] root_o,
    output logic              valid_o
);

  localparam SIGN_W      = 1;
  localparam REMAINDER_W = 2 * DIN_W + SIGN_W;
  localparam TEST_SUB_W  = DIN_W + SIGN_W;

  localparam STAGE_STEPS           = DOUT_W / PIPELINE_STAGES;
  localparam REMAINING_STAGE_STEPS = DOUT_W - PIPELINE_STAGES * STAGE_STEPS;

  logic [REMAINDER_W-1:0] AX     [PIPELINE_STAGES+1];
  logic [ TEST_SUB_W-1:0] T      [PIPELINE_STAGES+1];
  logic [     DOUT_W-1:0] Q      [PIPELINE_STAGES+1];

  logic [REMAINDER_W-1:0] AX_next[PIPELINE_STAGES+1];
  logic [ TEST_SUB_W-1:0] T_next [PIPELINE_STAGES+1];
  logic [     DOUT_W-1:0] Q_next [PIPELINE_STAGES+1];

  logic                   valid  [PIPELINE_STAGES+1];

  always_comb begin
    AX[0][DIN_W-1:0]           = rad_i;
    valid[0]                   = valid_i;

    AX[0][REMAINDER_W-1:DIN_W] = '0;
    T[0]                       = '0;
    Q[0]                       = '0;
  end

  genvar stage_idx;
  generate
    for (stage_idx = 0; stage_idx < PIPELINE_STAGES; stage_idx++) begin : gen_pipeline

      localparam SQRT_STEPS = (stage_idx == PIPELINE_STAGES -1) ?
                              REMAINING_STAGE_STEPS + STAGE_STEPS
                            : STAGE_STEPS;

      sqrt_non_restoring_stage #(
          .DIN_W     (DIN_W),
          .SQRT_STEPS(SQRT_STEPS)
      ) sqrt_non_restoring_stage_inst (
          .AX_i(AX[stage_idx]),
          .T_i (T[stage_idx]),
          .Q_i (Q[stage_idx]),
          .AX_o(AX_next[stage_idx]),
          .T_o (T_next[stage_idx]),
          .Q_o (Q_next[stage_idx])
      );

      logic [DOUT_W-1:0] Q_to_reg;

      if (stage_idx == PIPELINE_STAGES - 1) begin : gen_final_correction
        assign Q_to_reg = AX_next[stage_idx][REMAINDER_W-1] ? (Q_next[stage_idx] - 1'b1) : Q_next[stage_idx];
      end else begin : gen_pass_through
        assign Q_to_reg = Q_next[stage_idx];
      end

      data_status_pipeline #(
          .DATA_W    (REMAINDER_W + TEST_SUB_W + DOUT_W),
          .STATUS_W  (1),
          .PIPE_DEPTH(1),
          .CLOCK_GATE(1)
      ) data_status_pipeline_inst (
          .clk     (clk),
          .rst_n   (rst_n),
          .data_i  ({AX_next[stage_idx], T_next[stage_idx], Q_to_reg}),
          .status_i(valid[stage_idx]),
          .data_o  ({AX[stage_idx+1], T[stage_idx+1], Q[stage_idx+1]}),
          .status_o(valid[stage_idx+1])
      );

    end
  endgenerate

  assign root_o  = Q[PIPELINE_STAGES];
  assign valid_o = valid[PIPELINE_STAGES];

endmodule
