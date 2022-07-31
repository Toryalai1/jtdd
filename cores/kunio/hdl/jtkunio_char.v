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

module jtkunio_char(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              flip,
    input      [ 7:0]  h,
    input      [ 7:0]  v,

    input      [12:0]  cpu_addr,
    input              ram_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output     [ 7:0]  cpu_din,
    // ROM access
    output     [13:0]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 4:0]  pxl
);

wire [15:0] scan_dout, ram_dout;
wire [ 1:0] ram_we = { cpu_addr[0], ~cpu_addr[0] } & {2{ram_cs & ~cpu_wrn}};
reg  [ 9:0] code;
wire [ 9:0] scan_addr;
reg  [23:0] pxl_data;
reg  [ 1:0] pal, cur_pal;

assign cpu_din   = cpu_addr[0] ? ram_dout[15:8] : ram_dout[7:0];
assign scan_addr = { v[7:3], h[7:3] };
assign rom_addr  = { code, v[2:0], 1'b0 }; // 10+3+1 = 14
assign pxl       = { cur_pal, pxl_data[12], pxl_data[6], pxl_data[0] };

function [5:0] swap_bits( input [7:0] a);
    swap_bits = { a[6], a[7], a[4], a[5], a[2], a[3] };
endfunction

always @(posedge clk) if(pxl_cen) begin
    if( h[2:0]==0 ) begin
        code <= scan_dout[9:0];
        pal  <= scan_dout[15:14];
        cur_pal <= pal;
        pxl_data <= {swap_bits(rom_data[31:24]),
                     swap_bits(rom_data[23:16]),
                     swap_bits(rom_data[15: 8]),
                     swap_bits(rom_data[ 7: 0])};
    end else begin
        pxl_data <= pxl_data >> 1;
    end
end

jtframe_dual_ram16 #(
    .aw           ( 12          ),
    .simfile_lo   ("char_lo.bin"),
    .simfile_hi   ("char_hi.bin")
) u_ram( // 2kB
    .clk0   ( clk           ),
    .data0  ({2{cpu_dout}}  ),
    .addr0  (cpu_addr[12:1] ),
    .we0    ( ram_we        ),
    .q0     ( ram_dout      ),

    .clk1   ( clk           ),
    .data1  ( 16'd0         ),
    .addr1  ({2'b11,scan_addr}),
    .we1    ( 2'b0          ),
    .q1     ( scan_dout     )
);

endmodule