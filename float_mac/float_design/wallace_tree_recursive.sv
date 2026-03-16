module wallace_tree_recursive #(
    parameter DATA_W   = 16,
    parameter NUM_ROWS = 8
) (
    input  logic [DATA_W-1:0] partial_sums[NUM_ROWS],
    output logic [DATA_W-1:0] sum,
    output logic [DATA_W-1:0] carry
);

  localparam NUM_CSA_ROWS    = NUM_ROWS / 3;
  localparam LEFTOVER_ROWS   = NUM_ROWS % 3;
  localparam NEXT_STAGE_ROWS = (NUM_CSA_ROWS * 2) + LEFTOVER_ROWS;

  logic [DATA_W-1:0] partial_sums_next[NEXT_STAGE_ROWS];

  genvar row_idx;
  generate
    if (NUM_ROWS <= 2) begin : gen_tree_root
      assign sum   = partial_sums[0];
      assign carry = (NUM_ROWS == 2) ? partial_sums[1] : '0;

    end else begin : gen_recursive_tree
      for (row_idx = 0; row_idx < NUM_CSA_ROWS; row_idx++) begin : csa_rows
        logic [DATA_W-1:0] csa_sum;
        logic [DATA_W-1:0] csa_carry;

        carry_save_row_adder #(
            .DATA_W(DATA_W)
        ) carry_save_rows_inst (
            .row_a(partial_sums[row_idx*3]),
            .row_b(partial_sums[row_idx*3+1]),
            .row_c(partial_sums[row_idx*3+2]),
            .sum  (csa_sum),
            .carry(csa_carry)
        );

        assign partial_sums_next[row_idx*2]   = csa_sum;
        assign partial_sums_next[row_idx*2+1] = {csa_carry[DATA_W-2:0], 1'b0};
      end

      for (row_idx = 0; row_idx < LEFTOVER_ROWS; row_idx++) begin
        assign partial_sums_next[(NUM_CSA_ROWS*2)+row_idx] = partial_sums[(NUM_CSA_ROWS*3)+row_idx];
      end

      wallace_tree_recursive #(
          .DATA_W  (DATA_W),
          .NUM_ROWS(NEXT_STAGE_ROWS)
      ) next_wallance_tree_level (
          .partial_sums(partial_sums_next),
          .sum         (sum),
          .carry       (carry)
      );
    end

  endgenerate

endmodule


