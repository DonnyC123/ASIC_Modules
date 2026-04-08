module mantissa_divider
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

  localparam REMAINDER_W      = SIGN_W + MANTISSA_W + REDUCTION_W + GUARD_W;
  localparam DIVISOR_SCALED_W = REMAINDER_W;
  localparam COUNTER_LEN      = (QUOTIENT_RAW_W + (REDUCTION_W - 1)) / REDUCTION_W;
  localparam COUNTER_W        = $clog2(COUNTER_LEN) + 1;

  logic                    [      MANTISSA_W-1:0] divisor_d;
  logic                    [      MANTISSA_W-1:0] divisor_q;

  logic signed             [     REMAINDER_W-1:0] remainder_d;
  logic signed             [     REMAINDER_W-1:0] remainder_shifted;
  logic signed             [     REMAINDER_W-1:0] remainder_q;

  logic signed             [  QUOTIENT_RAW_W-1:0] quotient_extended_d;
  logic signed             [  QUOTIENT_RAW_W-1:0] quotient_extended_q;

  logic signed             [     REMAINDER_W-1:0] divisor_padded;
  logic signed             [     REMAINDER_W-1:0] divisor_padded_neg;

  logic signed             [QUOTIENT_DIGIT_W-1:0] quotient_digit;

  logic signed             [DIVISOR_SCALED_W-1:0] divisor_scaled_pos_1_5;
  logic signed             [DIVISOR_SCALED_W-1:0] divisor_scaled_pos_0_5;
  logic signed             [DIVISOR_SCALED_W-1:0] divisor_scaled_neg_0_5;
  logic signed             [DIVISOR_SCALED_W-1:0] divisor_scaled_neg_1_5;

  logic signed             [     REMAINDER_W-1:0] subtrahend;

  mantissa_divider_state_t                        divider_state_d;
  mantissa_divider_state_t                        divider_state_q;

  logic                    [       COUNTER_W-1:0] divider_counter_d;
  logic                    [       COUNTER_W-1:0] divider_counter_q;

  always_comb begin
    divisor_padded         = $signed({(SIGN_W + GUARD_W)'(0), divisor_q, REDUCTION_FACTOR'(0)});

    divisor_padded_neg     = -divisor_padded;

    divisor_scaled_pos_0_5 = divisor_padded / 2;
    divisor_scaled_pos_1_5 = divisor_padded + divisor_scaled_pos_0_5;
    divisor_scaled_neg_0_5 = divisor_padded_neg / 2;
    divisor_scaled_neg_1_5 = divisor_padded_neg + divisor_scaled_neg_0_5;

    quotient_digit         = QUOTIENT_DIGIT_W'(0);
    remainder_shifted      = remainder_q <<< REDUCTION_FACTOR;

    if (remainder_shifted >= divisor_scaled_pos_0_5) begin
      quotient_digit = QUOTIENT_DIGIT_W'(1);
      if (remainder_shifted >= divisor_scaled_pos_1_5) begin
        quotient_digit = QUOTIENT_DIGIT_W'(2);
      end
    end else if (remainder_shifted <= divisor_scaled_neg_0_5) begin
      quotient_digit = QUOTIENT_DIGIT_W'(-1);
      if (remainder_shifted <= divisor_scaled_neg_1_5) begin
        quotient_digit = QUOTIENT_DIGIT_W'(-2);
      end
    end

    unique case (quotient_digit)
      3'sd2:  subtrahend = divisor_padded * 2;
      3'sd1:  subtrahend = divisor_padded;
      3'sd0:  subtrahend = '0;
      -3'sd1: subtrahend = divisor_padded_neg;
      -3'sd2: subtrahend = divisor_padded_neg * 2;
    endcase
  end

  always_comb begin
    divider_state_d     = divider_state_q;
    divisor_d           = divisor_q;
    remainder_d         = remainder_q;
    quotient_extended_d = quotient_extended_q;
    divider_counter_d   = '0;
    done_o              = '0;
    sticky_o            = '0;

    unique case (divider_state_q)
      IDLE: begin
        if (start_i) begin
          divider_state_d     = ACTIVE;
          divisor_d           = divisor_i;
          remainder_d         = $signed({(SIGN_W + GUARD_W + REDUCTION_FACTOR)'(1'b0), dividend_i});
          quotient_extended_d = '0;
        end
      end
      ACTIVE: begin
        divider_counter_d = divider_counter_q + 1;
        quotient_extended_d = (quotient_extended_q <<< REDUCTION_FACTOR) + QUOTIENT_RAW_W'(quotient_digit);
        remainder_d = remainder_shifted - subtrahend;

        if (divider_counter_q == COUNTER_W'($unsigned(COUNTER_LEN - 1))) begin
          divider_state_d = DONE;
        end
      end

      DONE: begin
        done_o          = 1'b1;
        divider_state_d = IDLE;
        if (remainder_q[REMAINDER_W-1]) begin
          quotient_extended_d = quotient_extended_q - 1;
          sticky_o            = 1'b1;
        end else begin
          quotient_extended_d = quotient_extended_q;
          sticky_o            = (remainder_q != 0);
        end

      end
    endcase
  end

  always_comb begin
    quotient_raw_o = quotient_extended_d;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      divider_state_q = IDLE;
    end else begin
      divider_state_q     = divider_state_d;
      divisor_q           = divisor_d;
      remainder_q         = remainder_d;
      quotient_extended_q = quotient_extended_d;
      divider_counter_q   = divider_counter_d;
    end
  end

endmodule
