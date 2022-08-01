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
    Date: 30-7-2022 */

module jtkunio_obj(
    input              rst,
    input              clk,
    input              pxl_cen,
    input      [ 7:0]  cpu_addr,
    input              objram_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output     [ 7:0]  cpu_din,
    input              flip,
    // ROM access
    output             rom_cs,
    output reg [17:0]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 5:0]  pxl
);


wire [15:0] scan_dout, vram_dout;
wire        vram_we = objram_cs & ~cpu_wrn;
reg  [ 9:0] scan_addr;

assign pxl = 0;

jtframe_dual_ram #(.aw(8)) u_ram( //
    .clk0   ( clk         ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_addr    ),
    .we0    ( vram_we     ),
    .q0     ( cpu_din     ),

    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan_addr   ),
    .we1    ( 1'b0        ),
    .q1     ( scan_dout   )
);

endmodule