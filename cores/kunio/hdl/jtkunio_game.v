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
    input   [ 7:0]  joystick1,
    input   [ 7:0]  joystick2,

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
    output  [ 7:0]  ioctl_din,
    input           ioctl_wr,
    input           ioctl_ram,
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
wire        cen12, cen6, cen3, cen1p5; // 24 MHz based

// CPU bus
wire [ 7:0] cpu_dout, pcm_dout,
            vram_dout, attr_dout, pal_dout;
wire        fm_cs, oki_cs,
            cpu_rnw, busrq, int_n,
            pal_cs, vram_msb, vram_cs, attr_cs;
wire [11:0] cpu_addr;
wire        char_en, obj_en, video_en, pal_bank;
wire        dma_go, busak_n, busrq_n;
wire [ 8:0] h;

// SDRAM
wire [19:0] char_addr;
wire [31:0] char_data;
wire [16:0] obj_addr;
wire [31:0] obj_data;
wire        main_cs, char_cs, obj_cs,
            init_n;
wire [17:0] pcm_addr;
wire [19:0] main_addr;
wire [ 7:0] main_data, pcm_data;
wire        main_ok, obj_ok, pcm_ok, pcm_bank;
wire        flip;

assign cen12      = cen24[0];
assign cen6       = cen24[1];
assign cen3       = cen24[2];
assign cen1p5     = cen24[3];
assign pxl2_cen   = cen48[0];
assign pxl_cen    = cen48[1];
// The game does not write to the SDRAM
assign ba_wr      = 0;
assign ba0_din    = 0;
assign ba0_din_m  = 0;
assign debug_view = 0;
assign dip_flip   = ~flip;

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
    .cpu_cen     ( pxl_cen      ),
    .int_n       ( int_n        ),
    .ctrl_type   ( ctrl_type    ),

    .cpu_addr    ( cpu_addr     ),
    .cpu_rnw     ( cpu_rnw      ),
    .cpu_dout    ( cpu_dout     ),

    .flip        ( flip         ),
    .LVBL        ( LVBL         ),
    .LHBL        ( LHBL         ),
    .hcnt        ( h[2:0]       ),
    .dip_pause   ( dip_pause    ),
    .init_n      ( init_n       ),

    .char_en     ( char_en      ),
    .obj_en      ( obj_en       ),
    .video_enq   ( video_en     ),

    .attr_cs     ( attr_cs      ),
    .vram_cs     ( vram_cs      ),
    .vram_msb    ( vram_msb     ),
    .pal_cs      ( pal_cs       ),
    .pal_bank    ( pal_bank     ),
    .attr_dout   ( attr_dout    ),
    .pal_dout    ( pal_dout     ),
    .vram_dout   ( vram_dout    ),

    // Sound
    .fm_cs       ( fm_cs        ),
    .pcm_cs      ( oki_cs       ),
    .pcm_bank    ( pcm_bank     ),
    .pcm_dout    ( pcm_dout     ),

    // DMA
    .dma_go      ( dma_go       ),
    .busrq_n     ( ~busrq       ),
    .busak_n     ( busak_n      ),

    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    .start_button(start_button  ),
    .coin        ( coin_input[0]),
    .service     ( service      ),
    .test        ( dip_test     ),

    .mouse_1p    ( mouse_1p[7:0]),
    .mouse_2p    ( mouse_2p[7:0]),

    // NVRAM
    .prog_addr   ( ioctl_addr[12:0] ),
    .prog_data   ( ioctl_dout   ),
    .prog_din    ( ioctl_din    ),
    .prog_we     ( ioctl_wr     ),
    .prog_ram    ( ioctl_ram    ),

    .kabuki_we   ( kabuki_we    ),
    .kabuki_en   ( kabuki_en    ),

    .debug_bus   ( debug_bus    ),
    // ROM
    .rom_addr    ( main_addr    ),
    .rom_cs      ( main_cs      ),
    .rom_data    ( main_data    ),
    .rom_ok      ( main_ok      )
);

`ifndef NOSOUND
jtkunio_snd u_snd(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .cen6       ( cen6          ),
    .H8         ( H8            ),

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
    .snd        ( snd           )
);
`else
    assign pcm_addr = 0;
    assign sample   = 0;
    assign game_led = 0;
    assign snd      = 0;
    assign pcm_dout = 0;
`endif

jtkunio_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .int_n      ( int_n         ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .h          ( h             ),
    .flip       ( flip          ),
    .video_en   ( video_en      ),
    .char_en    ( char_en       ),

    .pal_bank   ( pal_bank      ),
    .pal_cs     ( pal_cs        ),
    .vram_msb   ( vram_msb      ),
    .vram_cs    ( vram_cs       ),
    .attr_cs    ( attr_cs       ),
    .wr_n       ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .vram_dout  ( vram_dout     ),
    .attr_dout  ( attr_dout     ),
    .pal_dout   ( pal_dout      ),

    .dma_go     ( dma_go        ),
    .busak_n    ( busak_n       ),
    .busrq      ( busrq         ),

    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_cs    ( char_cs       ),

    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_cs     ( obj_cs        ),
    .obj_ok     ( obj_ok        ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        )
);
/* xxverilator tracing_off */
jtkunio_sdram u_sdram(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),
    .init_n     ( init_n        ),
    .ctrl_type  ( ctrl_type     ),

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

    .char_cs    ( char_cs       ),
    .char_ok    (               ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),

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

    .kabuki_we  ( kabuki_we     ),
    .kabuki_en  ( kabuki_en     ),

    .ioctl_addr ( ioctl_addr    ),
    .ioctl_dout ( ioctl_dout    ),
    .ioctl_wr   ( ioctl_wr      ),
    .ioctl_ram  ( ioctl_ram     ),

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