module sqrt_float_32_top #(
    localparam EXP_W  = 8,
    localparam FRAC_W = 23,
    localparam DATA_W = FRAC_W + EXP_W + 1
) (
    input  logic              clk,
    input  logic              clk_en,
    input  logic              rst_n,
    input  logic              rad_valid_i,
    input  logic [DATA_W-1:0] rad_i,
    output logic [DATA_W-1:0] root_o,
    output logic              root_valid_o
);

  sqrt_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) divider_float32_inst (
      .clk         (clk),
      .clk_en      (clk_en),
      .rst_n       (rst_n),
      .rad_valid_i (rad_valid_i),
      .rad_i       (rad_i),
      .root_o      (root_o),
      .root_valid_o(root_valid_o)
  );
endmodule
