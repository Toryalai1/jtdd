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


module jtdd_timing(
    input              clk,
    input              rst,
    (*direct_enable*) input cen12,
    input              flip,
    output reg [7:0]   VPOS=8'd0, // VPOS in schematics
    output     [7:0]   HPOS, // HPOS in schematics
    output reg         VBL=1'b0,
    output reg         HBL=1'b0,
    output reg         VS,
    output reg         HS,
    output     [5:0]   M       // *M in schematics, *M represents ~M
);

reg [8:0] hn;
reg [7:0] vn;
reg [7:0]  m;
wire hover = hn==9'd383;
wire [8:0] nextn = hover ? 9'd0 : hn+9'd1;
reg aux = 1'b0;

always @(posedge clk) begin
    VPOS <= vn ^ flip;
end

assign M = m[5:0];
assign HPOS = hn[7:0] ^ {8{flip}};

always @(posedge clk) if(cen12) begin
    // bus phases
    m  <= 8'd0;
    if( nextn[0] ) m[nextn[3:1]] <= 1'b1;
    // counters
    hn <= nextn;
    if( hn[8:0] == 9'd255 ) begin
        HBL <= 1'b1;
    end else if( hover )begin
        HBL <= 1'b0;
        if( &vn ) begin
            vn <= VBL ? 8'he8 : 8'h8;
        end else begin
            vn <= vn + 8'd1;
            if( vn == 8'hF5 ) begin
                VBL <= 1'b1;
                aux <= VBL;
            end
            if( vn == 8'hfe && aux ) VBL <= 1'b0;
        end
    end
end


endmodule