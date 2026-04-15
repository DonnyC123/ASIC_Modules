module sqrt_mantissa #(
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

  import sqrt_float_pkg::*;

  localparam SIGN_W      = 1;
  localparam SQRT_STEPS  = ROOT_EXTENDED_W;

  localparam STAGE_STEPS = PIPELINE_STAGES : SQRT_STEPS / (PIPELINE_STAGES) : 0;

  localparam TEST_SUB_W  = ROOT_EXTENDED_W + SIGN_W + 2;
  localparam REMAINDER_W = TEST_SUB_W + (2 * SQRT_STEPS);

  logic [ROOT_EXTENDED_W-1:0] root_extended;

  logic [    REMAINDER_W-1:0] AX            [SQRT_STEPS];
  logic [     TEST_SUB_W-1:0] T             [SQRT_STEPS];
  logic [ROOT_EXTENDED_W-1:0] Q             [SQRT_STEPS];

  logic [    REMAINDER_W-1:0] AX_next       [SQRT_STEPS];
  logic [     TEST_SUB_W-1:0] T_next        [SQRT_STEPS];
  logic [ROOT_EXTENDED_W-1:0] Q_next        [SQRT_STEPS];

  logic                       valid         [SQRT_STEPS];

  always_comb begin
    AX[0]                               = '0;
    AX[0][(2*SQRT_STEPS)-1-:MANTISSA_W] = mantissa_rad_i;
    T[0]                                = '0;
    Q[0]                                = '0;

    valid[0]                            = valid_i;
  end

  genvar stage_idx;

  generate
    for (stage_idx = 0; stage_idx < SQRT_STEPS; stage_idx++) begin
      sqrt_restoring_step #(
          .DIN_W      (MANTISSA_W),
          .DOUT_W     (ROOT_EXTENDED_W),
          .TEST_SUB_W (TEST_SUB_W),
          .REMAINDER_W(REMAINDER_W)
      ) sqrt_restoring_step_inst (
          .AX_i(AX[stage_idx]),
          .T_i (T[stage_idx]),
          .Q_i (Q[stage_idx]),
          .AX_o(AX_next[stage_idx]),
          .T_o (T_next[stage_idx]),
          .Q_o (Q_next[stage_idx])
      );

      if (stage_idx < SQRT_STEPS - 1) begin : prop_signal
        if ((stage_idx + 1) % STAGE_STEPS == 0) begin : reg_signal
          data_status_pipeline #(
              .DATA_W    (REMAINDER_W + TEST_SUB_W + ROOT_EXTENDED_W),
              .STATUS_W  (1),
              .PIPE_DEPTH(1),
              .CLK_EN    (1)
          ) data_pipe (
              .clk     (clk),
              .clk_en  (clk_en),
              .rst_n   (rst_n),
              .data_i  ({AX_next[stage_idx], T_next[stage_idx], Q_next[stage_idx]}),
              .status_i(valid[stage_idx]),
              .data_o  ({AX[stage_idx+1], T[stage_idx+1], Q[stage_idx+1]}),
              .status_o(valid[stage_idx+1])
          );
        end else begin
          always_comb begin
            AX[stage_idx+1]    = AX_next[stage_idx];
            T[stage_idx+1]     = T_next[stage_idx];
            Q[stage_idx+1]     = Q_next[stage_idx];

            valid[stage_idx+1] = valid[stage_idx];
          end
        end
      end
    end
  endgenerate

  logic [REMAINDER_W-1:0] true_rem;
  logic [ TEST_SUB_W-1:0] restore_val;

  always_comb begin
    root_extended_o = Q_next[SQRT_STEPS-1];
    sticky_rem_o    = |AX_next[SQRT_STEPS-1];
    valid_o         = valid[SQRT_STEPS-1];
  end

endmodule
