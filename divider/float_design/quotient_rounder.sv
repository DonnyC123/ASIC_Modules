module quotient_rounder
  import divider_float_pkg::*;
#(
    parameter FRAC_W       = 10,
    parameter EXP_W        = 6,
    parameter SIGNED_EXP_W = 8,
    parameter type float_t = struct packed {
      logic sign;
      logic [EXP_W-1:0] exp;
      logic [FRAC_W-1:0] frac;
    },
    localparam MANTISSA_W     = FRAC_W + 1,
    localparam QUOTIENT_RAW_W = OFFSET_BIT_W + MANTISSA_W + GUARD_W
) (
    input  quotient_float_flags_t                      float_quotient_flags_i,
    input  logic signed           [  SIGNED_EXP_W-1:0] quotient_exp_i,
    input  logic                  [QUOTIENT_RAW_W-1:0] quotient_raw_i,
    input  logic                                       sticky_i,
    output float_t                                     quotient_o
);

  localparam QUOTIENT_EXTENDED_W = MANTISSA_W + GUARD_W;

  logic        [QUOTIENT_EXTENDED_W-1:0] quotient_extended;
  logic        [QUOTIENT_EXTENDED_W-1:0] quotient_unrounded;
  logic        [QUOTIENT_EXTENDED_W-1:0] quotient_rounded_raw;
  logic        [         MANTISSA_W-1:0] quotient_rounded;
  logic        [         MANTISSA_W-1:0] quotient_mantissa;


  logic signed [       SIGNED_EXP_W-1:0] quotient_exp_extended;
  logic signed [       SIGNED_EXP_W-1:0] quotient_exp_rounded;

  logic                                  quotient_exp_rounded_unfl;
  logic                                  quotient_exp_rounded_ovfl;

  logic                                  guard;
  logic                                  sticky;

  // Might be able to check if we will round and then do one add instead of
  // mutliple

  always_comb begin
    // ==========================================================
    // 1. Initial Normalization & Setup
    // ==========================================================
    // Start with default values from inputs
    logic signed [       SIGNED_EXP_W-1:0] exp_temp;
    logic        [QUOTIENT_EXTENDED_W-1:0] mant_temp;
    logic                                  sticky_temp;
    logic                                  guard_bit;
    logic                                  round_bit;  // Often useful to track explicitly
    int                                    shift_amt;
    logic        [           MANTISSA_W:0] mant_rounded;  // 1 bit wider for overflow

    // Handle the divider output normalization (1.x vs 0.1x)
    if (!quotient_raw_i[QUOTIENT_RAW_W-1]) begin
      // Shifted case: MSB was 0, so we use lower bits and decrement exp
      exp_temp    = quotient_exp_i - 1;
      mant_temp   = quotient_raw_i[QUOTIENT_EXTENDED_W-1:0];
      sticky_temp = sticky_i;  // Sticky from divider is sufficient
    end else begin
      // Standard case
      exp_temp    = quotient_exp_i;
      mant_temp   = quotient_raw_i[QUOTIENT_RAW_W-1:1];
      sticky_temp = sticky_i || quotient_raw_i[0];  // Capture dropped LSB into sticky
    end

    // ==========================================================
    // 2. Denormalization (Underflow Handling)
    // ==========================================================
    // If the exponent is too small (<= 0), we must shift right to fit
    // the denormal range (Target Exp = 1, Mantissa = 0.xxx)

    shift_amt = 0;  // Default

    if (exp_temp <= 0) begin
      // Calculate shift needed to bring exponent back to 1
      // Example: Exp 0 -> Shift 1. Exp -1 -> Shift 2.
      shift_amt = 1 - exp_temp;

      // CAPTURE STICKY BITS BEFORE SHIFTING
      // Any '1' bit that is shifted out must be added to the sticky bit.
      // We create a mask for the bits to be shifted out.
      // (Note: ensure shift_amt doesn't exceed width to prevent simulation errors)
      if (shift_amt < QUOTIENT_EXTENDED_W) begin
        logic [QUOTIENT_EXTENDED_W-1:0] mask;
        mask        = (QUOTIENT_EXTENDED_W'(1) << shift_amt) - 1;
        sticky_temp = sticky_temp || |(mant_temp & mask);

        // Apply the shift
        mant_temp   = mant_temp >> shift_amt;
      end else begin
        // Total underflow: flushed to zero (but sticky remains)
        sticky_temp = sticky_temp || |mant_temp;
        mant_temp   = '0;
      end

      // Force exponent to minimum (denormal) value
      exp_temp = 1;
    end

    // ==========================================================
    // 3. Rounding Logic
    // ==========================================================
    // Now that we have the final aligned mantissa, we round.
    // Based on your previous code, 'mant_temp' likely has:
    // [MSB ... LSB, Guard, (Round?)]

    // Assuming mant_temp structure: [MANTISSA | GUARD | ...]
    // Let's isolate the bits for clarity:

    // The bit at position 0 is our 'Guard' (the first bit after precision)
    guard_bit    = mant_temp[0];

    // The bits above it are the unrounded mantissa
    // We add a leading 0 to handle potential overflow (1.11 -> 10.00)
    mant_rounded = {1'b0, mant_temp[QUOTIENT_EXTENDED_W-1:1]};

    // Round to Nearest Even:
    // Increment if:
    // 1. Guard is 1 AND Sticky is 1 ( > 0.5 )
    // 2. Guard is 1 AND Sticky is 0 AND LSB is 1 ( == 0.5, round to even )
    if (guard_bit && (sticky_temp || mant_rounded[0])) begin
      mant_rounded = mant_rounded + 1;
    end

    // ==========================================================
    // 4. Post-Rounding Update
    // ==========================================================

    quotient_exp_rounded = exp_temp;

    // Check if rounding caused an overflow (e.g. 0.111... -> 1.000...)
    // Since 'mant_rounded' is 1 bit wider, we check the MSB.
    if (mant_rounded[MANTISSA_W]) begin
      // Overflow! Shift right and increment exponent
      quotient_mantissa    = mant_rounded[MANTISSA_W:1];
      quotient_exp_rounded = exp_temp + 1;
    end else begin
      // Normal case
      quotient_mantissa = mant_rounded[MANTISSA_W-1:0];
    end

    quotient_exp_rounded_ovfl = |quotient_exp_rounded[SIGNED_EXP_W-2-:2];  // Check top bits
    quotient_exp_rounded_unfl = quotient_exp_rounded[SIGNED_EXP_W-1];
  end



























































  always_comb begin
    quotient_o.sign = float_quotient_flags_i.sign;
    quotient_o.frac = quotient_mantissa[FRAC_W-1:0];
    quotient_o.exp  = quotient_exp_rounded[EXP_W-1:0];

    if (float_quotient_flags_i.nan) begin  // unique0?
      quotient_o.exp  = '1;
      quotient_o.frac = '1;
    end else if (float_quotient_flags_i.zero || quotient_exp_rounded_unfl) begin
      quotient_o.exp = '0;
      if (float_quotient_flags_i.zero) begin
        quotient_o.frac = '0;
      end
    end else if (float_quotient_flags_i.inf || quotient_exp_rounded_ovfl) begin
      quotient_o.exp  = '1;
      quotient_o.frac = '0;
    end
  end

endmodule

