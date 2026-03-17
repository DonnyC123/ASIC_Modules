module sqrt_mantissa #(
    parameter int MANTISSA_W      = 12,
    parameter int ROOT_EXTENDED_W = 13,
    parameter int PIPELINE_STAGES = 1
) (
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic [     MANTISSA_W-1:0] mantissa_rad_i,
    input  logic                       valid_i,
    output logic [ROOT_EXTENDED_W-1:0] root_extended_o,
    output logic                       sticky_rem_o,
    output logic                       valid_o
);

  import sqrt_float_pkg::*;

  localparam SIGN_W      = 1;
  localparam REMAINDER_W = 2 * ROOT_EXTENDED_W + SIGN_W;
  localparam TEST_SUB_W  = ROOT_EXTENDED_W + SIGN_W;

  localparam STAGE_STEPS           = ROOT_EXTENDED_W / PIPELINE_STAGES;
  localparam REMAINING_STAGE_STEPS = ROOT_EXTENDED_W - PIPELINE_STAGES * STAGE_STEPS;

  logic                       final_rem_is_neg;
  logic [ROOT_EXTENDED_W-1:0] root_extended;


  logic [    REMAINDER_W-1:0] AX               [PIPELINE_STAGES+1];
  logic [     TEST_SUB_W-1:0] T                [PIPELINE_STAGES+1];
  logic [ROOT_EXTENDED_W-1:0] Q                [PIPELINE_STAGES+1];

  logic [    REMAINDER_W-1:0] AX_next          [PIPELINE_STAGES+1];
  logic [     TEST_SUB_W-1:0] T_next           [PIPELINE_STAGES+1];
  logic [ROOT_EXTENDED_W-1:0] Q_next           [PIPELINE_STAGES+1];
  logic                       valid            [PIPELINE_STAGES+1];

  always_comb begin
    AX[0][ROOT_EXTENDED_W-1:0]           = {1'b0, mantissa_rad_i};
    valid[0]                             = valid_i;

    AX[0][REMAINDER_W-1:ROOT_EXTENDED_W] = '0;
    T[0]                                 = '0;
    Q[0]                                 = '0;
  end

  genvar stage_idx;
  generate
    for (stage_idx = 0; stage_idx < PIPELINE_STAGES; stage_idx++) begin

      localparam SQRT_STEPS = (stage_idx == PIPELINE_STAGES -1) ?                
                              REMAINING_STAGE_STEPS + STAGE_STEPS                
                            : STAGE_STEPS;

      sqrt_restoring_stage #(
          .DIN_W     (ROOT_EXTENDED_W),
          .DOUT_W    (ROOT_EXTENDED_W),
          .SQRT_STEPS(SQRT_STEPS)
      ) sqrt_restoring_stage_inst (
          .AX_i(AX[stage_idx]),
          .T_i (T[stage_idx]),
          .Q_i (Q[stage_idx]),
          .AX_o(AX_next[stage_idx]),
          .T_o (T_next[stage_idx]),
          .Q_o (Q_next[stage_idx])
      );

      data_status_pipeline #(
          .DATA_W    (REMAINDER_W + TEST_SUB_W + ROOT_EXTENDED_W),
          .STATUS_W  (1),
          .PIPE_DEPTH(1),
          .CLOCK_GATE(1)
      ) data_status_pipeline_inst (
          .clk     (clk),
          .rst_n   (rst_n),
          .data_i  ({AX_next[stage_idx], T_next[stage_idx], Q_next[stage_idx]}),
          .status_i(valid[stage_idx]),
          .data_o  ({AX[stage_idx+1], T[stage_idx+1], Q[stage_idx+1]}),
          .status_o(valid[stage_idx+1])
      );

    end
  endgenerate

  always_comb begin
    root_extended = Q[PIPELINE_STAGES];

    valid_o       = valid[PIPELINE_STAGES];
    sticky_rem_o  = (AX[PIPELINE_STAGES] != '0);
  end

endmodule
