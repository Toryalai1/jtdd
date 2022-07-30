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
    input             clk,        // 24 MHz
    input             rst,
    input             cen6,
    input             h8,
    // communication with main CPU
    input             snd_irq,
    input      [ 7:0] snd_latch,
    // ROM
    output     [14:0] rom_addr,
    output reg        rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    output reg [16:0] pcm_addr,
    output            pcm_cs,
    input      [ 7:0] pcm_data,
    input             pcm_ok,

    // Sound output
    output signed [15:0] sound,
    output               sample,
    output               peak
);

wire        [ 7:0] cpu_dout, ram_dout, fm_dout;
wire        [15:0] A;
reg         [ 7:0] cpu_din;
wire               cpu_rnw, firq_n, irq_n;
reg                ram_cs, latch_cs, fm_cs,
                   pcm_start, pcm_stop, nmi_n,
                   oki_s, pcm_rst;
reg         [13:0] pcm_cnt;
wire               cen_fm, cen_fm2;
wire signed [11:0] pcm_snd;
wire signed [15:0] fm_snd;
wire               pcm_sample;
reg         [ 1:0] pcm_msb;
reg                pcm_s, ctrl_cs;
reg         [ 2:0] pcm_ce;
reg                cen_oki, last_h8, h8_edge, pcm_cen;
wire               cpu_cen;
wire        [ 3:0] pcm_din;

assign rom_addr = A[14:0];
assign pcm_din  = pcm_cnt[0] ? pcm_data[7:4] : pcm_data[3:0];

localparam [7:0] FMGAIN  = 8'h08,
                 PCMGAIN = 8'h10;

jtframe_mixer #(.W0(16),.W1(12)) u_mixer(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cen    ( cen_fm2       ),
    // input signals
    .ch0    ( fm_snd        ),
    .ch1    ( pcm_snd       ),
    .ch2    (               ),
    .ch3    (               ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( FMGAIN        ),
    .gain1  ( PCMGAIN       ),
    .gain2  ( 8'h00         ),
    .gain3  ( 8'h00         ),
    .mixed  ( sound         ),
    .peak   ( peak          )
);

always @(*) begin
    rom_cs    = A[15];
    ram_cs    = 0;
    latch_cs  = 0;
    ctrl_cs   = 0;
    fm_cs     = 0;
    pcm_start = 0;
    pcm_stop  = 0;
    if(!A[15] && !A[14]) case(A[13:11])
        0,1: ram_cs  = 1;
        2: latch_cs  = 1;
        3: pcm_start = 1;
        4: ctrl_cs   = 1;
        5: fm_cs     = 1;
        6: pcm_stop  = 1;
        default:;
    endcase
end

always @(*) begin
    cpu_din = rom_cs   ? rom_data  :
              ram_cs   ? ram_dout  :
              latch_cs ? snd_latch :
              fm_cs    ? fm_dout   :
              8'hff;
end

always @(*) begin
    pcm_addr[14:0] = { pcm_msb, pcm_cnt[13:1] };
    case( pcm_ce )
        1: pcm_addr[16:15]=0;
        2: pcm_addr[16:15]=1;
        4: pcm_addr[16:15]=2;
        default: pcm_addr[16:15]=0;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        oki_s   <= 0;
        pcm_ce  <= 0;
        pcm_msb <= 0;
        pcm_cnt <= 0;
        pcm_rst <= 1;
        nmi_n   <= 1;
    end else begin
        if( ctrl_cs && !cpu_rnw )
            { oki_s, pcm_ce, pcm_msb } <= cpu_dout[5:0];
        if( pcm_start ) begin
            nmi_n   <= 1;
            pcm_cnt <= 0;
            pcm_rst <= 0;
        end else if(pcm_cen) begin
            pcm_cnt <= pcm_cnt + 1'd1;
            if( &pcm_cnt ) begin
                nmi_n   <= 0;
                pcm_rst <= 1;
            end
        end
    end
end

always @(posedge clk) begin
    last_h8 <= h8;
    h8_edge <= h8 && !last_h8;
    cen_oki <= h8_edge;
end

jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( latch_cs    ),    // active high
    .sigedge  ( snd_irq     ) // signal whose edge will trigger the FF
);

jtframe_sys6809 #(.RAM_AW(12)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen6      ),    // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 1.5MHz
    .VMA        (           ),
    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( firq_n    ),
    .nNMI       ( nmi_n     ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( cpu_rnw   ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

jtframe_frac_cen u_fmcen(
    .clk        (  clk                ), // 24 MHz
    .n          ( 10'd105             ),
    .m          ( 10'd704             ),
    .cen        ( { cen_fm2, cen_fm } ),
    .cenb       (                     )
);

jtopl2 u_opl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_fm    ),
    .din    ( cpu_dout  ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm_cs    ),
    .wr_n   ( cpu_rnw   ),
    .dout   ( fm_dout   ),
    .irq_n  ( firq_n    ),
    .snd    ( fm_snd    ),
    .sample ( sample    )
);

jt5205 #(.INTERPOL(0)) u_decod(
    .rst    ( pcm_rst   ),
    .clk    ( clk       ),
    .cen    ( cen_oki   ),
    .sel    ( {1'b0, oki_s } ),
    .din    ( pcm_din   ),
    .sound  ( pcm_snd   ),
    .irq    ( pcm_sample),
    // unused
    .vclk_o ( pcm_cen   ),
    .sample (           )
);

endmodule
