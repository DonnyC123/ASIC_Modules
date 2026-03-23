module mantissa_divider_stage
  import divider_float_pkg::*;
#(
    parameter  MANTISSA_W     = 11,
    localparam QUOTIENT_RAW_W = OFFSET_BIT_W + MANTISSA_W + GUARD_W,
    localparam REMAINDER_W    = SIGN_W + MANTISSA_W + REDUCTION_W + GUARD_W
) (
    input  logic signed [   REMAINDER_W-1:0] rem_sum_i,
    input  logic signed [   REMAINDER_W-1:0] rem_carry_i,
    input  logic signed [QUOTIENT_RAW_W-1:0] quotient_i,
    input  logic        [    MANTISSA_W-1:0] divisor_i,
    output logic signed [   REMAINDER_W-1:0] rem_sum_o,
    output logic signed [   REMAINDER_W-1:0] rem_carry_o,
    output logic signed [QUOTIENT_RAW_W-1:0] quotient_o
);

  localparam DIVISOR_SCALED_W = REMAINDER_W;

  logic signed [     REMAINDER_W-1:0] divisor_padded;
  logic signed [     REMAINDER_W-1:0] divisor_padded_neg;
  logic signed [DIVISOR_SCALED_W-1:0] divisor_scaled_pos_1_5;
  logic signed [DIVISOR_SCALED_W-1:0] divisor_scaled_pos_0_5;
  logic signed [DIVISOR_SCALED_W-1:0] divisor_scaled_neg_0_5;
  logic signed [DIVISOR_SCALED_W-1:0] divisor_scaled_neg_1_5;
  logic signed [QUOTIENT_DIGIT_W-1:0] quotient_digit;
  logic signed [     REMAINDER_W-1:0] rem_sum_shifted;
  logic signed [     REMAINDER_W-1:0] rem_carry_shifted;
  logic signed [     REMAINDER_W-1:0] rem_resolved;
  logic signed [     REMAINDER_W-1:0] subtrahend;
  logic signed [     REMAINDER_W-1:0] neg_subtrahend;

  always_comb begin
    divisor_padded =
        $signed({(SIGN_W + GUARD_W + REDUCTION_FACTOR)'(0), divisor_i, REDUCTION_FACTOR'(0)});
    divisor_padded_neg = -divisor_padded;

    divisor_scaled_pos_0_5 = divisor_padded / 2;
    divisor_scaled_pos_1_5 = divisor_padded + divisor_scaled_pos_0_5;
    divisor_scaled_neg_0_5 = divisor_padded_neg / 2;
    divisor_scaled_neg_1_5 = divisor_padded_neg + divisor_scaled_neg_0_5;

    rem_sum_shifted = rem_sum_i <<< REDUCTION_FACTOR;
    rem_carry_shifted = rem_carry_i <<< REDUCTION_FACTOR;

    rem_resolved = rem_sum_shifted + rem_carry_shifted;

    quotient_digit = QUOTIENT_DIGIT_W'(0);
    if (rem_resolved >= divisor_scaled_pos_0_5) begin
      quotient_digit = QUOTIENT_DIGIT_W'(1);
      if (rem_resolved >= divisor_scaled_pos_1_5) begin
        quotient_digit = QUOTIENT_DIGIT_W'(2);
      end
    end else if (rem_resolved <= divisor_scaled_neg_0_5) begin
      quotient_digit = QUOTIENT_DIGIT_W'(-1);
      if (rem_resolved <= divisor_scaled_neg_1_5) begin
        quotient_digit = QUOTIENT_DIGIT_W'(-2);
      end
    end

    unique case (quotient_digit)
      3'sd2:  neg_subtrahend = divisor_padded_neg * 2;
      3'sd1:  neg_subtrahend = divisor_padded_neg;
      3'sd0:  neg_subtrahend = '0;
      -3'sd1: neg_subtrahend = divisor_padded;
      -3'sd2: neg_subtrahend = divisor_padded * 2;
    endcase
    quotient_o = (quotient_i <<< REDUCTION_FACTOR) + QUOTIENT_RAW_W'(quotient_digit);
  end

  carry_save_row_adder #(
      .DATA_W(REMAINDER_W)
  ) csa_inst (
      .row_a(rem_sum_shifted),
      .row_b(rem_carry_shifted),
      .row_c(neg_subtrahend),
      .sum  (rem_sum_o),
      .carry(rem_carry_o)
  );

endmodule
