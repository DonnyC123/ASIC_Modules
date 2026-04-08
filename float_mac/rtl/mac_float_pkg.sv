package mac_float_pkg;

  localparam CARRY_W              = 1;
  localparam SIGN_W               = 1;
  localparam MANTISSA_INT_W       = 1;
 
  typedef struct packed {
    logic sign;
    logic inf;
    logic nan;
    logic sticky_c;
    logic c_dominates;
    logic ignore_round_even;
  } sum_float_flags_t;

endpackage
