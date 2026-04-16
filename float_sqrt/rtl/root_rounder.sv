module root_rounder
  import sqrt_float_pkg::*;
#(
    parameter FRAC_W          = 10,
    parameter EXP_W           = 5,
    parameter SIGNED_EXP_W    = 8,
    parameter ROOT_EXTENDED_W = 13,
    parameter type float_t    = struct packed {
      logic sign;
      logic [EXP_W-1:0] exp;
      logic [FRAC_W-1:0] frac;
    },
    localparam MANTISSA_W = FRAC_W + 1
) (
    input  float_flags_t                       float_root_flags_i,
    input  logic signed  [   SIGNED_EXP_W-1:0] root_exp_i,
    input  logic         [ROOT_EXTENDED_W-1:0] root_raw_i,
    input  logic                               sticky_i,
    output float_t                             root_o
);

  logic        [  ROOT_EXTENDED_W-1:0] root_normalized;
  logic        [       MANTISSA_W-1:0] root_unrounded;
  logic        [       MANTISSA_W-1:0] root_rounded_raw;

  logic        [           FRAC_W-1:0] root_frac;
  logic signed [     SIGNED_EXP_W-1:0] root_exp_rounded;

  logic                                guard;
  logic                                sticky;
  logic                                lsb;
  logic                                round_up;

  always_comb begin
    root_normalized  = root_raw_i;
    sticky           = sticky_i;

    guard            = root_normalized[0];
    lsb              = root_normalized[1];

    root_unrounded   = {1'b0, root_normalized[MANTISSA_W-1:1]};

    round_up         = guard && (sticky || lsb);
    root_rounded_raw = root_unrounded + round_up;

    if (root_rounded_raw[MANTISSA_W-1]) begin
      root_frac        = root_rounded_raw[MANTISSA_W-1:1];
      root_exp_rounded = root_exp_i + 1;
    end else begin
      root_frac        = root_rounded_raw[FRAC_W-1:0];
      root_exp_rounded = root_exp_i;
    end

  end

  always_comb begin
    root_o.sign = float_root_flags_i.sign;
    root_o.frac = root_frac;
    root_o.exp  = root_exp_rounded[EXP_W-1:0];

    if (float_root_flags_i.nan) begin
      root_o.exp  = '1;
      root_o.frac = {1'b1, {(FRAC_W - 1) {1'b0}}};
    end else if (float_root_flags_i.zero) begin
      root_o.exp  = '0;
      root_o.frac = '0;
    end else if (float_root_flags_i.inf || root_exp_rounded >= (1 << EXP_W) - 1) begin
      root_o.exp  = '1;
      root_o.frac = '0;
    end
  end
endmodule
