module srt_radix4_seed
  import srt_sqrt_pkg::*;
(
    input  logic [SEED_IDX_W-1:0] seed_idx_i,
    output logic [SEED_IDX_W-1:0] root_seed_o,
    output logic [  SQ_INT_W-1:0] root_sq_seed_o
);

  localparam ROM_DEPTH = 2 ** SEED_IDX_W;

  logic [SEED_IDX_W-1:0] root_seed_rom   [ROM_DEPTH];
  logic [  SQ_INT_W-1:0] root_sq_seed_rom[ROM_DEPTH];

  always_comb begin
    root_seed_rom[0]  = 6'd0;
    root_seed_rom[1]  = 6'd0;
    root_seed_rom[2]  = 6'd0;
    root_seed_rom[3]  = 6'd0;
    root_seed_rom[4]  = 6'd0;
    root_seed_rom[5]  = 6'd0;
    root_seed_rom[6]  = 6'd0;
    root_seed_rom[7]  = 6'd0;
    root_seed_rom[8]  = 6'd0;
    root_seed_rom[9]  = 6'd0;
    root_seed_rom[10] = 6'd0;
    root_seed_rom[11] = 6'd0;
    root_seed_rom[12] = 6'd0;
    root_seed_rom[13] = 6'd0;
    root_seed_rom[14] = 6'd0;
    root_seed_rom[15] = 6'd0;
    root_seed_rom[16] = 6'd32;
    root_seed_rom[17] = 6'd33;
    root_seed_rom[18] = 6'd34;
    root_seed_rom[19] = 6'd35;
    root_seed_rom[20] = 6'd36;
    root_seed_rom[21] = 6'd37;
    root_seed_rom[22] = 6'd38;
    root_seed_rom[23] = 6'd39;
    root_seed_rom[24] = 6'd40;
    root_seed_rom[25] = 6'd40;
    root_seed_rom[26] = 6'd41;
    root_seed_rom[27] = 6'd42;
    root_seed_rom[28] = 6'd43;
    root_seed_rom[29] = 6'd43;
    root_seed_rom[30] = 6'd44;
    root_seed_rom[31] = 6'd45;
    root_seed_rom[32] = 6'd46;
    root_seed_rom[33] = 6'd46;
    root_seed_rom[34] = 6'd47;
    root_seed_rom[35] = 6'd48;
    root_seed_rom[36] = 6'd48;
    root_seed_rom[37] = 6'd49;
    root_seed_rom[38] = 6'd50;
    root_seed_rom[39] = 6'd50;
    root_seed_rom[40] = 6'd51;
    root_seed_rom[41] = 6'd52;
    root_seed_rom[42] = 6'd52;
    root_seed_rom[43] = 6'd53;
    root_seed_rom[44] = 6'd53;
    root_seed_rom[45] = 6'd54;
    root_seed_rom[46] = 6'd55;
    root_seed_rom[47] = 6'd55;
    root_seed_rom[48] = 6'd56;
    root_seed_rom[49] = 6'd56;
    root_seed_rom[50] = 6'd57;
    root_seed_rom[51] = 6'd57;
    root_seed_rom[52] = 6'd58;
    root_seed_rom[53] = 6'd59;
    root_seed_rom[54] = 6'd59;
    root_seed_rom[55] = 6'd60;
    root_seed_rom[56] = 6'd60;
    root_seed_rom[57] = 6'd61;
    root_seed_rom[58] = 6'd61;
    root_seed_rom[59] = 6'd62;
    root_seed_rom[60] = 6'd62;
    root_seed_rom[61] = 6'd63;
    root_seed_rom[62] = 6'd63;
    root_seed_rom[63] = 6'd63;

  end

  always_comb begin
    for (int i = 0; i < ROM_DEPTH; i++) begin
      root_sq_seed_rom[i] = SQ_INT_W'(root_seed_rom[i]) * SQ_INT_W'(root_seed_rom[i]);
    end
  end

  assign root_seed_o    = root_seed_rom[seed_idx_i];
  assign root_sq_seed_o = root_sq_seed_rom[seed_idx_i];
endmodule
