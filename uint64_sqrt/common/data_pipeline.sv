module data_pipeline #(
    parameter int                DATA_W     = 32,
    parameter int                PIPE_DEPTH = 1,
    parameter bit                RST_EN     = 1,
    parameter logic [DATA_W-1:0] RST_VAL    = '0,
    parameter bit                CLK_EN     = 0
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [PIPE_DEPTH-1:0] clk_en,
    input  logic [    DATA_W-1:0] data_i,
    output logic [    DATA_W-1:0] data_o
);

  generate
    if (PIPE_DEPTH >= 1) begin : gen_delay
      logic [DATA_W-1:0] data_shift_reg_d[PIPE_DEPTH];
      logic [DATA_W-1:0] data_shift_reg_q[PIPE_DEPTH];

      always_comb begin
        data_shift_reg_d[0] = data_i;

        for (int i = 1; i < PIPE_DEPTH; i++) begin
          data_shift_reg_d[i] = data_shift_reg_q[i-1];
        end
      end

      if (RST_EN) begin : gen_with_rst
        always_ff @(posedge clk or negedge rst_n) begin
          if (!rst_n) begin
            for (int i = 0; i < PIPE_DEPTH; i++) begin
              data_shift_reg_q[i] <= RST_VAL;
            end
          end else begin
            for (int i = 0; i < PIPE_DEPTH; i++) begin
              if (!CLK_EN || clk_en[i]) begin
                data_shift_reg_q[i] <= data_shift_reg_d[i];
              end
            end
          end
        end

      end else begin : gen_without_rst
        always_ff @(posedge clk) begin
          for (int i = 0; i < PIPE_DEPTH; i++) begin
            if (!CLK_EN || clk_en[i]) begin
              data_shift_reg_q[i] <= data_shift_reg_d[i];
            end
          end
        end
      end

      assign data_o = data_shift_reg_q[PIPE_DEPTH-1];
    end else begin : gen_no_delay
      assign data_o = data_i;
    end
  endgenerate

endmodule

