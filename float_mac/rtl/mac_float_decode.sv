module mac_float_decode
  import mac_float_pkg::*;
#(
    parameter type float_t                      = struct packed {logic sign; logic [5:0] exp; logic [9:0] frac;},
    parameter      SIGNED_EXP_W                 = 9,
    parameter      FRAC_IN_W                    = 10,
    parameter      EXP_IN_W                     = 5,
    parameter      FRAC_OUT_W                   = 10,
    parameter      EXP_OUT_W                    = 8,
    localparam     MANTISSA_IN_W                = FRAC_IN_W + 1,
    localparam     MANTISSA_OUT_W               = FRAC_OUT_W + 1,
    localparam     C_UPPER_SLICE_W              = MANTISSA_OUT_W + 3,
    localparam     PRODUCT_MANTISSA_W           = 2 * MANTISSA_IN_W,
    localparam     C_LOWER_SLICE_W              = PRODUCT_MANTISSA_W + FRAC_OUT_W - FRAC_IN_W
) (
    input  float_t                            float_a_i,
    input  float_t                            float_b_i,
    input  float_t                            float_c_i,
    output sum_float_flags_t                  sum_float_flags_o,
    output logic                              product_sign_o,
    output logic signed [   SIGNED_EXP_W-1:0] product_exp_o,
    output logic        [C_UPPER_SLICE_W-1:0] c_upper_slice_o,
    output logic        [C_LOWER_SLICE_W-1:0] c_lower_slice_o,
    output logic        [  MANTISSA_IN_W-1:0] norm_mant_a_o,
    output logic        [  MANTISSA_IN_W-1:0] norm_mant_b_o
);

  localparam BIAS                 = (1 << (EXP_IN_W - 1)) - 1;
 
  typedef struct packed {
    logic                     sign;
    logic [EXP_IN_W-1:0]      exp;
    logic [MANTISSA_IN_W-1:0] mantissa;
  } unpacked_float_t;
 
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
    logic         exp_max;
    logic         frac_zero;
    logic         exp_zero;

    exp_max           = float_i.exp == '1;
    exp_zero          = float_i.exp == '0;
    frac_zero         = float_i.frac == '0;

    flags_o.inf       = exp_max && frac_zero;
    flags_o.nan       = exp_max && !frac_zero;
    flags_o.frac_zero = frac_zero;
    flags_o.exp_zero  = exp_zero;
    flags_o.zero      = exp_zero && frac_zero;
    flags_o.sign      = float_i.sign;

    return flags_o;
  endfunction

  function automatic unpacked_float_t unpack_float(input float_t float_i, input logic exp_zero_i);
    unpacked_float_t unpacked_o;
    unpacked_o.sign     = float_i.sign;
    unpacked_o.exp      = float_i.exp;
    unpacked_o.mantissa = {1'b1, float_i.frac};

    if (exp_zero_i) begin
      unpacked_o.exp[0]                    = 1'b1;
      unpacked_o.mantissa[MANTISSA_IN_W-1] = 1'b0;
    end

    return unpacked_o;
  endfunction

  float_flags_t                    a_flags;
  float_flags_t                    b_flags;
  float_flags_t                    c_flags;

  float_flags_t                    product_flags;
  float_flags_t                    sum_flags;

  unpacked_float_t                unpacked_a;
  unpacked_float_t                unpacked_b;
  unpacked_float_t                unpacked_c;

  logic signed  [SIGNED_EXP_W-1:0] true_exp_a;
  logic signed  [SIGNED_EXP_W-1:0] true_exp_b;

  logic                         c_dominates;

  always_comb begin
    a_flags = deduce_float_flags(float_a_i);
    b_flags = deduce_float_flags(float_b_i);
    c_flags = deduce_float_flags(float_c_i);

    product_flags.zero = a_flags.zero || b_flags.zero;
    product_flags.inf = a_flags.inf || b_flags.inf;
    product_flags.nan = (a_flags.zero && b_flags.inf) || (a_flags.inf && b_flags.zero);
    product_flags.sign = a_flags.sign ^ b_flags.sign;

    sum_flags.zero = product_flags.zero && c_flags.zero;
    sum_flags.inf  = (product_flags.inf && c_flags.inf && (product_flags.sign == c_flags.sign))
                   ||product_flags.inf ^ c_flags.inf;

    sum_flags.nan = product_flags.inf && c_flags.inf && (product_flags.sign != c_flags.sign);
    sum_flags.sign = product_flags.inf ? product_flags.sign : c_flags.sign;

    sum_float_flags_o.sign = '0;
    sum_float_flags_o.inf = '0;
    sum_float_flags_o.nan = '0;


    if (a_flags.nan || b_flags.nan || c_flags.nan || product_flags.nan || sum_flags.nan) begin
      sum_float_flags_o.nan = 1'b1;
    end else begin
      sum_float_flags_o.inf  = sum_flags.inf;
      sum_float_flags_o.sign = sum_flags.sign;
    end
  end

  always_comb begin
    unpacked_a = unpack_float(float_a_i, a_flags.exp_zero);
    unpacked_b = unpack_float(float_b_i, b_flags.exp_zero);
    unpacked_c = unpack_float(float_c_i, c_flags.exp_zero);
  end

  // Lazy normalization: subnormal inputs flow through with leading-bit = 0
  // (already produced by unpack_float) and exp field substituted with 1
  // (also already done by unpack_float). The post-multiply LZC + shifter in
  // mac_float_align_round_sum normalizes the product, so we don't need to
  // pre-normalize subnormals here. IEEE 754 bit-exact: the encoded value is
  // unchanged, only the bit position shifts.
  always_comb begin
    norm_mant_a_o  = unpacked_a.mantissa;
    norm_mant_b_o  = unpacked_b.mantissa;
    true_exp_a     = $signed({3'b000, unpacked_a.exp});
    true_exp_b     = $signed({3'b000, unpacked_b.exp});
    product_sign_o = unpacked_a.sign ^ unpacked_b.sign;
    product_exp_o  = true_exp_a + true_exp_b - $signed(SIGNED_EXP_W'(BIAS));
  end

    align_addend #(
      .EXP_IN_W (EXP_IN_W),
      .FRAC_IN_W(FRAC_IN_W),
      .EXP_OUT_W (EXP_OUT_W),
      .FRAC_OUT_W(FRAC_OUT_W),
      .unpacked_float_t(unpacked_float_t)
  ) align_addend_inst (
      .unpacked_c_i       (unpacked_c),
      .product_exp_i      (product_exp_o),
      .product_sign_i     (product_sign_o),
      .c_upper_slice_o    (c_upper_slice_o),
      .c_lower_slice_o    (c_lower_slice_o),
      .c_lower_sticky_o   (sum_float_flags_o.sticky_c),
      .c_dominates_o      (c_dominates),
      .ignore_round_even_o(sum_float_flags_o.ignore_round_even)
  );

  assign sum_float_flags_o.c_dominates = (c_dominates && !c_flags.zero)|| product_flags.zero;

endmodule
