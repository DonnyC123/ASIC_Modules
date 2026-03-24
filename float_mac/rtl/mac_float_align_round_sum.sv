module mac_float_align_round_sum
  import mac_float_pkg::*;
#(
    parameter EXP_W        = 6,
    parameter FRAC_W       = 10,
    parameter FULL_SUM_W   = 33,
    parameter SIGNED_EXP_W = 9,
    parameter type float_t = struct packed {
      logic sign;
      logic [EXP_W-1:0] exp;
      logic [FRAC_W-1:0] frac;
    },

    localparam MANTISSA_W         = FRAC_W + 1,
    localparam PRODUCT_MANTISSA_W = MANTISSA_W * 2

) (
    input  float_t                              float_c_i,
    input  sum_float_flags_t                    sum_float_flags_i,
    input  logic                                sum_signed_i,
    input  logic signed      [SIGNED_EXP_W-1:0] product_exp_i,
    input  logic             [  FULL_SUM_W-1:0] unsigned_mantissa_sum_i,
    output float_t                              float_sum_rounded,
    output logic                                sum_rounded_exp_ovfl_o,
    output logic                                sum_rounded_exp_unfl_o
);

  localparam LZC_COUNT_W        = $clog2(FULL_SUM_W + 1);
  localparam LZC_COUNT_OVFL_W   = LZC_COUNT_W + 1;
  localparam SUM_EXP_ADD_OFFSET = FULL_SUM_W - PRODUCT_MANTISSA_W;

  localparam EXP_OVFL_IDX = EXP_W + CARRY_W - 1;
  localparam EXP_SIGN_IDX = EXP_W + SIGN_W + CARRY_W - 1;

  localparam NORMAL_FRAC_LSB_IDX = FULL_SUM_W - 1 - FRAC_W;
  localparam GUARD_IDX           = NORMAL_FRAC_LSB_IDX - 1;

  logic        [     LZC_COUNT_W-1:0] mantissa_sum_lz;
  logic        [     LZC_COUNT_W-1:0] mantissa_sum_shift;
  logic        [LZC_COUNT_OVFL_W-1:0] mantissa_sum_shift_ovfl;

  // Speculative sticky: suffix OR precomputed before the barrel shift.
  // suffix_or[k] = |unsigned_mantissa_sum_i[k:0]
  // Indexed by (GUARD_IDX-1-shift) to get the sticky without waiting for the shift output.
  logic        [      FULL_SUM_W-1:0] suffix_or;

  logic signed [    SIGNED_EXP_W-1:0] sum_exp;
  logic                               sum_exp_ovfl;
  logic                               sum_exp_unfl;

  logic                               sum_rounded_signed;
  logic        [      FULL_SUM_W-1:0] normalized_mantissa;
  logic signed [    SIGNED_EXP_W-1:0] sum_rounded_exp_raw;
  logic        [          FRAC_W-1:0] sum_frac_raw;
  logic        [      MANTISSA_W-1:0] sum_frac_carry;
  logic        [          FRAC_W-1:0] sum_frac_rounded;

  logic                               sticky_sum;
  logic                               guard;
  logic                               round_mantissa;

  logic        [          FRAC_W-1:0] sum_frac_plus1;
  logic                               sum_frac_plus1_ovfl;
  logic signed [    SIGNED_EXP_W-1:0] sum_exp_plus1;

  leading_zero_counter_top #(
      .DATA_W          (FULL_SUM_W),
      .LZC_DATA_BLOCK_W(4)
  ) leading_zero_counter_top_inst (
      .data_i              (unsigned_mantissa_sum_i),
      .leading_zero_count_o(mantissa_sum_lz)
  );

  always_comb begin

    suffix_or[0] = unsigned_mantissa_sum_i[0];
    for (int k = 1; k < FULL_SUM_W; k++) begin
      suffix_or[k] = suffix_or[k-1] | unsigned_mantissa_sum_i[k];
    end
  end

  always_comb begin
    sum_rounded_signed = sum_signed_i;

    // Use SIGNED_EXP_W' to zero-extend lz count cleanly — avoids upper-bit
    // truncation that was blocking CSA with the {2'b0, ...} concatenation.
    sum_exp = product_exp_i - $signed(SIGNED_EXP_W'(mantissa_sum_lz))
            + SIGNED_EXP_W'(SUM_EXP_ADD_OFFSET + MANTISSA_W - FRAC_W);
    sum_exp_ovfl = sum_exp[EXP_OVFL_IDX] && !sum_exp[EXP_SIGN_IDX];
    sum_exp_unfl = sum_exp[EXP_OVFL_IDX] && sum_exp[EXP_SIGN_IDX];

    mantissa_sum_shift_ovfl = $unsigned(product_exp_i + LZC_COUNT_OVFL_W'(SUM_EXP_ADD_OFFSET) +
                                        LZC_COUNT_OVFL_W'(MANTISSA_W - FRAC_W));

    if (sum_exp_unfl) begin
      mantissa_sum_shift = mantissa_sum_shift_ovfl[LZC_COUNT_W-1:0];
    end else begin
      mantissa_sum_shift = mantissa_sum_lz;
    end

    normalized_mantissa = unsigned_mantissa_sum_i << mantissa_sum_shift;
    sum_frac_raw        = normalized_mantissa[FULL_SUM_W-1-MANTISSA_INT_W-:FRAC_W];

    if (mantissa_sum_shift < LZC_COUNT_W'(GUARD_IDX)) begin
      sticky_sum = suffix_or[GUARD_IDX-1-mantissa_sum_shift];
    end else begin
      sticky_sum = 1'b0;
    end
    guard = normalized_mantissa[GUARD_IDX];

    if (sum_float_flags_i.c_dominates) begin
      sum_frac_raw       = float_c_i.frac;
      sticky_sum         = '0;
      guard              = '0;
      sum_exp            = $signed({3'b0, float_c_i.exp});
      sum_rounded_signed = float_c_i.sign;

    end else if (sum_exp_unfl || sum_exp == 0) begin
      sum_frac_raw = normalized_mantissa[FULL_SUM_W-1-:FRAC_W];
      sticky_sum   = |normalized_mantissa[GUARD_IDX:0];
      guard        = normalized_mantissa[GUARD_IDX+1];
    end

    round_mantissa = guard && (sticky_sum || sum_float_flags_i.sticky_c || (sum_frac_raw[0] && !sum_float_flags_i.ignore_round_even));

    // Speculative rounding: precompute sum_frac_raw+1 in parallel with
    // round_mantissa, then mux. round_mantissa drives only a mux (1 gate)
    // instead of feeding into the adder carry chain.
    {sum_frac_plus1_ovfl, sum_frac_plus1} = sum_frac_raw + 1'b1;
    sum_frac_carry = round_mantissa ? {sum_frac_plus1_ovfl, sum_frac_plus1}
                                    : {1'b0, sum_frac_raw};

    // Speculative exponent increment: precompute sum_exp+1 in parallel with
    // sum_frac_carry, then mux on the carry-out bit.
    sum_exp_plus1       = sum_exp + 1;
    sum_rounded_exp_raw = (sum_frac_carry[MANTISSA_W-1] && !sum_exp_ovfl) ? sum_exp_plus1 : sum_exp;

    sum_rounded_exp_ovfl_o = sum_rounded_exp_raw[EXP_OVFL_IDX] && !sum_exp[EXP_SIGN_IDX];
    sum_rounded_exp_unfl_o = sum_rounded_exp_raw[EXP_OVFL_IDX] && sum_exp[EXP_SIGN_IDX];
    sum_frac_rounded = sum_frac_carry[FRAC_W-1:0];

    float_sum_rounded.exp = sum_rounded_exp_raw[EXP_W-1:0];
    float_sum_rounded.sign = sum_rounded_signed;
    float_sum_rounded.frac = sum_frac_rounded;
  end
endmodule
