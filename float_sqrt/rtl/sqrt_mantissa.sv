module sqrt_mantissa #(
    parameter int MANTISSA_W      = 12,
    parameter int ROOT_EXTENDED_W = 12,
    parameter int PIPELINE_STAGES = 1
) (
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic [     MANTISSA_W-1:0] mantissa_rad_i,
    output logic [ROOT_EXTENDED_W-1:0] root_extended_o,
    output logic                       sticky_rem_o
);

  import sqrt_float_pkg::*;

  localparam SIGN_W      = 1;
  localparam REMAINDER_W = 2 * ROOT_EXTENDED_W + SIGN_W;
  localparam TEST_SUB_W  = ROOT_EXTENDED_W + SIGN_W;

  localparam STAGE_STEPS           = ROOT_EXTENDED_W / PIPELINE_STAGES;
  localparam REMAINING_STAGE_STEPS = ROOT_EXTENDED_W - PIPELINE_STAGES * STAGE_STEPS;
  localparam SQRT_STEPS            = ROOT_EXTENDED_W;


  logic                       final_rem_is_neg;
  logic [ROOT_EXTENDED_W-1:0] root_extended;


  logic [    REMAINDER_W-1:0] AX;
  logic [     TEST_SUB_W-1:0] T;
  logic [ROOT_EXTENDED_W-1:0] Q;

  logic [    REMAINDER_W-1:0] AX_out;
  logic [     TEST_SUB_W-1:0] T_out;
  logic [ROOT_EXTENDED_W-1:0] Q_out;

  always_comb begin
    AX[ROOT_EXTENDED_W-1:0]           = mantissa_rad_i;
    AX[REMAINDER_W-1:ROOT_EXTENDED_W] = '0;
    T                                 = '0;
    Q                                 = '0;
  end


  sqrt_non_restoring_stage #(
      .DIN_W     (ROOT_EXTENDED_W),
      .DOUT_W    (ROOT_EXTENDED_W),
      .SQRT_STEPS(SQRT_STEPS)
  ) sqrt_non_restoring_stage_inst (
      .AX_i(AX),
      .T_i (T),
      .Q_i (Q),
      .AX_o(AX_out),
      .T_o (T_out),
      .Q_o (Q_out)
  );

  logic [REMAINDER_W-1:0] tc_AX_out;  // Two's Complement version of AX_out
  logic [REMAINDER_W-1:0] true_rem;
  logic [ TEST_SUB_W-1:0] restore_val;

  always_comb begin
    root_extended    = Q_out;

    // 1. CONVERT TO TWO'S COMPLEMENT
    // By inverting the Carry-Out MSB, we turn it into a standard signed number!
    tc_AX_out        = {~AX_out[REMAINDER_W-1], AX_out[REMAINDER_W-2:0]};

    // 2. Now we can check the standard sign bit directly (No '!' needed anymore)
    final_rem_is_neg = tc_AX_out[REMAINDER_W-1];

    if (final_rem_is_neg) begin
      root_extended_o = root_extended - 1'b1;

      // The overshoot is (2Q + 1)
      restore_val     = {root_extended_o, 1'b1};

      // 3. Add to restore. Because tc_AX_out is now a true negative, 
      // adding the positive restore_val will perfectly cancel it to 0!
      true_rem        = tc_AX_out + {restore_val, {ROOT_EXTENDED_W{1'b0}}};
    end else begin
      root_extended_o = root_extended;
      true_rem        = tc_AX_out;
    end

    // 4. MASK THE STICKY BIT
    // If it was a perfect square, true_rem is now exactly 000...000
    sticky_rem_o = (true_rem[REMAINDER_W-1 : ROOT_EXTENDED_W] != '0);
  end


endmodule
