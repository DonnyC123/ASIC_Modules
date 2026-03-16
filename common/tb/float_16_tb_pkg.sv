package float_16_tb_pkg;

  parameter EXP_W    = 5;
  parameter FRAC_W   = 10;
  localparam FLOAT_W = FRAC_W + EXP_W + 1;
  localparam BIAS    = (1 << (EXP_W - 1)) - 1;
  localparam MAX_EXP = (1 << EXP_W);

  typedef struct packed {
    logic sign;
    logic [EXP_W-1:0] exp;
    logic [FRAC_W-1:0] frac;
  } float_16_t;


  localparam DOUBLE_EXP_W  = 11;
  localparam DOUBLE_FRAC_W = 52;
  localparam DOUBLE_SIGN_W = 1;
  localparam DOUBLE_W      = DOUBLE_EXP_W + DOUBLE_FRAC_W + DOUBLE_SIGN_W;
  localparam DOUBLE_BIAS   = (1 << (DOUBLE_EXP_W - 1)) - 1;

  typedef struct packed {
    logic sign;
    logic [DOUBLE_EXP_W-1:0] exp;
    logic [DOUBLE_FRAC_W-1:0] frac;
  } float_double_t;

  function automatic float_16_t downscale_double(input real val);
    logic          [DOUBLE_FRAC_W:0] full_frac;
    logic          [       FRAC_W:0] rounding_frac;
    logic          [       FRAC_W:0] frac_carry_adder;
    logic                            sticky;
    logic                            round_up;
    float_double_t                   double_bits;
    float_16_t                       float_o;
    int                              shift_dist;
    int                              new_exp;

    double_bits = float_double_t'($realtobits(val));
    new_exp     = int'(double_bits.exp) - DOUBLE_BIAS + BIAS;

    if (double_bits.exp == '0 && double_bits.frac == '0) begin
      float_o      = '0;
      float_o.sign = double_bits.sign;
      return float_o;
    end

    full_frac = (double_bits.exp == '0) ? {1'b0, double_bits.frac} : {1'b1, double_bits.frac};
    if (new_exp <= 0) begin
      float_o.exp = '0;
      shift_dist  = 1 - new_exp;

      if (shift_dist > DOUBLE_FRAC_W + 1) begin
        rounding_frac = '0;
        sticky        = 1'b1;
      end else begin
        logic [DOUBLE_FRAC_W:0] shifted_frac = full_frac >> shift_dist;
        rounding_frac = shifted_frac[DOUBLE_FRAC_W-1-:(FRAC_W+1)];

        if (FRAC_W < DOUBLE_FRAC_W) begin
          sticky = (|shifted_frac[DOUBLE_FRAC_W - FRAC_W - 2 : 0]) |                                 
                   ((full_frac << (DOUBLE_FRAC_W + 1 - shift_dist)) != '0);
        end else begin
          sticky = ((full_frac << (DOUBLE_FRAC_W + 1 - shift_dist)) != '0);
        end
      end
    end else if (new_exp >= (1 << EXP_W) - 1) begin
      float_o.sign = double_bits.sign;
      float_o.exp  = '1;
      float_o.frac = (double_bits.exp == '1) ? FRAC_W'(|(double_bits.frac)) : '0;
      return float_o;

    end else begin
      float_o.exp   = new_exp[EXP_W-1:0];
      rounding_frac = double_bits.frac[DOUBLE_FRAC_W-1-:(FRAC_W+1)];

      if (FRAC_W < DOUBLE_FRAC_W) begin
        sticky = |double_bits.frac[(DOUBLE_FRAC_W-FRAC_W-2) : 0];
      end else begin
        sticky = 1'b0;
      end
    end

    round_up         = rounding_frac[0] & (rounding_frac[1] | sticky);
    frac_carry_adder = {1'b0, rounding_frac[FRAC_W:1]} + round_up;
    float_o.frac     = frac_carry_adder[FRAC_W-1:0];

    if (frac_carry_adder[FRAC_W]) begin
      float_o.exp = float_o.exp + 1'b1;
    end

    float_o.sign = double_bits.sign;
    return float_o;

  endfunction

  function automatic real upscale_to_double(input float_16_t float_i);
    int            lz;
    float_double_t double_bits;
    double_bits      = '0;
    double_bits.sign = float_i.sign;

    if (float_i.exp == '0) begin
      if (float_i.frac == '0) begin
        return $bitstoreal(double_bits);
      end else begin
        lz = 0;
        for (int i = FRAC_W - 1; i >= 0; i--) begin
          if (float_i.frac[i] == 1'b1) break;
          lz++;
        end

        double_bits.exp  = DOUBLE_EXP_W'($unsigned(DOUBLE_BIAS - BIAS - lz));
        double_bits.frac = {float_i.frac << (lz + 1), {(DOUBLE_FRAC_W - FRAC_W) {1'b0}}};
      end
    end else if (float_i.exp == '1) begin
      double_bits.exp  = '1;
      double_bits.frac = {float_i.frac, {(DOUBLE_FRAC_W - FRAC_W) {1'b0}}};
    end else begin
      double_bits.exp  = DOUBLE_EXP_W'(float_i.exp) + DOUBLE_EXP_W'($unsigned(DOUBLE_BIAS - BIAS));
      double_bits.frac = {float_i.frac, {(DOUBLE_FRAC_W - FRAC_W) {1'b0}}};
    end

    return $bitstoreal(double_bits);
  endfunction

  function automatic logic is_nan(input real val);
    return (val != val);
  endfunction
endpackage
