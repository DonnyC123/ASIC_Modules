module mac_float_16_top #(
    localparam EXP_W  = 5,
    localparam FRAC_W = 10,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic              clk,
    input  logic              clk_en,
    input  logic              rst_n,
    input  logic              valid_i,
    input  logic [DATA_W-1:0] a,
    input  logic [DATA_W-1:0] b,
    input  logic [DATA_W-1:0] c,
    output logic              valid_o,
    output logic [DATA_W-1:0] z
);

  mac_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) mac_float_inst (
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
