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
  localparam QUOTIENT_DIV_W = QUOTIENT_RAW_W | 1;
  localparam REMAINDER_W    = REDUCTION_W + QUOTIENT_DIV_W;
  localparam COUNTER_LEN    = (QUOTIENT_RAW_W + (REDUCTION_W)) / REDUCTION_W;

  logic signed [   REMAINDER_W-1:0] rem_w        [COUNTER_LEN+1];
  logic signed [QUOTIENT_DIV_W-1:0] quot_w       [COUNTER_LEN+1];

  logic        [QUOTIENT_DIV_W-1:0] quotient_div;

  assign rem_w[0]  = $signed({(SIGN_W + GUARD_W + REDUCTION_FACTOR)'(1'b0), dividend_i});
  assign quot_w[0] = '0;

  genvar i;
  generate
    for (i = 0; i < COUNTER_LEN; i++) begin : g_stage
      mantissa_divider_stage #(
          .MANTISSA_W(MANTISSA_W | 1)
      ) stage_inst (
          .remainder_i(rem_w[i]),
          .quotient_i (quot_w[i]),
          .divisor_i  (divisor_i),
          .remainder_o(rem_w[i+1]),
          .quotient_o (quot_w[i+1])
      );
    end

    if (QUOTIENT_RAW_W % 2 == 1) begin
      always_comb begin
        if (rem_w[COUNTER_LEN][REMAINDER_W-1]) begin
          quotient_raw_o = quot_w[COUNTER_LEN] - 1;
          sticky_o       = 1'b1;
        end else begin
          quotient_raw_o = quot_w[COUNTER_LEN];
          sticky_o       = (rem_w[COUNTER_LEN] != '0);
        end
      end
    end else begin


      always_comb begin
        if (rem_w[COUNTER_LEN][REMAINDER_W-1]) begin
          quotient_div = quot_w[COUNTER_LEN] - 1;
          sticky_o     = 1'b1;
        end else begin
          quotient_div = quot_w[COUNTER_LEN];
          sticky_o     = (rem_w[COUNTER_LEN] != '0) || quot_w[0];
        end
        quotient_raw_o = quotient_div[QUOTIENT_DIV_W-1:1];
      end
    end
  endgenerate

endmodule
