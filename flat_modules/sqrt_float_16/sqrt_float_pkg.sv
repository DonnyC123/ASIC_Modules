package sqrt_float_pkg;
  localparam MANTISSA_INT_W  = 2;
  localparam CARRY_W         = 1;
  localparam SIGN_W          = 1;
  localparam GUARD_W         = 1;
  localparam FLOAT_FLAGS_W   = 4;

typedef struct packed {
  logic sign;
  logic inf;
  logic nan;
  logic zero;
} float_flags_t;



endpackage
