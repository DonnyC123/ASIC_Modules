`timescale 1ns / 1ps

module tb_mac_float;

  parameter EXP_W    = 5;
  parameter FRAC_W   = 10;
  localparam FLOAT_W = FRAC_W + EXP_W + 1;
  localparam BIAS    = (1 << (EXP_W - 1)) - 1;
  localparam MAX_EXP = (1 << EXP_W);

  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_t;

  logic [FLOAT_W-1:0] a, b, c;
  logic [FLOAT_W-1:0] z;

  mac_float #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) dut (
      .a(a),
      .b(b),
      .c(c),
      .z(z)
  );

  localparam DOUBLE_EXP_W  = 11;
  localparam DOUBLE_FRAC_W = 52;
  localparam DOUBLE_SIGN_W = 1;
  localparam DOUBLE_W      = DOUBLE_EXP_W + DOUBLE_FRAC_W + DOUBLE_SIGN_W;
  localparam DOUBLE_BIAS   = (1 << (DOUBLE_EXP_W - 1)) - 1;

  typedef struct packed {
    logic sign;
    logic [DOUBLE_EXP_W-1:0] exp;
    logic [DOUBLE_FRAC_W-1:0] frac;
  } double_fields_t;

  function automatic float_t downscale_double(input real val);
    double_fields_t                     double_bits;
    float_t                             float_o;
    int                                 e_c;
    int                                 shift_amount;
    logic           [DOUBLE_FRAC_W+1:0] full_frac;
    logic           [DOUBLE_FRAC_W+1:0] shifted_frac;
    logic           [         FRAC_W:0] rounding_frac;
    logic                               sticky;
    logic                               round_up;

    double_bits  = double_fields_t'($realtobits(val));
    float_o      = '0;
    float_o.sign = double_bits.sign;

    if (double_bits.exp == '0 && double_bits.frac == '0) begin
      return float_o;
    end

    if (double_bits.exp == '1) begin
      float_o.exp = '1;
      if (double_bits.frac != '0) float_o.frac = FRAC_W'(|(double_bits.frac));
      return float_o;
    end

    e_c = int'(double_bits.exp) - DOUBLE_BIAS + BIAS;

    full_frac = (double_bits.exp == 0) ? {2'b00, double_bits.frac} : {1'b0, 1'b1, double_bits.frac};

    if (e_c <= 0) begin
      // --- SUBNORMAL OR UNDERFLOW ---
      float_o.exp  = '0;
      shift_amount = 1 - e_c;
      if (shift_amount > DOUBLE_FRAC_W + 2) begin
        shifted_frac = '0;
        sticky       = |full_frac;
      end else begin
        shifted_frac = full_frac >> shift_amount;
        sticky       = (full_frac << (DOUBLE_FRAC_W + 2 - shift_amount)) != '0;
      end

      rounding_frac = shifted_frac[DOUBLE_FRAC_W-1-:(FRAC_W+1)];

      if (FRAC_W < DOUBLE_FRAC_W) begin
        sticky = sticky | (|shifted_frac[DOUBLE_FRAC_W-FRAC_W-2 : 0]);
      end

    end else if (e_c >= (1 << EXP_W) - 1) begin
      float_o.exp  = '1;
      float_o.frac = '0;
      return float_o;

    end else begin
      float_o.exp   = e_c;
      rounding_frac = double_bits.frac[DOUBLE_FRAC_W-1-:(FRAC_W+1)];

      if (FRAC_W < DOUBLE_FRAC_W) begin
        sticky = |double_bits.frac[DOUBLE_FRAC_W-FRAC_W-2 : 0];
      end else begin
        sticky = 1'b0;
      end
    end

    round_up                    = rounding_frac[0] & (rounding_frac[1] | sticky);
    {float_o.exp, float_o.frac} = {float_o.exp, rounding_frac[FRAC_W:1]} + round_up;

    return float_o;
  endfunction

  function automatic real upscale_to_double(input float_t float_i);
    double_fields_t              double_bits;
    int                          lz;
    logic           [FRAC_W-1:0] norm_frac;

    double_bits      = '0;
    double_bits.sign = float_i.sign;

    if (float_i.exp == '0 && float_i.frac == '0) begin
      double_bits.exp  = '0;
      double_bits.frac = '0;

    end else if (float_i.exp == '1) begin
      double_bits.exp  = '1;
      double_bits.frac = {float_i.frac, {(DOUBLE_FRAC_W - FRAC_W) {1'b0}}};

    end else if (float_i.exp == '0) begin
      lz = 0;
      for (int i = FRAC_W - 1; i >= 0; i--) begin
        if (float_i.frac[i]) break;
        lz++;
      end

      double_bits.exp  = DOUBLE_EXP_W'($unsigned(DOUBLE_BIAS - BIAS - lz));

      norm_frac        = float_i.frac << (lz + 1);
      double_bits.frac = {norm_frac, {(DOUBLE_FRAC_W - FRAC_W) {1'b0}}};

    end else begin
      double_bits.exp  = DOUBLE_EXP_W'(float_i.exp) + DOUBLE_EXP_W'($unsigned(DOUBLE_BIAS - BIAS));
      double_bits.frac = {float_i.frac, {(DOUBLE_FRAC_W - FRAC_W) {1'b0}}};
    end

    return $bitstoreal(double_bits);
  endfunction


  real real_a, real_b, real_c, real_z_dut, real_z_ref;
  integer i;
  integer errors = 0;

  task check_result(input string name);
    real                expected;
    logic [FLOAT_W-1:0] expected_bits;
    logic [FLOAT_W-1:0] diff;
    bit                 check_pass;

    real_a        = upscale_to_double(a);
    real_b        = upscale_to_double(b);
    real_c        = upscale_to_double(c);

    expected      = (real_a * real_b) + real_c;
    expected_bits = downscale_double(expected);

    real_z_dut    = upscale_to_double(z);
    real_z_ref    = upscale_to_double(downscale_double(expected));

    check_pass    = 0;

    if (real_z_dut == 0.0 && real_z_ref == 0.0) begin
      check_pass = 1;
    end else if (z != expected_bits) begin
      check_pass = 0;
    end else begin
      diff = (z > expected_bits) ? (z - expected_bits) : (expected_bits - z);
      if (diff <= 1) check_pass = 1;
    end

    if (!check_pass) begin
      $error("[%s] FAIL: A=%f B=%f C=%f | DUT=%f (0x%h) REF=%f (0x%h)", name, real_a, real_b,
             real_c, real_z_dut, z, real_z_ref, expected_bits);
      errors++;
    end else begin
      $display("[%s] PASS: %f", name, real_z_dut);
    end
  endtask

  initial begin
    $display("=== STARTING PARAMETERIZED MAC TEST (Exp=%0d, Frac=%0d) ===", EXP_W, FRAC_W);

    a = downscale_double(1.5);
    b = downscale_double(2.0);
    c = downscale_double(0.0);

    #10;
    check_result("Simple Mult");

    a = downscale_double(1.0);
    b = downscale_double(1.0);
    c = downscale_double(3.5);

    #10;
    check_result("Simple Add");

    $display("--- Random Stress Test ---");
    for (i = 0; i < 100; i++) begin
      void'(std::randomize(a, b, c));

      if (i % 10 == 0) c = 0;

      #10;
      check_result($sformatf("Rand #%0d", i));
    end

    $display("=== TEST COMPLETED. Total Errors: %0d ===", errors);
    $finish;
  end

endmodule
