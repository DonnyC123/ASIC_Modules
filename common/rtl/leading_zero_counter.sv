module leading_zero_counter #(
    parameter  DATA_W         = 8,
    localparam ZERO_COUNTER_W = $clog2(DATA_W)
) (
    input  logic [        DATA_W-1:0] data_i,
    output logic                      contains_one_o,
    output logic [ZERO_COUNTER_W-1:0] leading_zero_count_o
);

  logic [ZERO_COUNTER_W-1:0] leading_zero_count;
  logic                      found_one;

  always_comb begin
    leading_zero_count = '0;
    found_one          = 1'b0;

    for (int idx = DATA_W - 1; idx >= 0; idx--) begin
      if (!found_one && data_i[idx]) begin
        leading_zero_count = ZERO_COUNTER_W'(DATA_W - 1 - idx);
        found_one          = 1'b1;
      end
    end
  end

  assign contains_one_o       = found_one;
  assign leading_zero_count_o = leading_zero_count;

endmodule

