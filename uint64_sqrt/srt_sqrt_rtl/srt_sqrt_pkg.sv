package srt_sqrt_pkg;

  localparam SIGN_W  = 1;
  localparam RADIX   = 4;
  localparam RADIX_W = $clog2(RADIX);

  localparam INT_W             = 6;
  localparam SQ_INT_W          = INT_W * 2;
  localparam Q_IDX_W           = RADIX;
  localparam MAX_DIGIT         = RADIX / 2;
  localparam SUM_INT_W         = 2;
  localparam Q_DIGIT_W         = RADIX_W + SIGN_W;
  localparam CONST_TABLE_DEPTH = 2 ** Q_IDX_W;

  localparam ESTIMATE_CS_LSB = 61;

  localparam int REGISTERED_STEPS[3] = '{4, 14, 24};

  function automatic bit is_pipeline_stage(int idx);
    for (int j = 0; j < $size(REGISTERED_STEPS); j++) begin
      if (REGISTERED_STEPS[j] == idx) begin
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction


  parameter logic [4:0] LOWER_SEL_CONST_TABLE[CONST_TABLE_DEPTH] = '{
      4,
      4,
      4,
      5,
      5,
      5,
      6,
      6,
      6,
      6,
      7,
      7,
      7,
      7,
      8,
      8
  };

  parameter logic [5:0] UPPER_SEL_CONST_TABLE[CONST_TABLE_DEPTH] = '{
      12,
      13,
      14,
      15,
      15,
      16,
      17,
      18,
      18,
      19,
      20,
      20,
      21,
      22,
      23,
      24
  };

endpackage
