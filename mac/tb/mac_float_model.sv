module mac_float_model #(
    parameter  EXP_W  = 5,
    parameter  FRAC_W = 10,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic [DATA_W-1:0] a,
    input  logic [DATA_W-1:0] b,
    input  logic [DATA_W-1:0] c,
    output logic [DATA_W-1:0] z
);
  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_t;

  typedef struct {
    bit inf;
    bit sign;
    longint exp;
    longint mantissa;
  } unpacked_float_t;

  localparam BIAS       = (2 ** (EXP_W - 1)) - 1;
  localparam MANTISSA_W = FRAC_W + 1;
  localparam GUARD_W    = 2;

  function automatic void unpack_float(input float_t float_i, output unpacked_float_t unpacked_o);
    unpacked_o.mantissa = longint'($unsigned({1'b1, float_i.frac}));
    unpacked_o.exp      = longint'($unsigned(float_i.exp));
    unpacked_o.inf      = float_i.exp == '1;
    unpacked_o.sign     = float_i.sign;

    if (float_i.exp == '0) begin
      unpacked_o.mantissa[MANTISSA_W-1] = 1'b0;
      unpacked_o.exp                    = 1; 
    end
  endfunction

  unpacked_float_t unpacked_a;
  unpacked_float_t unpacked_b;
  unpacked_float_t unpacked_c;
  unpacked_float_t unpacked_c_shifted;
  unpacked_float_t unpacked_product;
  unpacked_float_t unpacked_sum;
  
  longint exp_diff_product_shift;
  longint unpacked_sum_guarded;
  longint unpacked_sum_guarded_shifted;

  logic guard;
  logic sticky;
  logic lsb;

  always_comb begin
    unpack_float(float_t'(a), unpacked_a);
    unpack_float(float_t'(b), unpacked_b);
    unpack_float(float_t'(c), unpacked_c);

    unpacked_product.exp      = unpacked_a.exp + unpacked_b.exp - BIAS;
    unpacked_product.mantissa = (unpacked_a.mantissa * unpacked_b.mantissa);
    unpacked_product.sign     = unpacked_a.sign ^ unpacked_b.sign;
    unpacked_product.inf      = unpacked_a.inf || unpacked_b.inf;

    exp_diff_product_shift    = unpacked_c.exp - unpacked_product.exp + MANTISSA_W + GUARD_W;
    unpacked_c_shifted        = '{default:0};

    if (exp_diff_product_shift > 2*FRAC_W + GUARD_W) begin
       unpacked_sum = unpacked_c;
    end
    else if (exp_diff_product_shift < 0) begin
       unpacked_sum = unpacked_product;
    end
    else begin

      unpacked_c_shifted.mantissa = unpacked_c.mantissa << exp_diff_product_shift;
      unpacked_product.mantissa   = unpacked_product.mantissa << GUARD_W;

      unpacked_c_shifted.exp      = unpacked_product.exp;
      unpacked_c_shifted.sign     = unpacked_c.sign;
      unpacked_c_shifted.inf      = unpacked_c.inf;

      unpacked_sum.exp = unpacked_product.exp;

      if (unpacked_c_shifted.sign == unpacked_product.sign) begin
        unpacked_sum.sign     = unpacked_c_shifted.sign;
        unpacked_sum_guarded  = unpacked_c_shifted.mantissa + unpacked_product.mantissa;
      end else begin
        if(unpacked_c_shifted.mantissa > unpacked_product.mantissa) begin
          unpacked_sum.sign    = unpacked_c_shifted.sign;
          unpacked_sum_guarded = unpacked_c_shifted.mantissa - unpacked_product.mantissa;
        end else begin
          unpacked_sum.sign    = unpacked_product.sign;
          unpacked_sum_guarded = unpacked_product.mantissa - unpacked_c_shifted.mantissa;
        end
      end
    end
  
    unpacked_sum_guarded_shifted = unpacked_sum_guarded;
    if (unpacked_sum_guarded == 0) begin
        unpacked_sum.mantissa = 0;
        unpacked_sum.exp      = -BIAS;
    end 
    else begin
        if (unpacked_sum_guarded[FRAC_W + GUARD_W + 1]) begin
            unpacked_sum_guarded >>= 1;
            unpacked_sum.exp++;
        end 
        else begin
            while (unpacked_sum_guarded[FRAC_W + GUARD_W] == 0) begin
                unpacked_sum_guarded <<= 1;
                unpacked_sum.exp--;
            end
        end


        guard  = unpacked_sum_guarded[GUARD_W - 1];
        sticky = |unpacked_sum_guarded[GUARD_W - 2 : 0];
        lsb    = unpacked_sum_guarded[GUARD_W];

        unpacked_sum.mantissa = unpacked_sum_guarded >> GUARD_W;

        if (guard && (sticky || lsb)) begin
            unpacked_sum.mantissa++;

            if (unpacked_sum.mantissa[FRAC_W + 1]) begin 
                unpacked_sum.mantissa >>= 1;
                unpacked_sum.exp++;
            end
        end
    end

    if (unpacked_sum.mantissa == 0) z = '0;
    else begin
        z[DATA_W-1]        = unpacked_sum.sign;
        z[DATA_W-2:FRAC_W] = unpacked_sum.exp[EXP_W-1:0];
        z[FRAC_W-1:0]      = unpacked_sum.mantissa[FRAC_W-1:0];
    end
  end
endmodule
