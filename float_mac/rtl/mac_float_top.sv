// This top mode is redundant
module mac_float_top #(
    localparam DATA_W = 16
) (
    input  logic              clk,
    input  logic [DATA_W-1:0] a,
    input  logic [DATA_W-1:0] b,
    input  logic [DATA_W-1:0] c,
    output logic [DATA_W-1:0] z

);
  mac_float mac_float_inst (
      .clk(clk),
      .a  (a),
      .b  (b),
      .c  (c),
      .z  (z)
  );

endmodule

