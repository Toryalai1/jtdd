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
    Date: 30-7-2022 */

module jtkunio_sound(
    input              clk,        // 24 MHz
    input              rst,
    input              cen_1p5,

    input       [ 1:0] start,
    input       [ 1:0] coin,
    input       [ 6:0] joystick1,
    input       [ 6:0] joystick2,
    input       [ 7:0] dipsw_a,
    input       [ 7:0] dipsw_b,
    input              dip_pause,
    // graphics
    output reg  [ 9:0] scrpos,
    output reg         flip,
    // communication with sound CPU
    output reg         snd_irq,
    output reg  [ 7:0] snd_latch,
    // ROM
    output     [15:0]  rom_addr,
    output reg         rom_cs,
    input      [ 7:0]  rom_data,
    input              rom_ok,
);

wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout;
reg  [ 7:0] cpu_din
reg         bank, bank_cs;
wire        rdy;

assign rom_addr = { ~cpu_addr[15], cpu_addr[15] ? cpu_addr[14] : bank, cpu_addr[13:0] };
assign rdy      = ~rom_cs | rom_ok;

always @* begin
    rom_cs = cpu_addr[15:14] >= 1;
    ram_cs = 0;
    objram_cs = 0;
    scrram_cs = 0;
    flip_cs   = 0;
    case( cpu_addr[13:11] )
        0,1,2,3: ram_cs = 1;
        4: objram_cs = 1;
        5: scrram_cs = 1;
        7: begin
            io_cs = 1;
            case( cpu_addr[2:0] )
                0: scrpos0_cs = 1;
                1: scrpos1_cs = 1;
                2: snd_irq = 1;
                3: flip_cs = 1;
                4: main2mcu_cs = 1;
                5: bank_cs = 1;
                6: nmi_clr = 1;
                7: irq_clr = 1;
            endcase
        end
    endcase
end

always @(posedge clk) begin
    case( cpu_addr[1:0] )
        0: cab_dout <= { start, joystick1[5:0] };
        1: cab_dout <= { coin,  joystick2[5:0] };
        2: cab_dout <= dipsw_b;
        3: cab_dout <= dipsw_a;
    endcase
end

always @* begin
    cpu_din = rom_cs    ? rom_data    :
              ram_cs    ? ram_dout    :
              objram_cs ? objram_dout :
              scrram_cs ? scrram_dout :
              io_cs     ? cab_dout    : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank      <= 0;
        snd_latch <= 0;
        scrpos    <= 0;
        flip      <= 0;
    end else begin
        if( bank_cs ) bank <= cpu_dout[0];
        if( snd_irq ) snd_latch <= cpu_dout;
        if( scrpos0_cs ) scrpos[7:0] <= cpu_dout;
        if( scrpos1_cs ) scrpos[9:8] <= cpu_dout[1:0];
        if( flip_cs ) flip <= ~cpu_dout[0];
    end
end

T65 u_cpu(
    .Mode   ( 2'd0      ),  // 6502 mode
    .Res_n  ( ~rst      ),
    .Enable ( cen_1p5   ),
    .Clk    ( clk       ),
    .Rdy    ( rdy       ),
    .Abort_n( 1'b1      ),
    .IRQ_n  ( irqn      ),
    .NMI_n  ( nmin      ),
    .SO_n   ( 1'b1      ),
    .R_W_n  ( cpu_rnw   ),
    .Sync   (           ),
    .EF     (           ),
    .MF     (           ),
    .XF     (           ),
    .ML_n   (           ),
    .VP_n   (           ),
    .VDA    (           ),
    .VPA    (           ),
    .A      ( cpu_addr  ),
    .DI     ( cpu_din   ),
    .DO     ( cpu_dout  )
);

endmodule
