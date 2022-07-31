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

module jtkunio_scroll(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              flip,
    input      [ 8:0]  h,
    input      [ 7:0]  v,

    input      [10:0]  cpu_addr,
    input              scr_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output     [ 7:0]  cpu_din,
    input      [ 9:0]  scrpos,
    // ROM access
    output     [16:0]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,
    output reg [ 5:0]  pxl
);

wire [15:0] scan_dout, vram_dout;
wire [ 1:0] vram_we = { cpu_addr[10], ~cpu_addr[10] } & {2{scr_cs & ~cpu_wrn}};
wire [ 9:0] scan_addr;
wire [ 9:0] hsum;
reg  [ 3:0] rom_msb;
reg  [ 2:0] code_msb, cur_pal, pal;
reg  [ 7:0] code;
reg  [15:0] plane0;
reg  [47:0] pxl_data;
wire        lower;

assign hsum      = scrpos + { h[8], h };
assign cpu_din   = cpu_addr[10] ? vram_dout[15:8] : vram_dout[7:0];
assign scan_addr = { v[7:4], hsum[9:4] };
assign rom_addr  = { rom_msb, code, v[3:0], 1'b0 }; // 4+8+4+1=17
assign pxl       = { cur_pal, pxl_data[24], pxl_data[16], pxl_data[0] };
assign lower     = code_msb[1:0]==0 || code_msb[1:0]==1;

always @* begin
    case( {hsum[3], code_msb} )
        4'o00: rom_msb = 0;
        4'o10: rom_msb = 2;
        4'o01: rom_msb = 0;
        4'o11: rom_msb = 3;

        4'o02: rom_msb = 1;
        4'o12: rom_msb = 4;
        4'o03: rom_msb = 1;
        4'o13: rom_msb = 5;

        4'o04: rom_msb = 6;
        4'o14: rom_msb = 8;
        4'o05: rom_msb = 6;
        4'o15: rom_msb = 9;

        4'o06: rom_msb = 7;
        4'o16: rom_msb = 10;
        4'o07: rom_msb = 7;
        4'o17: rom_msb = 11;
    endcase
end

always @(posedge clk) if(pxl_cen) begin
    if( hsum[2:0]==7 ) begin
        if( !hsum[3] )
            plane0 <= lower ? { rom_data[27:24], rom_data[19:16], rom_data[11: 8], rom_data[3:0] } :
                              { rom_data[31:28], rom_data[23:20], rom_data[15:12], rom_data[7:4] };
        else begin
            pal     <= scan_dout[15:13];
            cur_pal <= pal;
            { code_msb, code } <= scan_dout[10:0];
            pxl_data          <= {
                { rom_data[31:28], rom_data[23:20], rom_data[15:12], rom_data[7:4] }, // plane 2
                { rom_data[27:24], rom_data[19:16], rom_data[11: 8], rom_data[3:0] }, // plane 1
                plane0
            };
        end
    end
    if( hsum[3:0]!=15 ) begin
        pxl_data <= pxl_data>>1;
    end
end

jtframe_dual_ram16 #(.aw(10)) u_ram( // 2kB
    .clk0   ( clk         ),
    .data0  ({2{cpu_dout}}),
    .addr0  (cpu_addr[9:0]),
    .we0    ( vram_we     ),
    .q0     ( vram_dout   ),

    .clk1   ( clk         ),
    .data1  ( 16'd0       ),
    .addr1  ( scan_addr   ),
    .we1    ( 2'b0        ),
    .q1     ( scan_dout   )
);

endmodule