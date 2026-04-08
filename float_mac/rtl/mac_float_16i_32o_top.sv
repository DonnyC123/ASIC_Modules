module mac_float_16i_32o_top #(
    localparam EXP_IN_W   = 5,
    localparam FRAC_IN_W  = 10,
    localparam EXP_OUT_W  = 8,
    localparam FRAC_OUT_W = 23,
    localparam DIN_W      = FRAC_IN_W + EXP_IN_W + 1,
    localparam DOUT_W     = FRAC_OUT_W + EXP_OUT_W + 1
) (
    input  logic              clk,
    input  logic              clk_en,
    input  logic              rst_n,
    input  logic              valid_i,
    input  logic [ DIN_W-1:0] a,
    input  logic [ DIN_W-1:0] b,
    input  logic [ DIN_W-1:0] c,
    output logic              valid_o,
    output logic [DOUT_W-1:0] z
);


  mac_float_mixed #(
      .EXP_IN_W  (EXP_IN_W),
      .FRAC_IN_W (FRAC_IN_W),
      .EXP_OUT_W (EXP_OUT_W),
      .FRAC_OUT_W(FRAC_OUT_W)
  ) mac_float_mixed_inst (
      .clk    (clk),
      .clk_en (clk_en),
      .rst_n  (rst_n),
      .valid_i(valid_i),
      .a      (a),
      .b      (b),
      .c      (c),
      .valid_o(valid_o),
      .z      (z)
  );
endmodule
