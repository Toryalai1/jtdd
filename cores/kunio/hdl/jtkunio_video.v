/*  This file is part of JTKUNIO.
    JTKUNIO program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKUNIO program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKUNIO.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2019 */


module jtkunio_video(
    input              clk,
    input              rst,
    input              pxl_cen,
    input              pxl2_cen,
    // CPU bus
    input      [12:0]  cpu_addr,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    // Palette
    input              pal_cs,
    output     [ 7:0]  pal_dout,
    // Char
    input              ram_cs,
    output     [ 7:0]  ram_dout,
    output     [13:0]  char_addr,
    input      [31:0]  char_data,
    input              char_ok,
    // Scroll
    input              scrram_cs,
    input      [ 9:0]  scrpos,
    output     [ 7:0]  scr_dout,
    output     [16:0]  scr_addr,
    input      [31:0]  scr_data,
    input              scr_ok,
    // Object
    input              objram_cs,
    output     [ 7:0]  obj_dout,
    output     [17:0]  obj_addr,
    input      [31:0]  obj_data,
    input              obj_ok,    
    output             obj_cs,
    // video signals
    output             HS,
    output             VS,
    output             LVBL,
    output             LHBL,
    input              flip,
    output             h8,
    output             v8,
    // Pixel output
    output     [3:0]   red,
    output     [3:0]   green,
    output     [3:0]   blue,
    // Debug
    input      [3:0]   gfx_en
);

wire [5:0]  char_pxl, scr_pxl, obj_pxl;
wire [8:0]  vdump;
wire [8:0]  vrender;
wire [8:0]  H;
wire        Hinit;
wire        Vinit;

// Easy numbers for now
jtframe_vtimer #(
    .HB_START   ( 9'd255    ),
    .HB_END     ( 9'd383    )
) u_vtimer (
    .clk     ( clk          ),
    .pxl_cen ( pxl_cen      ),
    .vdump   ( vdump        ),
    .vrender ( vrender      ),
    .vrender1(              ),
    .H       ( H            ),
    .Hinit   ( Hinit        ),
    .Vinit   ( Vinit        ),
    .LHBL    ( LHBL         ),
    .LVBL    ( LVBL         ),
    .HS      ( HS           ),
    .VS      ( VS           )
);

assign h8 = H[3];
assign v8 = vdump[3];

jtkunio_char u_char(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    .flip        ( flip             ),

    .cpu_addr    ( cpu_addr         ),
    .ram_cs      ( ram_cs           ),
    .cpu_wrn     ( cpu_wrn          ),
    .cpu_dout    ( cpu_dout         ),
    .cpu_din     ( ram_dout         ),

    .rom_addr    ( char_addr        ),
    .rom_data    ( char_data        ),
    .rom_ok      ( char_ok          ),
    .pxl         ( char_pxl         )
);

jtkunio_scroll u_scroll(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    .flip        ( flip             ),

    .cpu_addr    ( cpu_addr[10:0]   ),
    .scr_cs      ( scrram_cs        ),
    .cpu_wrn     ( cpu_wrn          ),
    .cpu_dout    ( cpu_dout         ),
    .cpu_din     ( scr_dout         ),
    .scrpos      ( scrpos           ),

    .rom_addr    ( scr_addr         ),
    .rom_data    ( scr_data         ),
    .rom_ok      ( scr_ok           ),
    .pxl         ( scr_pxl          )
);

jtkunio_obj u_obj(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    .flip        ( flip             ),

    .cpu_addr    ( cpu_addr[10:0]   ),
    .objram_cs   ( objram_cs        ),
    .cpu_wrn     ( cpu_wrn          ),
    .cpu_dout    ( cpu_dout         ),
    .cpu_din     ( obj_dout         ),

    .rom_addr    ( obj_addr         ),
    .rom_data    ( obj_data         ),
    .rom_cs      ( obj_cs           ),
    .rom_ok      ( obj_ok           ),
    .pxl         ( obj_pxl          )
);

jtkunio_colmix u_colmix(
    .rst         ( rst              ),
    .clk         ( clk              ),
    .pxl_cen     ( pxl_cen          ),

    .LVBL        ( LVBL             ),
    .LHBL        ( LHBL             ),

    .pal_cs      ( pal_cs           ),
    .cpu_wrn     ( cpu_wrn          ),
    .cpu_addr    ( cpu_addr[8:0]    ),
    .cpu_dout    ( cpu_dout         ),
    .pal_dout    ( pal_dout         ),

    .char_pxl    ( char_pxl         ),
    .scr_pxl     ( scr_pxl          ),
    .obj_pxl     ( obj_pxl          ),

    .red         ( red              ),
    .green       ( green            ),
    .blue        ( blue             ),
    .gfx_en      ( gfx_en           )
);

endmodule