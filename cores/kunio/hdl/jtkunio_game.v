/*  This file is part of JTKUNIO.
    JTKUNIO program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    ( at your option) any later version.

    JTKUNIO program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKUNIO.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-7-2022 */

module jtkunio_game(
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
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

    // Bank 0: allows R/W
    output   [21:0] ba0_addr,
    output   [21:0] ba1_addr,
    output   [21:0] ba2_addr,
    output   [21:0] ba3_addr,
    output   [ 3:0] ba_rd,
    input    [ 3:0] ba_ack,
    input    [ 3:0] ba_dst,
    input    [ 3:0] ba_dok,
    input    [ 3:0] ba_rdy,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_din_m,
    output          ba_wr,

    input    [15:0] data_read,

    // RAM/ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [15:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output  [ 1:0]  prog_ba,
    output          prog_we,
    output          prog_rd,
    input           prog_ack,
    input           prog_dok,
    input           prog_dst,
    input           prog_rdy,
    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           service,
    input           dip_pause,
    output          dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en,
    input   [7:0]   debug_bus,
    output  [7:0]   debug_view
);

// clock enable signals
wire [ 3:0] cen24;
wire [ 1:0] cen48;
wire        cen_12, cen_6, cen_3, cen_1p5; // 24 MHz based

// CPU bus
wire [ 7:0] cpu_dout, ram_dout, snd_latch,
            scr_dout, obj_dout, pal_dout;
wire        cpu_rnw, int_n, v8, h8, snd_irq,
            ram_cs, scrram_cs, objram_cs, pal_cs;
wire [12:0] cpu_addr;

// SDRAM
wire [31:0] char_data, scr_data, obj_data;
wire        main_cs, snd_cs, pcm_cs,
            char_cs, scr_cs, obj_cs;
wire [17:0] obj_addr;
wire [16:0] scr_addr, pcm_addr;
wire [15:0] main_addr;
wire [14:0] snd_addr;
wire [13:0] char_addr;
wire [ 7:0] main_data, pcm_data, snd_data;
wire [ 9:0] scrpos;
wire        main_ok, snd_ok, pcm_ok,
            char_ok, scr_ok, obj_ok;
wire        flip;

assign cen_12     = cen24[0];
assign cen_6      = cen24[1];
assign cen_3      = cen24[2];
assign cen_1p5    = cen24[3];
assign pxl2_cen   = cen48[0];
assign pxl_cen    = cen48[1];
// The game does not write to the SDRAM
assign ba_wr      = 0;
assign ba0_din    = 0;
assign ba0_din_m  = 0;
assign debug_view = 0;
assign dip_flip   = flip;

// The CPUs/sound use the 24 MHz clock
jtframe_frac_cen #( .W( 4), .WC( 2)) u_cen24(
    .clk  ( clk24  ),
    .n    ( 2'd1   ),
    .m    ( 2'd2   ),
    .cen  ( cen24  ),
    .cenb (        )
);

// The video uses the 48 MHz clock
jtframe_frac_cen #( .W( 2), .WC( 4)) u_cen48(
    .clk  ( clk    ),
    .n    ( 4'd1   ),
    .m    ( 4'd4   ),
    .cen  ( cen48  ),
    .cenb (        )
);

jtkunio_main u_main(
    .rst         ( rst          ),
    .clk         ( clk          ),
    .cen_1p5     ( cen_1p5      ),
    .LVBL        ( LVBL         ),
    .v8          ( v8           ),

    .bus_addr    ( cpu_addr     ),
    .cpu_rnw     ( cpu_rnw      ),
    .cpu_dout    ( cpu_dout     ),

    .dip_pause   ( dip_pause    ),
    // video
    .flip        ( flip         ),
    .scrpos      ( scrpos       ),

    .ram_cs      ( ram_cs       ),
    .scrram_cs   ( scrram_cs    ),
    .objram_cs   ( objram_cs    ),
    .pal_cs      ( pal_cs       ),
    .pal_dout    ( pal_dout     ),
    .ram_dout    ( ram_dout     ),
    .scr_dout    ( scr_dout     ),
    .obj_dout    ( obj_dout     ),

    // Sound
    .snd_irq     ( snd_irq      ),
    .snd_latch   ( snd_latch    ),

    .joystick1   ( joystick1[6:0]),
    .joystick2   ( joystick2[6:0]),
    .start       ( start_button ),
    .coin        ( coin_input   ),
    .dipsw_a     ( dipsw[ 7:0]  ),
    .dipsw_b     ( dipsw[15:8]  ),
    .service     ( service      ),

    // ROM
    .rom_addr    ( main_addr    ),
    .rom_cs      ( main_cs      ),
    .rom_data    ( main_data    ),
    .rom_ok      ( main_ok      )
);

`ifndef NOSOUND
jtkunio_sound u_snd(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .cen6       ( cen_6         ),
    .h8         ( h8            ),

    .snd_latch  ( snd_latch     ),
    .snd_irq    ( snd_irq       ),

    .rom_addr   ( snd_addr      ),
    .rom_data   ( snd_data      ),
    .rom_cs     ( snd_cs        ),
    .rom_ok     ( snd_ok        ),

    .pcm_addr   ( pcm_addr      ),
    .pcm_data   ( pcm_data      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_ok     ( pcm_ok        ),

    .peak       ( game_led      ),
    .sample     ( sample        ),
    .sound      ( snd           )
);
`else
    assign sample   = 0;
    assign game_led = 0;
    assign snd      = 0;
    assign pcm_cs   = 0;
    assign snd_cs   = 0;
    assign pcm_addr = 0;
    assign snd_addr = 0;
`endif

jtkunio_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .flip       ( flip          ),
    .h8         ( h8            ),
    .v8         ( v8            ),

    .scrpos     ( scrpos        ),

    .pal_cs     ( pal_cs        ),
    .ram_cs     ( ram_cs        ),
    .scrram_cs  ( scrram_cs     ),
    .objram_cs  ( objram_cs     ),
    .cpu_wrn    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),

    .ram_dout   ( ram_dout      ),
    .scr_dout   ( scr_dout      ),
    .obj_dout   ( obj_dout      ),
    .pal_dout   ( pal_dout      ),

    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_ok    ( char_ok       ),

    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_ok     ( scr_ok        ),

    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_cs     ( obj_cs        ),
    .obj_ok     ( obj_ok        ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        )
);

jtkunio_sdram u_sdram(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .hs         ( HS            ),
    .vs         ( VS            ),

    .main_cs    ( main_cs       ),
    .main_addr  ( main_addr     ),
    .main_data  ( main_data     ),
    .main_ok    ( main_ok       ),

    .snd_addr   ( snd_addr      ),
    .snd_cs     ( snd_cs        ),
    .snd_data   ( snd_data      ),
    .snd_ok     ( snd_ok        ),

    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),

    .char_ok    ( char_ok       ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),

    .scr_ok     ( scr_ok        ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),

    .obj_ok     ( obj_ok        ),
    .obj_cs     ( obj_cs        ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),

    .ba0_addr   ( ba0_addr      ),
    .ba1_addr   ( ba1_addr      ),
    .ba2_addr   ( ba2_addr      ),
    .ba3_addr   ( ba3_addr      ),
    .ba_rd      ( ba_rd         ),
    .ba_ack     ( ba_ack        ),
    .ba_dst     ( ba_dst        ),
    .ba_dok     ( ba_dok        ),
    .ba_rdy     ( ba_rdy        ),
    .data_read  ( data_read     ),

    .downloading( downloading   ),
    .dwnld_busy ( dwnld_busy    ),

    .ioctl_addr ( ioctl_addr    ),
    .ioctl_dout ( ioctl_dout    ),
    .ioctl_wr   ( ioctl_wr      ),

    .prog_addr  ( prog_addr     ),
    .prog_data  ( prog_data     ),
    .prog_mask  ( prog_mask     ),
    .prog_ba    ( prog_ba       ),
    .prog_we    ( prog_we       ),
    .prog_rd    ( prog_rd       ),
    .prog_ack   ( prog_ack      ),
    .prog_rdy   ( prog_rdy      )
);

endmodule