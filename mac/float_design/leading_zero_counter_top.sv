module leading_zero_counter_top #(
    parameter  DATA_W           = 29,
    parameter  LZC_DATA_BLOCK_W = 4,
    localparam LZ_COUNT_W       = $clog2(DATA_W + 1)
) (
    input  logic [    DATA_W-1:0] data_i,
    output logic [LZ_COUNT_W-1:0] leading_zero_count_o
);

  localparam NUM_LZC_UNITS         = (DATA_W + LZC_DATA_BLOCK_W - 1) / LZC_DATA_BLOCK_W;
  localparam LAST_LZC_DATA_BLOCK_W = DATA_W - LZC_DATA_BLOCK_W * (NUM_LZC_UNITS - 1);
  localparam BLOCK_LZ_COUNT_W      = $clog2(LZC_DATA_BLOCK_W);
  localparam LAST_BLOCK_LZ_COUNT_W = $clog2(LAST_LZC_DATA_BLOCK_W);
  localparam UPPER_LZ_COUNT_W      = LZ_COUNT_W - BLOCK_LZ_COUNT_W;

  generate
    if (NUM_LZC_UNITS < 2) begin : min_lzc_check
      $error(
          "Config Error: Module expects NUM_LZC_UNITS to be >= 2. Current value: %0d", NUM_LZC_UNITS
      );
    end
    if (1 << $clog2(LZC_DATA_BLOCK_W) != LZC_DATA_BLOCK_W) begin : power_2_lzc_check
      $error(
          "Config Error: Module expects LZC_DATA_BLOCK_W to be a power of 2. Current value: %0d",
          LZC_DATA_BLOCK_W
      );
    end
  endgenerate

  logic [   NUM_LZC_UNITS-1:0] block_contains_one;
  logic [BLOCK_LZ_COUNT_W-1:0] block_lz_count     [NUM_LZC_UNITS];
  logic [UPPER_LZ_COUNT_W-1:0] upper_lz_count;
  logic [UPPER_LZ_COUNT_W-1:0] lower_lz_idx;

  genvar data_idx;
  generate
    for (data_idx = 0; data_idx < (NUM_LZC_UNITS - 1); data_idx++) begin
      leading_zero_counter #(
          .DATA_W(LZC_DATA_BLOCK_W)
      ) leading_zero_counter_inst (
          .data_i              (data_i[DATA_W-1-data_idx*LZC_DATA_BLOCK_W-:LZC_DATA_BLOCK_W]),
          .contains_one_o      (block_contains_one[data_idx]),
          .leading_zero_count_o(block_lz_count[data_idx])
      );
    end

    leading_zero_counter #(
        .DATA_W(LAST_LZC_DATA_BLOCK_W)
    ) leading_zero_counter_inst_last (
        .data_i              (data_i[LAST_LZC_DATA_BLOCK_W-1:0]),
        .contains_one_o      (block_contains_one[NUM_LZC_UNITS-1]),
        .leading_zero_count_o(block_lz_count[NUM_LZC_UNITS-1][LAST_BLOCK_LZ_COUNT_W-1:0])
    );
    assign block_lz_count[NUM_LZC_UNITS-1][BLOCK_LZ_COUNT_W-1:LAST_BLOCK_LZ_COUNT_W] = '0;
  endgenerate

  leading_zero_counter #(
      .DATA_W(NUM_LZC_UNITS)
  ) leading_zero_counter_block_contains_one (
      .data_i              (block_contains_one),
      .contains_one_o      (),
      .leading_zero_count_o(upper_lz_count)
  );

  always_comb begin
    lower_lz_idx                                        = upper_lz_count;
    leading_zero_count_o[BLOCK_LZ_COUNT_W-1:0]          = block_lz_count[lower_lz_idx];
    leading_zero_count_o[LZ_COUNT_W-1:BLOCK_LZ_COUNT_W] = upper_lz_count;
  end

endmodule
