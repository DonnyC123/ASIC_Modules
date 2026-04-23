module data_status_pipeline #(
    parameter int DATA_W     = 32,
    parameter int STATUS_W   = 1,
    parameter int PIPE_DEPTH = 1,
    parameter bit CLK_EN     = 0
) (
    input  logic                clk,
    input  logic                clk_en,
    input  logic                rst_n,
    input  logic [  DATA_W-1:0] data_i,
    input  logic [STATUS_W-1:0] status_i,
    output logic [  DATA_W-1:0] data_o,
    output logic [STATUS_W-1:0] status_o
);

  generate
    if (!CLK_EN || PIPE_DEPTH == 0) begin : gen_no_clk_gate
      data_pipeline #(
          .DATA_W    (STATUS_W),
          .PIPE_DEPTH(PIPE_DEPTH),
          .RST_EN    (1),
          .CLK_EN    (0)
      ) status_pipeline_inst (
          .clk   (clk),
          .clk_en('0),
          .rst_n (rst_n),
          .data_i(status_i),
          .data_o(status_o)
      );

      data_pipeline #(
          .DATA_W    (DATA_W),
          .PIPE_DEPTH(PIPE_DEPTH),
          .RST_EN    (1),
          .CLK_EN    (0)
      ) data_pipeline_inst (
          .clk   (clk),
          .clk_en('0),
          .rst_n (rst_n),
          .data_i(data_i),
          .data_o(data_o)
      );

    end else begin : gen_clk_gate
      data_pipeline #(
          .DATA_W    (STATUS_W),
          .PIPE_DEPTH(PIPE_DEPTH),
          .RST_EN    (1),
          .CLK_EN    (1)
      ) status_pipeline_inst (
          .clk   (clk),
          .clk_en(clk_en),
          .rst_n (rst_n),
          .data_i(status_i),
          .data_o(status_o)
      );

      data_pipeline #(
          .DATA_W    (DATA_W),
          .PIPE_DEPTH(PIPE_DEPTH),
          .RST_EN    (1),
          .CLK_EN    (1)
      ) data_pipeline_inst (
          .clk   (clk),
          .clk_en(clk_en),
          .rst_n (rst_n),
          .data_i(data_i),
          .data_o(data_o)
      );

    end
  endgenerate
endmodule

