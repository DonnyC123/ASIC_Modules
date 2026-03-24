module leading_zero_counter #(
    parameter  DATA_W         = 8,
    localparam ZERO_COUNTER_W = $clog2(DATA_W)
) (
    input  logic [        DATA_W-1:0] data_i,
    output logic                      contains_one_o,
    output logic [ZERO_COUNTER_W-1:0] leading_zero_count_o
);

  // all_zero_above[k+1] = 1 iff data_i[DATA_W-1:k+1] are all zero (no 1 found above k).
  // first_one[k]        = 1 iff data_i[k] is the most-significant set bit.
  // Binary encoding via OR-only logic avoids an internal adder, which would otherwise
  // have truncated carry bits that block cross-module CSA optimization (CSAGEN-QOR).
  logic [DATA_W:0]            all_zero_above;
  logic [DATA_W-1:0]          first_one;

  always_comb begin
    all_zero_above[DATA_W] = 1'b1;
    for (int k = DATA_W - 1; k >= 0; k--) begin
      all_zero_above[k] = all_zero_above[k+1] & ~data_i[k];
    end

    for (int k = 0; k < DATA_W; k++) begin
      first_one[k] = data_i[k] & all_zero_above[k+1];
    end

    // One-hot (first_one) to binary: each output bit is the OR of first_one[k]
    // for all k where bit b of (DATA_W-1-k) is set — pure OR, no adder.
    leading_zero_count_o = '0;
    for (int b = 0; b < ZERO_COUNTER_W; b++) begin
      for (int k = 0; k < DATA_W; k++) begin
        if ((DATA_W - 1 - k) & (1 << b)) begin
          leading_zero_count_o[b] = leading_zero_count_o[b] | first_one[k];
        end
      end
    end
  end

  assign contains_one_o = |data_i;

endmodule

