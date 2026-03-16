module divider_float_decoder
  import divider_float_pkg::*;
#(
    parameter      EXP_W        = 6,
    parameter      MANTISSA_W   = 11,
    parameter      SIGNED_EXP_W = 8,
    parameter type float_t      = struct packed {logic sign; logic [5:0] exp; logic [9:0] frac;}
) (
    input  float_t                                float_a_i,
    input  float_t                                float_b_i,
    output quotient_float_flags_t                 float_quotient_flags_o,
    output logic                 [MANTISSA_W-1:0] norm_mant_a_o,
    output logic                 [MANTISSA_W-1:0] norm_mant_b_o,
    output logic signed        [SIGNED_EXP_W-1:0] quotient_exp_o
);

  localparam LZ_COUNTER_W    = $clog2(MANTISSA_W);
  localparam BIAS            = (1 << (EXP_W - 1)) - 1;
  localparam EXP_TO_SIGNED_W = SIGNED_EXP_W - EXP_W; // Clean this up 

  typedef struct {
    logic sign;
    logic inf;
    logic nan;
    logic zero;
    logic frac_zero;
    logic exp_zero;
  } float_flags_t;

  function automatic float_flags_t deduce_float_flags(input float_t float_i);
    float_flags_t flags_o;
    logic                 frac_zero;
    logic                 exp_max;
    logic                 exp_zero;

    frac_zero         = float_i.frac == '0;
    exp_zero          = float_i.exp == '0;
    exp_max           = float_i.exp == '1;

    flags_o.sign      = float_i.sign;
    flags_o.nan       = exp_max && !frac_zero;
    flags_o.inf       = exp_max && frac_zero;
    flags_o.zero      = frac_zero && exp_zero;
    flags_o.frac_zero = frac_zero;
    flags_o.exp_zero  = exp_zero;

    return flags_o;
  endfunction

  float_flags_t                    a_flags;
  float_flags_t                    b_flags;

  logic signed          [SIGNED_EXP_W-1:0] true_exp_a;
  logic signed          [SIGNED_EXP_W-1:0] true_exp_b;
  logic                 [LZ_COUNTER_W-1:0] lz_a;
  logic                 [LZ_COUNTER_W-1:0] lz_b;


  always_comb begin
    a_flags                     = deduce_float_flags(float_a_i);
    b_flags                     = deduce_float_flags(float_b_i);

    float_quotient_flags_o.sign = a_flags.sign ^ b_flags.sign;
    float_quotient_flags_o.inf  = '0;
    float_quotient_flags_o.nan  = '0;
    float_quotient_flags_o.zero = '0;

    if ((a_flags.inf && b_flags.inf) || (a_flags.zero && b_flags.zero) || a_flags.nan || b_flags.nan) begin
      float_quotient_flags_o.nan = 1'b1;
    end else if (a_flags.zero || b_flags.inf) begin
      float_quotient_flags_o.zero = 1'b1;
    end else begin
      float_quotient_flags_o.inf = a_flags.inf || b_flags.zero;
    end
  end

  leading_zero_counter_top #(
      .DATA_W(MANTISSA_W - 1)
  ) leading_zero_counter_a_top_inst (
      .data_i              (float_a_i.frac),
      .leading_zero_count_o(lz_a)
  );

  leading_zero_counter_top #(
      .DATA_W(MANTISSA_W - 1)
  ) leading_zero_counter_b_top_inst (
      .data_i              (float_b_i.frac),
      .leading_zero_count_o(lz_b)
  );

  always_comb begin
    if (a_flags.exp_zero && !a_flags.frac_zero) begin
      true_exp_a    = -$signed({1'b0, lz_a});
      norm_mant_a_o = {float_a_i.frac << lz_a, 1'b0};
    end else begin
      true_exp_a    = a_flags.exp_zero ? $signed('0) : $signed({{EXP_TO_SIGNED_W{1'b0}}, float_a_i.exp});
      norm_mant_a_o = {1'b1, float_a_i.frac};
    end

    if (b_flags.exp_zero && !b_flags.frac_zero) begin
      true_exp_b    = -$signed({1'b0, lz_b});
      norm_mant_b_o = {float_b_i.frac << lz_b, 1'b0};
    end else begin
      true_exp_b    = b_flags.exp_zero ? $signed('0) : $signed({{EXP_TO_SIGNED_W{1'b0}}, float_b_i.exp});
      norm_mant_b_o = {1'b1, float_b_i.frac};
    end

    quotient_exp_o  = true_exp_a - true_exp_b + $signed(SIGNED_EXP_W'(BIAS));
  end
endmodule
