// Counts the number of zero bits before encountering a one bit, 
// moving from msb to lsb

module leading_zero_counter #(
    parameter DATA_W  = 22,
    parameter COUNT_W = $clog2(DATA_W + 1)
) (
  input  wire [       21:0] data_i,
  output wire [COUNT_W-1:0] leading_zero_count_o
);

  integer               i;
  reg                   found;
  reg     [COUNT_W-1:0] leading_zero_count;

  always @(*) begin
    leading_zero_count = 0;
    found              = 1'b0;
    for (i = DATA_W - 1; i >= 0; i = i - 1) begin
      if (!found && data_i[i]) begin
        found = 1'b1;
      end

      if (!found) begin
        leading_zero_count = leading_zero_count + 1'b1;
      end
    end
  end

  assign leading_zero_count_o = leading_zero_count;

endmodule
