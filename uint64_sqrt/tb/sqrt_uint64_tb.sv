module sqrt_tb ();
  localparam int DIN_W           = 64;
  localparam int DOUT_W          = DIN_W / 2;
  localparam int PIPELINE_STAGES = 4;
  localparam int P_VALID         = 30;
  localparam int NUM_TESTS       = 10000000;


  logic              clk;
  logic              rst_n;
  logic [ DIN_W-1:0] rad_i;
  logic              valid_i;
  logic [DOUT_W-1:0] root_restoring_o;
  logic              valid_restoring_o;

  int                items_received;
  int                items_sent;
  int                over_by_1_bit;
  int                under_by_1_bit;

  int                over_by_2_bit;
  int                under_by_2_bit;

  logic [ DIN_W-1:0] full_rand_val;

  logic [ DIN_W-1:0] input_sent_queue  [$];

  sqrt_non_restoring_rtl #(
      .DIN_W(DIN_W)
  ) sqrt_restoring_dut (
      .clk    (clk),
      .rst_n  (rst_n),
      .rad_i  (rad_i),
      .valid_i(valid_i),
      .root_o (root_restoring_o),
      .valid_o(valid_restoring_o)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  function automatic logic [31:0] exact_int_sqrt(input logic [63:0] val);
    logic [63:0] res = 0;
    logic [63:0] bit_val = 64'h4000000000000000;

    while (bit_val > 0) begin
      if (val >= res + bit_val) begin
        val = val - (res + bit_val);
        res = (res >> 1) + bit_val;
      end else begin
        res = res >> 1;
      end
      bit_val = bit_val >> 2;
    end
    return res[31:0];
  endfunction

  initial begin
    rst_n   = 0;
    valid_i = 0;
    rad_i   = '0;

    @(posedge clk);
    @(posedge clk);
    rst_n = 1;

    @(posedge clk);

    full_rand_val = 64'd10099058102597323805;

    @(posedge clk);
    valid_i <= 1'b1;
    rad_i   <= full_rand_val;
    input_sent_queue.push_back(full_rand_val);
    items_sent++;

    @(posedge clk);

    valid_i <= 1'b0;

    @(posedge clk);
    full_rand_val = 64'd9293152565177159026;

    @(posedge clk);
    valid_i <= 1'b1;
    rad_i   <= full_rand_val;
    input_sent_queue.push_back(full_rand_val);

    @(posedge clk);
    valid_i <= 1'b0;

    @(posedge clk);

    full_rand_val = 64'd5180299141684771318;

    @(posedge clk);
    valid_i <= 1'b1;
    rad_i   <= full_rand_val;
    input_sent_queue.push_back(full_rand_val);
    items_sent++;

    @(posedge clk);
    valid_i <= 1'b0;

    items_sent++;


    @(posedge clk);
    valid_i <= 1'b0;
    @(posedge clk);
    while (items_sent < 1000) begin
      @(posedge clk);

      if ($urandom_range(0, 99) < P_VALID) begin
        automatic logic [DIN_W-1:0] rand_val = items_sent;

        valid_i <= 1'b1;
        rad_i   <= rand_val;

        input_sent_queue.push_back(rand_val);
        items_sent++;
      end else begin
        valid_i <= 1'b0;
        rad_i   <= 'x;
      end
    end

    @(posedge clk);

    valid_i <= 1'b0;
    rad_i   <= 'x;

    while (items_sent < NUM_TESTS) begin
      @(posedge clk);

      if ($urandom_range(0, 99) < P_VALID) begin
        assert (std::randomize(full_rand_val));

        valid_i <= 1'b1;
        rad_i   <= full_rand_val;

        input_sent_queue.push_back(full_rand_val);
        items_sent++;
      end else begin
        valid_i <= 1'b0;
        rad_i   <= 'x;
      end
    end


  end

  always @(posedge clk) begin
    if (rst_n && valid_restoring_o) begin
      automatic logic   [ DIN_W-1:0] input_data = input_sent_queue.pop_front();
      automatic logic   [DOUT_W-1:0] expected_out = exact_int_sqrt(input_data);
      automatic longint              diff = longint'(root_restoring_o) - longint'(expected_out);

      if (diff != 0) begin
        if (diff > 2 || diff < -2) begin
          $error("Test Failed, Input: %0d, Expected: %0d,  Actual: %0d", input_data, expected_out,
                 root_restoring_o);
          $finish;
        end else begin
          $display("Small difference, Input: %0d, Expected: %0d,  Actual: %0d", input_data,
                   expected_out, root_restoring_o);
          $finish;
          if (diff >= 1) begin
            if (diff >= 2) begin
              over_by_2_bit += 1;
            end else begin
              over_by_1_bit += 1;
            end
          end else if (diff <= -1) begin
            if (diff <= -2) begin
              under_by_2_bit += 1;
            end else begin
              under_by_1_bit += 1;
            end
          end
        end

      end
      if (items_received % 10000 == 0) begin
        $display(
            "Update: Over1 %0d, Over2 %0d, Under1 %0d, Under2 %0d, Passed %0d/%0d. Last Input %0d, Last Actual Output %0d,",
            over_by_1_bit, over_by_2_bit, under_by_1_bit, under_by_2_bit, items_received,
            NUM_TESTS, input_data, expected_out);
      end

      items_received++;
      if (items_received == NUM_TESTS) begin
        $display("SUCCESS: All %0d tests passed", NUM_TESTS);
        $finish;
      end
    end
  end
endmodule
