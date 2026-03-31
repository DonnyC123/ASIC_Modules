module mac_float_align_round_sum
  import mac_float_pkg::*;
#(
    parameter EXP_IN_W         = 5,
    parameter FRAC_IN_W        = 10,
    parameter EXP_OUT_W        = 8,
    parameter FRAC_OUT_W       = 23,
    parameter FULL_SUM_W       = 62,
    localparam SIGNED_EXP_IN_W = EXP_IN_W + 3,
    localparam MANTISSA_IN_W   = FRAC_IN_W + 1,
    localparam MANTISSA_OUT_W  = FRAC_OUT_W + 1,
    parameter type float_in_t  = struct packed {
      logic sign;
      logic [EXP_IN_W-1:0] exp;
      logic [FRAC_IN_W-1:0] frac;
    },
    parameter type float_out_t = struct packed {
      logic sign;
      logic [EXP_OUT_W-1:0] exp;
      logic [FRAC_OUT_W-1:0] frac;
    }
) (
    input  float_in_t                              float_c_i,
    input  sum_float_flags_t                       sum_float_flags_i,
    input  logic                                   sum_signed_i,
    input  logic signed      [SIGNED_EXP_IN_W-1:0] product_exp_i,
    input  logic             [     FULL_SUM_W-1:0] unsigned_mantissa_sum_i,
    output float_out_t                             float_sum_rounded,
    output logic                                   sum_rounded_exp_ovfl_o,
    output logic                                   sum_rounded_exp_unfl_o
);

  localparam PRODUCT_MANTISSA_W = MANTISSA_IN_W * 2;

  localparam LZC_COUNT_W        = $clog2(FULL_SUM_W + 1);
  localparam SUM_EXP_ADD_OFFSET = FULL_SUM_W - PRODUCT_MANTISSA_W;

  localparam EXP_OVFL_IDX = EXP_OUT_W;
  localparam EXP_SIGN_IDX = EXP_OUT_W + 1;

  localparam NORMAL_FRAC_LSB_IDX = FULL_SUM_W - 1 - FRAC_OUT_W;
  localparam GUARD_IDX           = NORMAL_FRAC_LSB_IDX - 1;

  localparam BIAS_IN  = (1 << (EXP_IN_W - 1)) - 1;
  localparam BIAS_OUT = (1 << (EXP_OUT_W - 1)) - 1;


  logic        [   LZC_COUNT_W-1:0] mantissa_sum_lz;
  logic        [   LZC_COUNT_W-1:0] mantissa_sum_shift;

  logic signed [     EXP_OUT_W+1:0] sum_exp;
  logic                             sum_exp_unfl;

  logic                             sum_rounded_signed;
  logic        [    FULL_SUM_W-1:0] normalized_mantissa;
  logic signed [     EXP_OUT_W+1:0] sum_rounded_exp_raw;
  logic        [    FRAC_OUT_W-1:0] sum_frac_raw;
  logic        [MANTISSA_OUT_W-1:0] sum_frac_carry;
  logic        [    FRAC_OUT_W-1:0] sum_frac_rounded;

  logic                             sticky_sum;
  logic                             guard;
  logic                             round_mantissa;

  leading_zero_counter_top #(
      .DATA_W          (FULL_SUM_W),
      .LZC_DATA_BLOCK_W(4)
  ) leading_zero_counter_top_inst (
      .data_i              (unsigned_mantissa_sum_i),
      .leading_zero_count_o(mantissa_sum_lz)
  );

  always_comb begin
    sum_rounded_signed = sum_signed_i;

    sum_exp = product_exp_i - $signed({2'b0, mantissa_sum_lz}) + (SUM_EXP_ADD_OFFSET) +
        (FRAC_OUT_W - FRAC_IN_W) + (MANTISSA_IN_W - FRAC_IN_W) + (BIAS_OUT - BIAS_IN);

    sum_exp_unfl = sum_exp[EXP_OVFL_IDX] && sum_exp[EXP_SIGN_IDX];

    mantissa_sum_shift = mantissa_sum_lz;
    normalized_mantissa = unsigned_mantissa_sum_i << mantissa_sum_shift;
    sum_frac_raw = normalized_mantissa[FULL_SUM_W-1-MANTISSA_INT_W-:FRAC_OUT_W];
    sticky_sum = |normalized_mantissa[GUARD_IDX-1:0];
    guard = normalized_mantissa[GUARD_IDX];

    if (sum_float_flags_i.c_dominates) begin
      sum_frac_raw       = FRAC_OUT_W'(float_c_i.frac) << (FRAC_OUT_W - FRAC_IN_W);
      sticky_sum         = '0;
      guard              = '0;
      sum_exp            = $signed({3'b0, float_c_i.exp}) + (BIAS_OUT - BIAS_IN);
      sum_rounded_signed = float_c_i.sign;

    end else if (sum_exp_unfl || sum_exp == 0) begin
      sum_frac_raw = normalized_mantissa[FULL_SUM_W-1-:FRAC_OUT_W];
      sticky_sum   = |normalized_mantissa[GUARD_IDX:0];
      guard        = normalized_mantissa[GUARD_IDX+1];
    end

    round_mantissa = guard && (sticky_sum || sum_float_flags_i.sticky_c || (sum_frac_raw[0] && !sum_float_flags_i.ignore_round_even));
    sum_frac_carry = sum_frac_raw + FRAC_OUT_W'(round_mantissa);

    sum_rounded_exp_raw = (sum_frac_carry[MANTISSA_OUT_W-1] && !sum_exp[EXP_OVFL_IDX]) ? sum_exp + 1 : sum_exp;

    sum_rounded_exp_ovfl_o = sum_rounded_exp_raw[EXP_OVFL_IDX] && !sum_rounded_exp_raw[EXP_SIGN_IDX];
    sum_rounded_exp_unfl_o = sum_rounded_exp_raw[EXP_OVFL_IDX] && sum_rounded_exp_raw[EXP_SIGN_IDX];
    sum_frac_rounded = sum_frac_carry[FRAC_OUT_W-1:0];

    float_sum_rounded.exp = sum_rounded_exp_raw[EXP_OUT_W-1:0];
    float_sum_rounded.sign = sum_rounded_signed;
    float_sum_rounded.frac = sum_frac_rounded;
  end
endmodule
