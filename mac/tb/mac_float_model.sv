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
    longint mantisa;
  } unpacked_float_t;


  parameter BIAS        = (2 ** (EXP_W - 1)) - 1;
  parameter MANTISSA_W  = FRAC_W + 1;

  function automatic void unpack_float(input float_t float_i, output unpack_float_t unpacked_o);
    unpacked_o.mantisa = {1'b1, float_i.frac};
    unpacked_o.exp_o   = float_i.exp;
    unpacked_o.inf     = float_i.exp == '1;
    unpacked_o.sign    = float_i.sign;
 
    if (float_i.exp == '0) begin
      unpacked_o.mantisa[MANTISSA_W-1]  = 1'b0;
      unpacked_o.exp_o                  = 1'b1;
    end
  endfunction

  unpacked_float_t unpacked_a;
  unpacked_float_t unpacked_b;
  unpacked_float_t unpacked_c;

  always begin
    unpack_float(float_t'(a), unpacked_a);
    unpack_float(float_t'(b), unpacked_b);
    unpack_float(float_t'(c), unpacked_c);

    exp_product     = unpacked_a.exp + unpacked_a.exp - BIAS;
    mantisa_product = unpacked_a.mantisa * unpacked_b.mantisa;

    if (exp_product > unpacked_c.exp) begin


    end else 
    if (exp_product > unpacked_c.exp) begin

    end
  end
endmodule
