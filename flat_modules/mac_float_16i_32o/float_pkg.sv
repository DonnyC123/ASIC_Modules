package float_pkg;

  localparam EXP_16_W  = 5;
  localparam FRAC_16_W = 10;
  localparam EXP_32_W  = 8;
  localparam FRAC_32_W = 23;

  typedef struct packed {
    logic sign;
    logic [EXP_16_W-1:0] exp;
    logic [FRAC_16_W-1:0] frac;
  } float_16_t;

  typedef struct packed {
    logic sign;
    logic [EXP_32_W-1:0] exp;
    logic [FRAC_32_W-1:0] frac;
  } float_32_t;

endpackage

