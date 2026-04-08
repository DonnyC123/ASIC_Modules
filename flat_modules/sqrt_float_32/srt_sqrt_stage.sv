module srt_sqrt_stage
  import srt_sqrt_pkg::*;
#(
    parameter int DATA_W    = 72,
    parameter int FRAC_BITS = 66,
    parameter int RAD_W     = 64,
    parameter int STAGE     = 3,
    parameter bit USE_ADDER = 0
) (
    input  logic signed [DATA_W-1:0] rem_sum_i,
    input  logic signed [DATA_W-1:0] rem_carry_i,
    input  logic signed [DATA_W-1:0] root_q_i,
    input  logic signed [DATA_W-1:0] root_qm_i,
    output logic signed [DATA_W-1:0] rem_carry_o,
    output logic signed [DATA_W-1:0] rem_sum_o,
    output logic signed [DATA_W-1:0] root_q_o,
    output logic signed [DATA_W-1:0] root_qm_o
);

  localparam STEP_BIT    = FRAC_BITS - 2 * STAGE;
  localparam ROOT_IDX_W  = Q_IDX_W + 2;

  logic signed [   DATA_W-1:0] rem_sum_shift;
  logic signed [   DATA_W-1:0] rem_carry_shift;
  logic signed [Q_DIGIT_W-1:0] q_digit;
  logic        [  Q_IDX_W-1:0] q_idx;

  logic        [ROOT_IDX_W-1:0] raw_q_idx;
  logic signed [    DATA_W-1:0] two_root_q;
  logic signed [    DATA_W-1:0] q_sq_term;
  logic signed [    DATA_W-1:0] neg_sub;

  assign rem_sum_shift   = rem_sum_i << RADIX_W;
  assign rem_carry_shift = rem_carry_i << RADIX_W;
  assign raw_q_idx       = root_q_i[FRAC_BITS-:ROOT_IDX_W];

  always_comb begin
    if (raw_q_idx[ROOT_IDX_W-1]) begin
      q_idx = 4'd15;
    end else if (!raw_q_idx[ROOT_IDX_W-2]) begin
      q_idx = 4'd0;
    end else begin
      q_idx = raw_q_idx[ROOT_IDX_W-3:0];
    end
  end

  srt_radix4_qds #(
      .DATA_W(DATA_W),
      .RAD_W (RAD_W)
  ) srt_radix4_qds_inst (
      .rem_sum_shift_i  (rem_sum_shift),
      .rem_carry_shift_i(rem_carry_shift),
      .q_idx_i          (q_idx),
      .q_digit_o        (q_digit)
  );

  always_comb begin
    neg_sub = '0;
    if (USE_ADDER) begin
      case (q_digit)
        3'sd2, -3'sd2: two_root_q = root_q_i << 2;
        3'sd1, -3'sd1: two_root_q = root_q_i << 1;
        default:       two_root_q = '0;
      endcase

      q_sq_term = '0;
      case (q_digit)
        3'sd2, -3'sd2: q_sq_term[STEP_BIT+2] = 1'b1;
        3'sd1, -3'sd1: q_sq_term[STEP_BIT] = 1'b1;
        default:       q_sq_term = '0;
      endcase

      if (q_digit > 0) begin
        neg_sub = -(two_root_q + q_sq_term);
      end else if (q_digit < 0) begin
        neg_sub = two_root_q - q_sq_term;
      end

    end else begin

      case (q_digit)
        3'sd2:   two_root_q = root_q_i << 2;
        3'sd1:   two_root_q = root_q_i << 1;
        -3'sd1:  two_root_q = root_qm_i << 1;
        -3'sd2:  two_root_q = root_qm_i << 2;
        default: two_root_q = '0;
      endcase
      q_sq_term = '0;
      case (q_digit)
        3'sd2:   q_sq_term[STEP_BIT+2] = 1'b1;
        3'sd1:   q_sq_term[STEP_BIT] = 1'b1;
        -3'sd1:  q_sq_term = DATA_W'(7) << STEP_BIT;
        -3'sd2:  q_sq_term = DATA_W'(12) << STEP_BIT;
        default: q_sq_term = '0;
      endcase

      neg_sub = '0;
      if (q_digit > 3'sd0) begin
        unique case (q_digit)
          3'sd1: neg_sub = {~root_q_i[DATA_W-2:STEP_BIT+1], 2'b11, {STEP_BIT{1'b0}}};
          3'sd2: neg_sub = {~root_q_i[DATA_W-3:STEP_BIT+1], 1'b1, {(STEP_BIT + 2) {1'b0}}};
        endcase
      end else if (q_digit < 3'sd0) begin
        neg_sub = two_root_q | q_sq_term;
      end
    end
  end

  carry_save_row_adder #(
      .DATA_W(DATA_W)
  ) carry_save_row_adder_inst (
      .row_a(rem_sum_shift),
      .row_b(rem_carry_shift),
      .row_c(neg_sub),
      .sum  (rem_sum_o),
      .carry(rem_carry_o)
  );

  always_comb begin
    root_q_o  = root_q_i;
    root_qm_o = root_qm_i;

    if (USE_ADDER) begin
      unique case (q_digit)
        3'sd2: begin
          root_q_o  = root_q_i + $signed(DATA_W'(2'b10) << STEP_BIT);
          root_qm_o = root_q_i + $signed(DATA_W'(2'b01) << STEP_BIT);
        end
        3'sd1: begin
          root_q_o  = root_q_i + $signed(DATA_W'(2'b01) << STEP_BIT);
          root_qm_o = root_q_i;
        end
        3'sd0: begin
          root_q_o  = root_q_i;
          root_qm_o = root_qm_i + $signed(DATA_W'(2'b11) << STEP_BIT);
        end
        -3'sd1: begin
          root_q_o  = root_qm_i + $signed(DATA_W'(2'b11) << STEP_BIT);
          root_qm_o = root_qm_i + $signed(DATA_W'(2'b10) << STEP_BIT);
        end
        -3'sd2: begin
          root_q_o  = root_qm_i + $signed(DATA_W'(2'b10) << STEP_BIT);
          root_qm_o = root_qm_i + $signed(DATA_W'(2'b01) << STEP_BIT);
        end
      endcase
    end else begin
      unique case (q_digit)
        3'sd2: begin
          root_q_o  = root_q_i | $signed(DATA_W'(2'b10) << STEP_BIT);
          root_qm_o = root_q_i | $signed(DATA_W'(2'b01) << STEP_BIT);
        end
        3'sd1: begin
          root_q_o  = root_q_i | $signed(DATA_W'(2'b01) << STEP_BIT);
          root_qm_o = root_q_i;
        end
        3'sd0: begin
          root_q_o  = root_q_i;
          root_qm_o = root_qm_i | $signed(DATA_W'(2'b11) << STEP_BIT);
        end
        -3'sd1: begin
          root_q_o  = root_qm_i | $signed(DATA_W'(2'b11) << STEP_BIT);
          root_qm_o = root_qm_i | $signed(DATA_W'(2'b10) << STEP_BIT);
        end
        -3'sd2: begin
          root_q_o  = root_qm_i | $signed(DATA_W'(2'b10) << STEP_BIT);
          root_qm_o = root_qm_i | $signed(DATA_W'(2'b01) << STEP_BIT);
        end
      endcase
    end
  end

endmodule
