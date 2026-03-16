module carry_save_row_adder #(
    parameter DATA_W = 16
) (
    input  logic [DATA_W-1:0] row_a,
    input  logic [DATA_W-1:0] row_b,
    input  logic [DATA_W-1:0] row_c,
    output logic [DATA_W-1:0] sum,
    output logic [DATA_W-1:0] carry
);
  assign sum   = row_a ^ row_b ^ row_c;
  assign carry = (row_a & row_b) | (row_b & row_c) | (row_a & row_c);

endmodule


