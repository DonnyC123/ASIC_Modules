module sqrt_float #(
    parameter  EXP_W  = 5,
    parameter  FRAC_W = 10,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              rad_valid_i,
    input  logic [DATA_W-1:0] rad_i,
    output logic [DATA_W-1:0] root_o,
    output logic              root_valid_o
);

  import sqrt_float_pkg::*;

  localparam GUARD_W         = 1;
  localparam SIGN_W          = 1;
  localparam MANTISSA_W      = FRAC_W + MANTISSA_INT_W;
  localparam ROOT_EXTENDED_W = FRAC_W + MANTISSA_INT_W;
  localparam SIGNED_EXP_W    = EXP_W + SIGN_W;

  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_t;

  float_t                             float_rad;
  float_t                             float_root;

  float_flags_t                       root_float_flags;

  logic         [     MANTISSA_W-1:0] norm_mant_rad;
  logic signed  [   SIGNED_EXP_W-1:0] root_exp_signed;

  logic         [ROOT_EXTENDED_W-1:0] root_extended;
  logic                               sticky_rem;

  assign float_rad = float_t'(rad_i);

  sqrt_float_decoder #(
      .EXP_W     (EXP_W),
      .MANTISSA_W(MANTISSA_W)
  ) sqrt_float_decoder_inst (
      .float_rad_i    (float_rad),
      .root_flags_o   (root_float_flags),
      .norm_mant_rad_o(norm_mant_rad),
      .root_exp_o     (root_exp_signed)
  );

  sqrt_mantissa #(
      .MANTISSA_W     (MANTISSA_W),
      .ROOT_EXTENDED_W(ROOT_EXTENDED_W)
  ) sqrt_mantissa_inst (
      .clk            (clk),
      .rst_n          (rst_n),
      .mantissa_rad_i (norm_mant_rad),
      .root_extended_o(root_extended),
      .sticky_rem_o   (sticky_rem)
  );

  root_rounder #(
      .FRAC_W         (FRAC_W),
      .EXP_W          (EXP_W),
      .SIGNED_EXP_W   (SIGNED_EXP_W),
      .ROOT_EXTENDED_W(ROOT_EXTENDED_W),
      .float_t        (float_t)
  ) root_rounder_inst (
      .float_root_flags_i(root_float_flags),
      .root_exp_i        (root_exp_signed),
      .root_raw_i        (root_extended),
      .sticky_i          (sticky_rem),
      .root_o            (float_root)
  );


  always_comb begin
    root_o       = float_root;
    root_valid_o = rad_valid_i;
  end

endmodule
