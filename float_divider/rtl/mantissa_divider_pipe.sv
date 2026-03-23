module mantissa_divider_pipe
  import divider_float_pkg::*;
#(
    parameter  MANTISSA_W     = 11,
    localparam QUOTIENT_RAW_W = OFFSET_BIT_W + MANTISSA_W + GUARD_W
) (
    input  logic [    MANTISSA_W-1:0] dividend_i,
    input  logic [    MANTISSA_W-1:0] divisor_i,
    output logic [QUOTIENT_RAW_W-1:0] quotient_raw_o,
    output logic                      sticky_o
);

  localparam REMAINDER_W = SIGN_W + MANTISSA_W + REDUCTION_W + GUARD_W;
  localparam COUNTER_LEN = (QUOTIENT_RAW_W + (REDUCTION_W - 1)) / REDUCTION_W;

  logic signed [   REMAINDER_W-1:0] rem_sum_w  [COUNTER_LEN+1];
  logic signed [   REMAINDER_W-1:0] rem_carry_w[COUNTER_LEN+1];
  logic signed [QUOTIENT_RAW_W-1:0] quot_w     [COUNTER_LEN+1];

  assign rem_sum_w[0]   = $signed({(SIGN_W + GUARD_W + REDUCTION_FACTOR)'(1'b0), dividend_i});
  assign rem_carry_w[0] = '0;
  assign quot_w[0]      = '0;

  genvar i;
  generate
    for (i = 0; i < COUNTER_LEN; i++) begin : g_stage
      mantissa_divider_stage #(
          .MANTISSA_W(MANTISSA_W)
      ) stage_inst (
          .rem_sum_i  (rem_sum_w[i]),
          .rem_carry_i(rem_carry_w[i]),
          .quotient_i (quot_w[i]),
          .divisor_i  (divisor_i),
          .rem_sum_o  (rem_sum_w[i+1]),
          .rem_carry_o(rem_carry_w[i+1]),
          .quotient_o (quot_w[i+1])
      );
    end
  endgenerate

  always_comb begin
    logic signed [REMAINDER_W-1:0] final_rem;
    final_rem = rem_sum_w[COUNTER_LEN] + rem_carry_w[COUNTER_LEN];
    if (final_rem[REMAINDER_W-1]) begin
      quotient_raw_o = quot_w[COUNTER_LEN] - 1;
      sticky_o       = 1'b1;
    end else begin
      quotient_raw_o = quot_w[COUNTER_LEN];
      sticky_o       = (final_rem != '0);
    end
  end

endmodule
