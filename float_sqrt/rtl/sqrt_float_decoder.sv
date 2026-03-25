module sqrt_float_decoder
  import sqrt_float_pkg::*;
#(
    parameter EXP_W         = 6,
    parameter FRAC_W        = 10,
    localparam MANTISSA_W   = FRAC_W + MANTISSA_INT_W,
    localparam SIGNED_EXP_W = EXP_W + 1,
    localparam type float_t = struct packed {
      logic sign;
      logic [EXP_W-1:0] exp;
      logic [FRAC_W-1:0] frac;
    }
) (
    input  float_t                          float_rad_i,
    output float_flags_t                    root_flags_o,
    output logic         [  MANTISSA_W-1:0] norm_mant_rad_o,
    output logic signed  [SIGNED_EXP_W-1:0] root_exp_o
);

  localparam SIGNED_EXP_ROUND_W = EXP_W + 2;
  localparam LZ_COUNTER_W       = $clog2(MANTISSA_W);
  localparam BIAS               = (1 << (EXP_W - 1)) - 1;

  logic                                  rad_frac_zero;
  logic                                  rad_exp_zero;
  logic                                  rad_exp_max;
  logic                                  root_exp_odd;

  logic signed  [      SIGNED_EXP_W-1:0] rad_exp;
  logic signed  [SIGNED_EXP_ROUND_W-1:0] root_exp_unrounded;
  logic         [      LZ_COUNTER_W-1:0] lz_rad;
  logic         [        MANTISSA_W-1:0] norm_mant_rad;

  float_flags_t                          root_flags;


  leading_zero_counter_top #(
      .DATA_W(FRAC_W)
  ) leading_zero_counter_a_top_inst (
      .data_i              (float_rad_i.frac),
      .leading_zero_count_o(lz_rad)
  );

  logic rad_denorm;

  always_comb begin
    rad_frac_zero   = float_rad_i.frac == '0;
    rad_exp_zero    = float_rad_i.exp == '0;
    rad_exp_max     = float_rad_i.exp == '1;

    root_flags.sign = float_rad_i.sign;
    root_flags.inf  = rad_exp_max && rad_frac_zero;
    root_flags.zero = rad_frac_zero && rad_exp_zero;
    root_flags.nan  = (rad_exp_max && !rad_frac_zero) || (!root_flags.zero && float_rad_i.sign);
  end

  always_comb begin
    rad_denorm = float_rad_i.exp == '0;

    if (rad_denorm) begin
      rad_exp       = -$signed({1'b0, lz_rad});
      norm_mant_rad = {1'b0, float_rad_i.frac << lz_rad, 1'b0};
      root_exp_odd  = !lz_rad[0];
    end else begin
      rad_exp       = $signed({1'b0, float_rad_i.exp});
      norm_mant_rad = {2'b01, float_rad_i.frac};
      root_exp_odd  = !float_rad_i.exp[0];
    end

    root_exp_unrounded = $signed(rad_exp) - BIAS + (BIAS * 2);
    root_exp_o         = root_exp_unrounded[SIGNED_EXP_ROUND_W-1:1];

    norm_mant_rad_o    = root_exp_odd ? norm_mant_rad << 1 : norm_mant_rad;
    root_flags_o       = root_flags;
  end

endmodule
