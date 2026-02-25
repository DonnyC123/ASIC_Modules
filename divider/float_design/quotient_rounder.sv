module quotient_rounder
  import divider_float_pkg::*;
#(
    parameter FRAC_W       = 10,
    parameter EXP_W        = 6,
    parameter SIGNED_EXP_W = 8,
    parameter type float_t = struct packed {
      logic sign;
      logic [EXP_W-1:0] exp;
      logic [FRAC_W-1:0] frac;
    },
    localparam MANTISSA_W     = FRAC_W + 1,
    localparam QUOTIENT_RAW_W = OFFSET_BIT_W + MANTISSA_W + GUARD_W
) (
    input  quotient_float_flags_t                      float_quotient_flags_i,
    input  logic signed           [  SIGNED_EXP_W-1:0] quotient_exp_i,
    input  logic                  [QUOTIENT_RAW_W-1:0] quotient_raw_i,
    input  logic                                       sticky_i,
    output float_t                                     quotient_o
);

  localparam QUOTIENT_EXTENDED_W = MANTISSA_W + GUARD_W;

  logic        [QUOTIENT_EXTENDED_W-1:0] quotient_extended;
  logic        [QUOTIENT_EXTENDED_W-1:0] quotient_unrounded;
  logic        [QUOTIENT_EXTENDED_W-1:0] quotient_rounded_raw;
  logic        [         MANTISSA_W-1:0] quotient_rounded;
  logic        [         MANTISSA_W-1:0] quotient_mantissa;


  logic signed [       SIGNED_EXP_W-1:0] quotient_exp_extended;
  logic signed [       SIGNED_EXP_W-1:0] quotient_exp_rounded;

  logic                                  quotient_exp_rounded_unfl;
  logic                                  quotient_exp_rounded_ovfl;

  logic                                  guard;
  logic                                  sticky;

  // Might be able to check if we will round and then do one add instead of
  // mutliple

  always_comb begin
    quotient_exp_extended = quotient_exp_i;
    quotient_extended     = quotient_raw_i[QUOTIENT_RAW_W-1:1];
    sticky                = sticky_i || quotient_raw_i[0];

    if (!quotient_raw_i[QUOTIENT_RAW_W-1]) begin
      quotient_exp_extended = quotient_exp_i - 1;
      quotient_extended     = quotient_raw_i[QUOTIENT_EXTENDED_W-1:0];
      sticky                = sticky_i;
    end

    guard = quotient_extended[0];
    quotient_unrounded = {1'b0, quotient_extended[QUOTIENT_EXTENDED_W-1:1]};
    quotient_rounded_raw   = guard && (sticky || quotient_unrounded[0]) ? quotient_unrounded + 1 : quotient_unrounded;

    quotient_rounded = quotient_rounded_raw[MANTISSA_W-1:0];
    quotient_exp_rounded = quotient_exp_extended;

    if (quotient_rounded_raw[QUOTIENT_EXTENDED_W-1]) begin
      quotient_rounded     = quotient_rounded_raw[QUOTIENT_EXTENDED_W-1:1];
      quotient_exp_rounded = quotient_exp_extended + 1;
    end


    quotient_exp_rounded_unfl = quotient_exp_rounded[SIGNED_EXP_W-1];
    quotient_exp_rounded_ovfl = |quotient_exp_rounded[SIGNED_EXP_W-2-:1];

    quotient_mantissa         = quotient_rounded;

    if (quotient_exp_rounded_unfl) begin
      quotient_mantissa = quotient_rounded >> -quotient_exp_rounded;
    end

  end

  always_comb begin
    quotient_o.sign = float_quotient_flags_i.sign;
    quotient_o.frac = quotient_mantissa[FRAC_W-1:0];
    quotient_o.exp  = quotient_exp_rounded[EXP_W-1:0];

    if (float_quotient_flags_i.nan) begin  // unique0?
      quotient_o.exp  = '1;
      quotient_o.frac = '1;
    end else if (float_quotient_flags_i.zero || quotient_exp_rounded_unfl) begin
      quotient_o.exp = '0;
      if (float_quotient_flags_i.zero) begin
        quotient_o.frac = '0;
      end
    end else if (float_quotient_flags_i.inf || quotient_exp_rounded_ovfl) begin
      quotient_o.exp  = '1;
      quotient_o.frac = '0;
    end
  end

endmodule

