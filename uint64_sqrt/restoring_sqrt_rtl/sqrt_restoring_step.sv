module sqrt_restoring_step #(
    parameter DIN_W       = 64,
    parameter DOUT_W      = DIN_W / 2,      // I could make these marcos                   
    parameter REMAINDER_W = 2 * DIN_W + 1,
    parameter TEST_SUB_W  = DIN_W + 1
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

  always_comb begin
    AX = AX_i;
    T  = T_i;
    Q  = Q_i;

    AX = AX << 2;
    T  = AX[REMAINDER_W-1-:TEST_SUB_W] - {{(TEST_SUB_W - DOUT_W - 2) {1'b0}}, Q, 2'b01};
    Q  = Q << 1;

    if (T[TEST_SUB_W-1] == 1'b0) begin
      AX[REMAINDER_W-1-:TEST_SUB_W] = T;
      Q[0]                          = 1'b1;
    end

    AX_o = AX;
    T_o  = T;
    Q_o  = Q;
  end

endmodule
