// Parallel-prefix (binary-tree) leading-zero counter.
// Replaces the linear block-chain implementation.
// LZC_DATA_BLOCK_W kept in the port list for interface compatibility but unused.
module leading_zero_counter_top #(
    parameter  DATA_W           = 29,
    parameter  LZC_DATA_BLOCK_W = 4,
    localparam LZ_COUNT_W       = $clog2(DATA_W + 1)
) (
    input  logic [    DATA_W-1:0] data_i,
    output logic [LZ_COUNT_W-1:0] leading_zero_count_o
);

  // Round up to next power-of-2 so every level halves cleanly.
  localparam PAD_W  = (DATA_W > 1) ? (1 << $clog2(DATA_W)) : 2;
  localparam LEVELS = $clog2(PAD_W);

  // Each tree node stores {has_one, lz_count}.
  // Level 0 = leaves (one per padded bit, MSB first).
  // Level LEVELS = root (index 0 only).
  logic [PAD_W-1:0]      node_has_one [LEVELS+1];
  logic [LZ_COUNT_W-1:0] node_lz      [LEVELS+1][PAD_W];

  genvar l, i;
  generate
    // -----------------------------------------------------------------------
    // Leaves
    // -----------------------------------------------------------------------
    for (i = 0; i < PAD_W; i++) begin : g_leaf
      if (i < DATA_W) begin
        // index 0 = MSB of data_i
        assign node_has_one[0][i] = data_i[DATA_W-1-i];
        assign node_lz[0][i]      = node_has_one[0][i] ? '0 : LZ_COUNT_W'(1);
      end else begin
        // Padding: sentinel "1" so it does not inflate the zero count.
        assign node_has_one[0][i] = 1'b1;
        assign node_lz[0][i]      = '0;
      end
    end

    // -----------------------------------------------------------------------
    // Internal levels
    // -----------------------------------------------------------------------
    for (l = 0; l < LEVELS; l++) begin : g_level
      for (i = 0; i < PAD_W >> (l + 1); i++) begin : g_node
        // Left child = 2*i (MSB side), right child = 2*i+1
        assign node_has_one[l+1][i] = node_has_one[l][2*i] | node_has_one[l][2*i+1];
        assign node_lz[l+1][i]      = node_has_one[l][2*i] ?
                                        node_lz[l][2*i] :
                                        node_lz[l][2*i] + node_lz[l][2*i+1];
      end
    end
  endgenerate

  assign leading_zero_count_o = node_lz[LEVELS][0];

endmodule
