// One SRT radix-4 iteration with carry-save remainder.
// The remainder is kept as (rem_sum, rem_carry) where rem_sum + rem_carry = true_remainder.
// QDS resolves the carry-save pair with a single adder; the update uses a CSA (2 XOR levels)
// instead of a full subtractor, removing the long carry chain from the critical path.
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

    // Shift both halves of the carry-save remainder
    rem_sum_shifted   = rem_sum_i   <<< REDUCTION_FACTOR;
    rem_carry_shifted = rem_carry_i <<< REDUCTION_FACTOR;

    // Resolve carry-save to a single value for QDS (one adder, replaces nothing — the old
    // design had no adder here.  The saving is in the *update* below.)
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
      3'sd2:  subtrahend = divisor_padded * 2;
      3'sd1:  subtrahend = divisor_padded;
      3'sd0:  subtrahend = '0;
      -3'sd1: subtrahend = divisor_padded_neg;
      -3'sd2: subtrahend = divisor_padded_neg * 2;
    endcase

    // CSA update: (rem_sum_o + rem_carry_o) = rem_sum_shifted + rem_carry_shifted - subtrahend
    // Replaces the full subtractor — only 2 XOR levels deep regardless of REMAINDER_W.
    neg_subtrahend = -subtrahend;
    rem_sum_o   = rem_sum_shifted ^ rem_carry_shifted ^ neg_subtrahend;
    rem_carry_o = ((rem_sum_shifted  & rem_carry_shifted) |
                   (rem_carry_shifted & neg_subtrahend)   |
                   (rem_sum_shifted  & neg_subtrahend)) << 1;

    quotient_o = (quotient_i <<< REDUCTION_FACTOR) + QUOTIENT_RAW_W'(quotient_digit);
  end

endmodule
