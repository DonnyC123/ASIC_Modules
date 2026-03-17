module sqrt_non_restoring_stage #(
    parameter  int DIN_W       = 64,
    parameter  int SQRT_STEPS  = 16,
    parameter      DOUT_W      = DIN_W / 2,
    localparam     REMAINDER_W = 2 * DIN_W + 1,
    localparam     TEST_SUB_W  = DIN_W + 1
) (
    input  logic [REMAINDER_W-1:0] AX_i,
    input  logic [ TEST_SUB_W-1:0] T_i,
    input  logic [     DOUT_W-1:0] Q_i,
    output logic [REMAINDER_W-1:0] AX_o,
    output logic [ TEST_SUB_W-1:0] T_o,
    output logic [     DOUT_W-1:0] Q_o
);

  logic [REMAINDER_W-1:0] AX;
  logic [ TEST_SUB_W-1:0] T;
  logic [     DOUT_W-1:0] Q;

  logic                   sign_R;
  logic [ TEST_SUB_W-1:0] operand;

  always_comb begin
    AX = AX_i;
    T  = T_i;
    Q  = Q_i;

    for (int i = 0; i < SQRT_STEPS; i++) begin
      sign_R  = AX[REMAINDER_W-1];
      AX      = AX << 2;

      operand = {{(DOUT_W - 1) {1'b0}}, Q, sign_R, 1'b1};

      if (sign_R == 1'b0) begin
        T = AX[REMAINDER_W-1-:TEST_SUB_W] - operand;
      end else begin
        T = AX[REMAINDER_W-1-:TEST_SUB_W] + operand;
      end

      AX[REMAINDER_W-1-:TEST_SUB_W] = T;
      Q                             = Q << 1;
      if (T[TEST_SUB_W-1] == 1'b0) begin
        Q[0] = 1'b1;
      end

    end

    AX_o = AX;
    T_o  = T;
    Q_o  = Q;
  end

endmodule
