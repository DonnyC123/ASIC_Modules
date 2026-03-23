package divider_float_pkg;

  localparam NUM_MANTISSA_DIV_STATES = 3;
  localparam GUARD_W                 = 1;
  localparam ROUND_W                 = 1;
  localparam SIGN_W                  = 1;
  localparam CARRY_W                 = 1;
  localparam OFFSET_BIT_W            = 1;
  localparam RADIX                   = 4;
  localparam FLOAT_FLAGS_W           = 4;
  localparam REDUCTION_FACTOR        = $clog2(RADIX);
  localparam REDUCTION_W             = REDUCTION_FACTOR;
  localparam QUOTIENT_DIGIT_W        = REDUCTION_FACTOR + SIGN_W;

  localparam GUARD_IDX = 1;
  localparam ROUND_IDX = 1;
  
  typedef enum logic [NUM_MANTISSA_DIV_STATES-1:0] {
    IDLE   = 3'b001,
    ACTIVE = 3'b010,
    DONE   = 3'b100
  } mantissa_divider_state_t;
 
  typedef struct packed {
    logic sign;
    logic inf;
    logic nan;
    logic zero;
  } quotient_float_flags_t;
 

endpackage
