module data_status_pipeline #(
    parameter int DATA_W     = 32,
    parameter int STATUS_W   = 1,
    parameter int PIPE_DEPTH = 1,
    parameter bit CLOCK_GATE = 0
) (
    input  logic                clk,
    input  logic                rst_n,
    input  logic [  DATA_W-1:0] data_i,
    input  logic [STATUS_W-1:0] status_i,
    output logic [  DATA_W-1:0] data_o,
    output logic [STATUS_W-1:0] status_o
);

  generate
    if (!CLOCK_GATE || PIPE_DEPTH == 0) begin : gen_no_clk_gate
      data_pipeline #(
          .DATA_W    (STATUS_W),
          .PIPE_DEPTH(PIPE_DEPTH),
          .RST_EN    (1),
          .CLK_EN    (0)
      ) status_pipeline_inst (
          .clk   (clk),
          .rst_n (rst_n),
          .clk_en('0),
          .data_i(status_i),
          .data_o(status_o)
      );

      data_pipeline #(
          .DATA_W    (DATA_W),
          .PIPE_DEPTH(PIPE_DEPTH),
          .RST_EN    (0),
          .CLK_EN    (0)
      ) data_pipeline_inst (
          .clk   (clk),
          .rst_n (rst_n),
          .clk_en('0),
          .data_i(data_i),
          .data_o(data_o)
      );

    end else begin : gen_clk_gate
      logic [PIPE_DEPTH-1:0] clk_en;
      logic [  STATUS_W-1:0] status [PIPE_DEPTH];

      always_comb begin
        clk_en[0] = |status_i;
        for (int i = 1; i < PIPE_DEPTH; i++) begin
          clk_en[i] = |status[i-1];
        end
      end

      shift_reg #(
          .DATA_W    (STATUS_W),
          .PIPE_DEPTH(PIPE_DEPTH),
          .RST_EN    (1),
          .RST_VAL   ('0)
      ) status_pipeline_inst_reg (
          .clk   (clk),
          .rst_n (rst_n),
          .data_i(status_i),
          .data_o(status)
      );

      assign status_o = status[PIPE_DEPTH-1];

      data_pipeline #(
          .DATA_W    (DATA_W),
          .PIPE_DEPTH(PIPE_DEPTH),
          .RST_EN    (0),
          .CLK_EN    (1)
      ) data_pipeline_inst (
          .clk   (clk),
          .rst_n (rst_n),
          .clk_en(clk_en),
          .data_i(data_i),
          .data_o(data_o)
      );

    end
  endgenerate
endmodule

