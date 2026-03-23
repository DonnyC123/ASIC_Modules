// Multi-cycle SRT radix-4 mantissa divider with carry-save remainder.
// Drop-in replacement for mantissa_divider.sv.
module mantissa_divider_mc
  import divider_float_pkg::*;
#(
    parameter  MANTISSA_W     = 11,
    localparam QUOTIENT_RAW_W = OFFSET_BIT_W + MANTISSA_W + GUARD_W
) (
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      start_i,
    input  logic [    MANTISSA_W-1:0] dividend_i,
    input  logic [    MANTISSA_W-1:0] divisor_i,
    output logic [QUOTIENT_RAW_W-1:0] quotient_raw_o,
    output logic                      sticky_o,
    output logic                      done_o
);

  localparam REMAINDER_W = SIGN_W + MANTISSA_W + REDUCTION_W + GUARD_W;
  localparam COUNTER_LEN = (QUOTIENT_RAW_W + (REDUCTION_W - 1)) / REDUCTION_W;
  localparam COUNTER_W   = $clog2(COUNTER_LEN) + 1;

  logic signed [   REMAINDER_W-1:0] rem_sum_d,  rem_sum_q;
  logic signed [   REMAINDER_W-1:0] rem_carry_d, rem_carry_q;
  logic signed [QUOTIENT_RAW_W-1:0] quotient_d,  quotient_q;
  logic        [    MANTISSA_W-1:0] divisor_d,   divisor_q;
  logic        [     COUNTER_W-1:0] counter_d,   counter_q;
  mantissa_divider_state_t          state_d,     state_q;

  logic signed [   REMAINDER_W-1:0] stage_rem_sum_o;
  logic signed [   REMAINDER_W-1:0] stage_rem_carry_o;
  logic signed [QUOTIENT_RAW_W-1:0] stage_quot_o;

  mantissa_divider_stage #(
      .MANTISSA_W(MANTISSA_W)
  ) stage_inst (
      .rem_sum_i  (rem_sum_q),
      .rem_carry_i(rem_carry_q),
      .quotient_i (quotient_q),
      .divisor_i  (divisor_q),
      .rem_sum_o  (stage_rem_sum_o),
      .rem_carry_o(stage_rem_carry_o),
      .quotient_o (stage_quot_o)
  );

  always_comb begin
    state_d     = state_q;
    divisor_d   = divisor_q;
    rem_sum_d   = rem_sum_q;
    rem_carry_d = rem_carry_q;
    quotient_d  = quotient_q;
    counter_d   = '0;
    done_o      = '0;
    sticky_o    = '0;

    unique case (state_q)
      IDLE: begin
        if (start_i) begin
          state_d     = ACTIVE;
          divisor_d   = divisor_i;
          rem_sum_d   = $signed({(SIGN_W + GUARD_W + REDUCTION_FACTOR)'(1'b0), dividend_i});
          rem_carry_d = '0;
          quotient_d  = '0;
        end
      end
      ACTIVE: begin
        counter_d   = counter_q + 1;
        rem_sum_d   = stage_rem_sum_o;
        rem_carry_d = stage_rem_carry_o;
        quotient_d  = stage_quot_o;
        if (counter_q == COUNTER_W'($unsigned(COUNTER_LEN - 1))) begin
          state_d = DONE;
        end
      end
      DONE: begin
        done_o  = 1'b1;
        state_d = IDLE;
        // Resolve carry-save remainder to check sign
        begin
          logic signed [REMAINDER_W-1:0] final_rem;
          final_rem = rem_sum_q + rem_carry_q;
          if (final_rem[REMAINDER_W-1]) begin
            quotient_d = quotient_q - 1;
            sticky_o   = 1'b1;
          end else begin
            quotient_d = quotient_q;
            sticky_o   = (final_rem != '0);
          end
        end
      end
    endcase
  end

  assign quotient_raw_o = quotient_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= IDLE;
    end else begin
      state_q     <= state_d;
      divisor_q   <= divisor_d;
      rem_sum_q   <= rem_sum_d;
      rem_carry_q <= rem_carry_d;
      quotient_q  <= quotient_d;
      counter_q   <= counter_d;
    end
  end

endmodule
