module upscale_float #(
    parameter EXP_IN_W         = 5,
    parameter FRAC_IN_W        = 10,
    parameter EXP_OUT_W        = 8,
    parameter FRAC_OUT_W       = 23,
    localparam type float_in_t = struct packed {
      logic sign;
      logic [EXP_IN_W-1:0] exp;
      logic [FRAC_IN_W-1:0] frac;
    },
    localparam type float_out_t = struct packed {
      logic sign;
      logic [EXP_OUT_W-1:0] exp;
      logic [FRAC_OUT_W-1:0] frac;
    }
) (
    input  float_in_t  float_i,
    output float_out_t float_o
);

  localparam LZ_COUNTER_W = $clog2(FRAC_IN_W);

  localparam BIAS_IN  = (1 << (EXP_IN_W - 1)) - 1;
  localparam BIAS_OUT = (1 << (EXP_OUT_W - 1)) - 1;

  logic [LZ_COUNTER_W-1:0] lz_c;

  leading_zero_counter_top #(
      .DATA_W(FRAC_IN_W)
  ) leading_zero_counter_b_top_inst (
      .data_i              (float_i.frac),
      .leading_zero_count_o(lz_c)
  );

  always_comb begin
    float_o.sign = float_i.sign;
    float_o.exp = {{EXP_OUT_W - EXP_IN_W{1'b0}}, float_i.exp} +
        EXP_OUT_W'($unsigned(BIAS_OUT - BIAS_IN));
    float_o.frac = {{FRAC_OUT_W - FRAC_IN_W{1'b0}}, float_i.frac} << (FRAC_OUT_W - FRAC_IN_W);

    if (float_i.exp == '0) begin
      // Might be able to delete this line
      float_o.exp = {{EXP_OUT_W - EXP_IN_W{1'b0}}, float_i.exp} +
          EXP_OUT_W'($unsigned(BIAS_OUT - BIAS_IN)) + {{EXP_OUT_W - LZ_COUNTER_W{1'b0}}, lz_c};
      if (float_o.frac == '0) begin
        float_o.exp  = '0;
        float_o.frac = '0;
      end
    end
  end

endmodule
