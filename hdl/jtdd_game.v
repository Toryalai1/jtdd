/*  This file is part of JTDD.
    JTDD program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTDD program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTDD.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2017 */

module jtdd_game(
    input           clk,
    input           rst,
    output          pxl2_cen,
    output          pxl_cen,
    output          LVBL_dly,
    output          LHBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 6:0]  joystick1,
    input   [ 6:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    input           loop_rst,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [31:0]  data_read,
    input           data_rdy,
    input           sdram_ack,
    output          refresh_en,
    // ROM LOAD
    input   [21:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input           dip_pause,
    input           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB   
    // Sound output (stereo game)
    output  signed [15:0] snd_left,
    output  signed [15:0] snd_right,
    output          sample,
    input           enable_psg,
    input           enable_fm,
    // video
    output  [ 3:0]  red,
    output  [ 3:0]  green,
    output  [ 3:0]  blue,
    // Debug
    input   [ 3:0]  gfx_en

);

wire       [12:0]  cpu_AB;
wire               pal_cs;
wire               char_cs;
wire               cpu_wrn;
wire       [ 7:0]  cpu_dout;
wire               cen_E;
wire       [ 7:0]  char_dout;
// video signals
wire               VBL, HBL, VS, HS;
wire               flip;
// ROM access
wire       [14:0]  char_addr;
wire       [ 7:0]  char_data;
wire               char_ok;
wire       [ 6:0]  char_pxl;
// PROM programming
wire       [21:0]  prog_addr;
wire               prom_prio_we;

assign LVBL_dly = ~VBL;
assign LHBL_dly = ~HBL;
assign prog_addr = 22'd0;

wire cen12, cen8, cen6, cen3, cen3q, cen1p5, cen12b, cen6b;

assign pxl_cen  = cen6;
assign pxl2_cen = cen12;

jtframe_cen48 u_cen(
    .clk     (  clk      ),    // 48 MHz
    .cen12   (  cen12    ),
    .cen8    (  cen8     ),
    .cen6    (  cen6     ),
    .cen3    (  cen3     ),
    .cen3q   (  cen3q    ), // 1/4 advanced with respect to cen3
    .cen1p5  (  cen1p5   ),
    .cen12b  (  cen12b   ),
    .cen6b   (  cen6b    )
);

jtdd_video u_video(
    .clk          (  clk          ),
    .rst          (  rst          ),
    .pxl_cen      (  pxl_cen      ),
    .cen12        (  cen12        ),
    .cpu_AB       (  cpu_AB       ),
    .pal_cs       (  pal_cs       ),
    .char_cs      (  char_cs      ),
    .cpu_wrn      (  cpu_wrn      ),
    .cpu_dout     (  cpu_dout     ),
    .cen_E        (  cen_E        ),
    .char_dout    (  char_dout    ),
    // video signals
    .VBL          (  VBL          ),
    .VS           (  VS           ),
    .HBL          (  HBL          ),
    .HS           (  HS           ),
    .flip         (  flip         ),
    .char_addr    (  char_addr    ),
    // ROM access
    .char_data    (  char_data    ),
    .char_ok      (  char_ok      ),
    .char_pxl     (  char_pxl     ),
    // PROM programming
    .prog_addr    (  prog_addr[7:0]    ),
    .prom_prio_we (  prom_prio_we ),
    // Pixel output
    .red          (  red          ),
    .green        (  green        ),
    .blue         (  blue         )
);

// Same as locations inside JTDD.rom file
localparam BANK_ADDR   = 22'h00000;
localparam MAIN_ADDR   = 22'h20000;
localparam SND_ADDR    = 22'h28000;
localparam ADPCM_1     = 22'h30000;
localparam ADPCM_2     = 22'h40000;
localparam CHAR_ADDR   = 22'h50000;

// reallocated:
localparam SCR_ADDR  = 22'h40000;
localparam OBJ_ADDR  = 22'h80000;


jtframe_rom #(
    .char_aw    ( 15              ),
    .char_dw    ( 8               ),
    .main_aw    ( 17              ),
    .obj_aw     ( 16              ),
    .scr1_aw    ( 15              ),
    .scr2_aw    ( 15              ),
    // MAP slots used for ADPCM
    .snd_offset ( SND_ADDR>>1     ),
    .char_offset( CHAR_ADDR>>1    ),
    .scr1_offset( SCR_ADDR        ),
    .scr2_offset(  ),
    .obj_offset ( OBJ_ADDR        )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .LVBL        ( ~VBL          ),

    .main_cs     ( 1'b0          ),
    .snd_cs      ( 1'b0          ),
    .main_ok     ( main_ok       ),
    .snd_ok      (               ),
    .scr1_ok     (               ),
    .scr2_ok     (               ),
    .char_ok     ( char_ok       ),
    .obj_ok      (               ),

    .char_addr   ( char_addr     ),
    .main_addr   ( 17'd0             ),
    .snd_addr    ( 15'd0             ),
    .obj_addr    ( 16'd0             ),
    .scr1_addr   ( 15'd0             ),
    .scr2_addr   ( 15'd0             ),
    .map1_addr   ( 14'd0         ),
    .map2_addr   ( 14'd0         ),

    .char_dout   ( char_data     ),
    .main_dout   (               ),
    .snd_dout    (               ),
    .obj_dout    (               ),
    .map1_dout   (               ),
    .map2_dout   (               ),
    .scr1_dout   (               ),
    .scr2_dout   (               ),

    .ready       ( rom_ready     ),
    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .refresh_en  ( refresh_en    )
);

endmodule