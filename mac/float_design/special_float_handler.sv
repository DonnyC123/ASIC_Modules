
module special_float_handler #(
    parameter type float_t = struct packed {
      logic sign;
      logic [5:0] exp;
      logic [9:0] frac;
    }
) (
    input  float_t float_a_i,
    input  float_t float_b_i,
    input  float_t float_c_i,
    output logic   inf_o,
    output logic   inf_sign_o,
    output logic   nan_o
);


  typedef struct {
    logic sign;
    logic inf;
    logic nan;
    logic zero;
  } float_flags_t;


  function automatic float_flags_t deduce_float_flags(input float_t float_i);
    float_flags_t flags_o;
    logic exp_max;
    logic frac_zero;
    logic exp_zero;

    exp_max       = float_i.exp == '1;
    exp_zero      = float_i.exp == '0;
    frac_zero     = float_i.frac == '0;

    flags_o.inf   = exp_max && frac_zero;
    flags_o.nan   = exp_max && !frac_zero;
    flags_o.zero  = exp_zero && frac_zero;
    flags_o.sign  = float_i.sign;

    return flags_o;
  endfunction

   float_flags_t a_flags;
   float_flags_t b_flags;
   float_flags_t c_flags;

   float_flags_t product_flags;
   float_flags_t sum_flags;


  always_comb begin
    a_flags = deduce_float_flags(float_a_i);
    b_flags = deduce_float_flags(float_b_i);
    c_flags = deduce_float_flags(float_c_i);

    product_flags.zero = a_flags.zero || b_flags.zero;
    product_flags.inf  = a_flags.inf || b_flags.inf;
    product_flags.nan  = (a_flags.zero && b_flags.inf) || (a_flags.inf && b_flags.zero);
    product_flags.sign = a_flags.sign ^ b_flags.sign;
 
    sum_flags.zero = product_flags.zero && c_flags.zero;
    sum_flags.inf  = (product_flags.inf && c_flags.inf && (product_flags.sign == c_flags.sign))
                   ||product_flags.inf ^ c_flags.inf;

    sum_flags.nan  = product_flags.inf && c_flags.inf && (product_flags.sign != c_flags.sign);
    sum_flags.sign = product_flags.inf ? product_flags.sign : c_flags.sign;
 
    inf_o      = '0;
    inf_sign_o = '0;
    nan_o      = '0; 


    if (a_flags.nan || b_flags.nan || c_flags.nan || product_flags.nan || sum_flags.nan) begin
      nan_o      = 1'b1;
    end else begin
      inf_o      = sum_flags.inf;
      inf_sign_o = sum_flags.sign;
    end
  end

endmodule
