module mantissa_divider_pipe
  import divider_float_pkg::*;
#(
    parameter      MANTISSA_W      = 11,
    parameter  int PIPELINE_STAGES = 1,
    localparam     QUOTIENT_RAW_W  = OFFSET_BIT_W + MANTISSA_W + GUARD_W
) (
  input  logic                      clk,
  input  logic                      clk_en,
  input  logic                      rst_n,
  input  logic [    MANTISSA_W-1:0] dividend_i,
  input  logic [    MANTISSA_W-1:0] divisor_i,
  input  logic                      valid_i,
  output logic [QUOTIENT_RAW_W-1:0] quotient_raw_o,
  output logic                      sticky_o,
  output logic                      valid_o
);
  localparam QUOTIENT_DIV_W = QUOTIENT_RAW_W | 1;
  localparam REMAINDER_W = REDUCTION_W + QUOTIENT_DIV_W;
  localparam COUNTER_LEN = (QUOTIENT_RAW_W + (REDUCTION_W)) / REDUCTION_W;

  localparam DIV_STEPS = COUNTER_LEN;
  localparam STAGE_STEPS = PIPELINE_STAGES ? (DIV_STEPS + 1) / (PIPELINE_STAGES + 1) : DIV_STEPS + 1;


  logic signed [   REMAINDER_W-1:0] rem_w      [COUNTER_LEN+1];
  logic signed [QUOTIENT_DIV_W-1:0] quot_w     [COUNTER_LEN+1];

  logic signed [   REMAINDER_W-1:0] rem_w_next [COUNTER_LEN+1];
  logic signed [QUOTIENT_DIV_W-1:0] quot_w_next[COUNTER_LEN+1];

  logic        [    MANTISSA_W-1:0] divisor    [COUNTER_LEN+1];
  logic                             valid      [COUNTER_LEN+1];

  assign rem_w[0]   = $signed({(SIGN_W + GUARD_W + REDUCTION_FACTOR)'(1'b0), dividend_i});
  assign quot_w[0]  = '0;
  assign divisor[0] = divisor_i;
  assign valid[0]   = valid_i;

  genvar i;
  generate
    for (i = 0; i < COUNTER_LEN; i++) begin : g_stage
      mantissa_divider_stage #(
          .MANTISSA_W    (MANTISSA_W),
          .QUOTIENT_RAW_W(QUOTIENT_DIV_W),
          .REMAINDER_W   (REMAINDER_W)
      ) stage_inst (
          .remainder_i(rem_w[i]),
          .quotient_i (quot_w[i]),
          .divisor_i  (divisor[i]),
          .remainder_o(rem_w_next[i]),
          .quotient_o (quot_w_next[i])
      );

      if (i < DIV_STEPS - 1) begin : prop_signal
        if ((i + 1) % STAGE_STEPS == 0) begin : reg_signal
          data_status_pipeline #(
              .DATA_W    (REMAINDER_W + QUOTIENT_DIV_W + MANTISSA_W),
              .STATUS_W  (1),
              .PIPE_DEPTH(1),
              .CLK_EN    (1)
          ) data_pipe (
              .clk     (clk),
              .clk_en  (clk_en),
              .rst_n   (rst_n),
              .data_i  ({rem_w_next[i], quot_w_next[i], divisor[i]}),
              .status_i(valid[i]),
              .data_o  ({rem_w[i+1], quot_w[i+1], divisor[i+1]}),
              .status_o(valid[i+1])
          );
        end else begin
          always_comb begin
            rem_w[i+1]   = rem_w_next[i];
            quot_w[i+1]  = quot_w_next[i];
            divisor[i+1] = divisor[i];

            valid[i+1]   = valid[i];
          end
        end
      end
    end

    if (QUOTIENT_RAW_W % 2 == 1) begin
      always_comb begin
        if (rem_w_next[COUNTER_LEN-1][REMAINDER_W-1]) begin
          quotient_raw_o = quot_w_next[COUNTER_LEN-1] - 1;
          sticky_o       = 1'b1;
        end else begin
          quotient_raw_o = quot_w_next[COUNTER_LEN-1];
          sticky_o       = (rem_w_next[COUNTER_LEN-1] != '0);
        end
      end
    end else begin
      logic [QUOTIENT_DIV_W-1:0] quotient_div;

      always_comb begin
        if (rem_w_next[COUNTER_LEN-1][REMAINDER_W-1]) begin
          quotient_div = quot_w_next[COUNTER_LEN-1] - 1;
          sticky_o     = 1'b1;
        end else begin
          quotient_div = quot_w_next[COUNTER_LEN-1];
          sticky_o     = (rem_w_next[COUNTER_LEN-1] != '0) || quot_w[0];
        end
        quotient_raw_o = quotient_div[QUOTIENT_DIV_W-1:1];
      end
    end
  endgenerate

  assign valid_o = valid[COUNTER_LEN-1];

endmodule
