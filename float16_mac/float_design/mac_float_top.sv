
module mac_float_top #(
    localparam DATA_W = 16
) (
    input  logic              clk,
    input  logic [DATA_W-1:0] a,
    input  logic [DATA_W-1:0] b,
    input  logic [DATA_W-1:0] c,
    output logic [DATA_W-1:0] z

);
  logic [DATA_W-1:0] a_ff;
  logic [DATA_W-1:0] b_ff;
  logic [DATA_W-1:0] c_ff;


  always_ff @(posedge clk) begin
    a_ff <= a;
    b_ff <= b;
    c_ff <= c;

  end

  mac_float mac_float_inst (
      .clk(clk),
      .a  (a_ff),
      .b  (b_ff),
      .c  (c_ff),
      .z  (z)
  );

endmodule

