module mac_float_decode
  import mac_float_pkg::*;
#(
    parameter type float_t            = struct packed {logic sign; logic [5:0] exp; logic [9:0] frac;},
    parameter      SIGNED_EXP_W       = 9,
    parameter      MANTISSA_W         = 11,
    parameter      EXP_W              = 5,
    parameter      PARTIAL_SUM_HIGH_W = 14,
    parameter      PRODUCT_MANTISSA_W = 2 * (MANTISSA_W)
) (
    input  float_t                          float_a_i,
    input  float_t                          float_b_i,
    input  float_t                          float_c_i,
    output sum_float_flags_t                sum_float_flags_o,
    output logic                            product_sign_o,
    output logic signed [SIGNED_EXP_W-1:0]  product_exp_o,
    output logic [PARTIAL_SUM_HIGH_W-1:0]   c_upper_slice_o,
    output logic [PRODUCT_MANTISSA_W-1:0]   csa_c_o,
    output logic         [  MANTISSA_W-1:0] norm_mant_a_o,
    output logic         [  MANTISSA_W-1:0] norm_mant_b_o
);

  localparam LZ_COUNTER_W         = $clog2(MANTISSA_W);
  localparam BIAS                 = (1 << (EXP_W - 1)) - 1;
 
  typedef struct packed {
    logic                  sign;
    logic [EXP_W-1:0]      exp;
    logic [MANTISSA_W-1:0] mantissa;
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
      unpacked_o.exp[0]                 = 1'b1;
      unpacked_o.mantissa[MANTISSA_W-1] = 1'b0;
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
  logic         [LZ_COUNTER_W-1:0] lz_a;
  logic         [LZ_COUNTER_W-1:0] lz_b;
 
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

  leading_zero_counter_top #(
      .DATA_W(MANTISSA_W-1)
  ) leading_zero_counter_a_top_inst (
      .data_i              (float_a_i.frac),
      .leading_zero_count_o(lz_a)
  );

  leading_zero_counter_top #(
      .DATA_W(MANTISSA_W-1)
  ) leading_zero_counter_b_top_inst (
      .data_i              (float_b_i.frac),
      .leading_zero_count_o(lz_b)
  );

  always_comb begin
    if (a_flags.exp_zero && !a_flags.frac_zero) begin
      true_exp_a  = -$signed({1'b0, lz_a});
      norm_mant_a_o = {float_a_i.frac << lz_a, 1'b0};
    end else begin
      true_exp_a  = a_flags.exp_zero ? $signed('0) : $signed({3'b000, unpacked_a.exp});
      norm_mant_a_o = unpacked_a.mantissa;
    end

   if (b_flags.exp_zero && !b_flags.frac_zero) begin
      true_exp_b    = -$signed({1'b0, lz_b});
      norm_mant_b_o = {float_b_i.frac << lz_b, 1'b0};
   end else begin
      true_exp_b    = b_flags.exp_zero ? $signed('0) : $signed({3'b000, unpacked_b.exp});
      norm_mant_b_o = unpacked_b.mantissa;
     end
 
    product_sign_o = unpacked_a.sign ^ unpacked_b.sign;
    product_exp_o  = true_exp_a + true_exp_b - $signed(SIGNED_EXP_W'(BIAS));
  end

    align_addend #(
      .EXP_W (EXP_W),
      .FRAC_W(MANTISSA_W-1),
      .unpacked_float_t(unpacked_float_t)
  ) align_addend_inst (
      .unpacked_c_i       (unpacked_c),
      .product_exp_i      (product_exp_o),
      .product_sign_i     (product_sign_o),
      .c_upper_slice_o    (c_upper_slice_o),
      .csa_c_o            (csa_c_o),
      .c_lower_sticky_o   (sum_float_flags_o.sticky_c),
      .c_dominates_o      (c_dominates),
      .ignore_round_even_o(sum_float_flags_o.ignore_round_even)
  );
  assign sum_float_flags_o.c_dominates = c_dominates || product_flags.zero;

endmodule
