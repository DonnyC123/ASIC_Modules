`timescale 1ns / 1ps

module tb_mac_float;

  // -------------------------------------------------------------------------
  // Parameters
  // -------------------------------------------------------------------------
  parameter EXP_W   = 5;
  parameter FRAC_W  = 10;
  localparam DATA_W = FRAC_W + EXP_W + 1;
  localparam BIAS   = (1 << (EXP_W - 1)) - 1;

  // -------------------------------------------------------------------------
  // DUT Signals
  // -------------------------------------------------------------------------
  logic [DATA_W-1:0] a, b, c;
  logic [DATA_W-1:0] z;

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  mac_float_model #(
      .EXP_W (EXP_W),
      .FRAC_W(FRAC_W)
  ) dut (
      .a(a),
      .b(b),
      .c(c),
      .z(z)
  );

  // -------------------------------------------------------------------------
  // Helper Functions (Parameterized)
  // -------------------------------------------------------------------------

  // Converts a SystemVerilog 'real' (64-bit IEEE 754) to your Custom Float
  function automatic logic [DATA_W-1:0] real2bits(input real val);
    logic             sign;
    logic [10:0]      exp_raw;  // Always 11 bits for 'real' (double)
    logic [51:0]      mant_raw; // Always 52 bits for 'real' (double)
    logic [63:0]      double_bits;
    logic [EXP_W-1:0] new_exp;
    logic [FRAC_W-1:0] new_frac;
    
    // Variables for rounding
    logic [FRAC_W:0]  rounding_frac; 

    double_bits = $realtobits(val);
    sign        = double_bits[63];
    exp_raw     = double_bits[62:52];
    mant_raw    = double_bits[51:0];

    if (val == 0.0) return '0;

    // Check Underflow (Too small for custom width)
    if ($signed(exp_raw) - 1023 + BIAS <= 0) begin
      new_exp  = '0; 
      new_frac = '0;
    end 
    // Check Overflow (Too large for custom width)
    else if ($signed(exp_raw) - 1023 + BIAS >= (1 << EXP_W) - 1) begin
      new_exp  = '1; 
      new_frac = '0;
    end 
    // Normal Case
    else begin
      new_exp = exp_raw - 1023 + BIAS;
      
      // Extract top FRAC_W bits from the 52-bit double mantissa
      // We take the top FRAC_W + 1 bits to perform rounding
      if (FRAC_W >= 52) begin
          // If custom width is HUGE, just pad with zeros
          rounding_frac = {mant_raw, { (FRAC_W - 52 + 1) {1'b0} }};
      end else begin
          // Standard case: Select top bits
          rounding_frac = mant_raw[51 -: (FRAC_W + 1)];
      end
      
      // Round to nearest (check LSB of the slice)
      new_frac = rounding_frac[FRAC_W:1] + rounding_frac[0];
      
      // Handle rounding overflow (e.g. 111..1 + 1 -> 000..0)
      if (new_frac == 0 && rounding_frac[FRAC_W:1] == '1) begin
         new_exp = new_exp + 1;
         if (new_exp == '1) new_frac = 0; // Overflow to infinity
      end
    end

    return {sign, new_exp, new_frac};
  endfunction

  // Converts Custom Float to SystemVerilog 'real' (64-bit IEEE 754)
  function automatic real bits2real(input logic [DATA_W-1:0] val);
    logic             sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
    real              res;
    
    // Explicitly slice input based on parameters
    frac = val[FRAC_W-1:0];
    exp  = val[FRAC_W+EXP_W-1:FRAC_W];
    sign = val[DATA_W-1]; // MSB

    if (exp == '0) return 0.0;
    if (exp == '1) return (sign ? -1.0/0.0 : 1.0/0.0); // Inf

    // Calculate value: (-1)^S * (1.M) * 2^(E - Bias)
    // We divide frac by 2^FRAC_W to get the fractional part 0.xxxxx
    res = (1.0 + (real'(frac) / (2.0 ** FRAC_W))) * (2.0 ** (int'(exp) - BIAS));
    return sign ? -res : res;
  endfunction

  // -------------------------------------------------------------------------
  // Test Variables & Tasks
  // -------------------------------------------------------------------------
  real real_a, real_b, real_c, real_z_dut, real_z_ref;
  integer i;
  integer errors = 0;

  task check_result(input string name);
    real                expected;
    logic [DATA_W-1:0]  expected_bits;
    logic [DATA_W-1:0]  diff;
    bit                 check_pass;

    real_a = bits2real(a);
    real_b = bits2real(b);
    real_c = bits2real(c);

    expected      = (real_a * real_b) + real_c;
    expected_bits = real2bits(expected);

    real_z_dut    = bits2real(z);
    real_z_ref    = expected;

    check_pass = 0;
    
    // Zero Check (Handle +0 vs -0)
    if (real_z_dut == 0.0 && real_z_ref == 0.0) begin
        check_pass = 1;
    end
    // Sign Check
    else if (z[DATA_W-1] != expected_bits[DATA_W-1]) begin
        check_pass = 0; // Signs differ and not zero
    end
    // ULP Check
    else begin
        diff = (z > expected_bits) ? (z - expected_bits) : (expected_bits - z);
        if (diff <= 1) check_pass = 1;
    end

    if (!check_pass) begin
      $error("[%s] FAIL: A=%f B=%f C=%f | DUT=%f (0x%h) REF=%f (0x%h)", 
             name, real_a, real_b, real_c, real_z_dut, z, real_z_ref, expected_bits);
      errors++;
    end else begin
      $display("[%s] PASS: %f", name, real_z_dut);
    end
  endtask

  // -------------------------------------------------------------------------
  // Main Test Sequence
  // -------------------------------------------------------------------------
  initial begin
    $display("=== STARTING PARAMETERIZED MAC TEST (Exp=%0d, Frac=%0d) ===", EXP_W, FRAC_W);

    // 1. Directed Tests
    a = real2bits(1.5); b = real2bits(2.0); c = real2bits(0.0); #10; check_result("Simple Mult");
    a = real2bits(1.0); b = real2bits(1.0); c = real2bits(3.5); #10; check_result("Simple Add");
    
    // 2. Random Tests
    $display("--- Random Stress Test ---");
    for (i = 0; i < 100; i++) begin
      void'(std::randomize(a, b, c)); 
      
      // Inject some zeros occasionally to test edge cases
      if (i % 10 == 0) c = 0; 
      
      #10;
      check_result($sformatf("Rand #%0d", i));
    end

    $display("=== TEST COMPLETED. Total Errors: %0d ===", errors);
    $finish;
  end

endmodule
