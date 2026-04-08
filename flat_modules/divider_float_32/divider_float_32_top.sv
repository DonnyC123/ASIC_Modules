module divider_float_32_top #(
    localparam EXP_W  = 8,
    localparam FRAC_W = 23,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic              clk,
    input  logic              clk_en,
    input  logic              rst_n,
    input  logic              start_i,
    input  logic [DATA_W-1:0] a,
    input  logic [DATA_W-1:0] b,
    output logic [DATA_W-1:0] z,
    output logic              z_valid
);

  divider_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) divider_float32_inst (
      .clk    (clk),
      .clk_en (clk_en),
      .rst_n  (rst_n),
      .start_i(start_i),
      .a      (a),
      .b      (b),
      .z      (z),
      .z_valid(z_valid)
  );
endmodule
