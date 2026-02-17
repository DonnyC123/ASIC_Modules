
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

  mac_float_model #(
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

    logic           [FRAC_W:0] rounding_frac;
    logic                      sticky;

    double_fields_t            double_bits;
    float_t                    float_o;

    double_bits = double_fields_t'($realtobits(val));

    if (val == 0.0) begin
      float_o      = '0;
      float_o.sign = double_bits.sign;
      return float_o;
    end

    if (int'(double_bits.exp) - DOUBLE_BIAS + BIAS <= 0) begin
      float_o = '0;
    end else if (int'(double_bits.exp) - DOUBLE_BIAS + BIAS >= (1 << EXP_W) - 1) begin
      float_o     = '0;
      float_o.exp = '1;
    end else begin
      float_o.exp   = double_bits.exp - DOUBLE_BIAS + BIAS;

      rounding_frac = double_bits.frac[DOUBLE_FRAC_W-1-:(FRAC_W+1)];

      if (FRAC_W < DOUBLE_FRAC_W) begin
        sticky = |double_bits.frac[(DOUBLE_FRAC_W-FRAC_W-2) : 0];
      end else begin
        sticky = 1'b0;
      end

      float_o.frac = rounding_frac[FRAC_W:1] + (rounding_frac[0] & (rounding_frac[1] | sticky));

      if (float_o.frac == 0 && rounding_frac[FRAC_W:1] == '1) begin
        float_o.exp = float_o.exp + 1;
      end
    end

    float_o.sign = double_bits.sign;
    return float_o;

  endfunction

  function automatic real upscale_to_double(input float_t float_i);
    double_fields_t double_bits;

    double_bits      = '0;
    double_bits.sign = float_i.sign;

    if (float_i.exp == '0) begin
      double_bits.exp = '0;
    end else if (float_i.exp == '1) begin
      double_bits.exp = '1;
    end else begin
      double_bits.exp = DOUBLE_EXP_W'(float_i.exp) + DOUBLE_EXP_W'($unsigned(DOUBLE_BIAS - BIAS));
    end

    double_bits.frac = {float_i.frac, {(DOUBLE_FRAC_W - FRAC_W) {1'b0}}};
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
    real_z_ref    = expected;

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
      $display("[%s] FAIL: A=%f B=%f C=%f | DUT=%f (0x%h) REF=%f (0x%h)", name, real_a, real_b,
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
