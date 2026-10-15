//============================================================================
//  Arcade: Space Firebird
//
//  Mike Coates 
//
//  version 001 initial release - 2026
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

// Enable overlay (or not) for debugging
//`define DEBUG_MODE

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_OSD + per-pin push-pull mask, USER_IO widened to 8 bits
	output        USER_OSD,
	output  [7:0] USER_PP,
	input   [7:0] USER_IN,
	output  [7:0] USER_OUT,
	// [MiSTer-DB9 END]

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP driven by wrapper; USER_OUT driven by joydb (USER_OUT_DRIVE) below
assign USER_PP = USER_PP_DRIVE;
// [MiSTer-DB9 END]

assign AUDIO_S   = 1;
assign AUDIO_MIX = 0;

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
assign FB_FORCE_BLANK = 0;
assign VGA_DISABLE = 0;

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? ((status[2])  ? 8'd121 : 8'd91) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2])  ? 8'd91 : 8'd121) : 12'd0;

wire iRST = RESET | ioctl_download | status[0] | buttons[1];

`include "build_id.v" 
localparam CONF_STR = {
	"A.FIREBIRD;;",
   "OOR,CRT H adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
   "OSV,CRT V adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"H1O6,Flip,Off,On;",
	"O7,Pause,Off,On;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
	"O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
	"O[125],UserIO Players, 1 Player,2 Players;",
	// [MiSTer-DB9-Pro END]
	"DIP;",
	"-;",
`ifdef DEBUG_MODE
	"OB,Debug display,Off,On;",
	"-;",
`endif
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Start 1P,Start 2P,Coin;",
	"jn,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_vid, clk_cpu, clk_mem, clk_snd;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),			// 20.00 Mhz
	.outclk_1(clk_sys), 			// 32.00 Mhz
	.outclk_2(clk_cpu), 			//  4.00 Mhz
	.outclk_3(clk_mem),			// 80.00 Mhz
	.outclk_4(clk_snd),			//  6.00 Mhz
	.locked(pll_locked)
);

///////////////////////////////////////////////////

// [MiSTer-DB9 BEGIN] - widened to 128 bits for joy_type at [127:126] and joy_2p at [125]
wire [127:0] status;
// [MiSTer-DB9 END]
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;
wire [15:0] joy1, joy2;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [21:0] gamma_bus;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
// SNAC cores: replace 1'b0 with the core's SNAC enable expression so SNAC
// preempts the joydb wrapper on shared USER_IO pins. Default 1'b0 is no-op.
wire         snac_active     = 1'b0;
// MT32-pi cores on primary USER_IO: replace 1'b0 with the core's MT32-active
// expression (e.g. `mt32_use` under `ifndef SECOND_MT32`, `~mt32_disable` for
// TRS-80's inverted polarity). Suppresses the OSD-open autodetect probe so it
// doesn't read the RPi's I2C master traffic as a ghost Saturn signature.
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;
// Programmable-remap matrix (joydb_remap inside joydb): clk_sys carries the
// 0xFD selector load (HPS-bus domain). joydb_*_mapped are the MiSTer-standard
// joystick words the core consumes at its joy0_USB merge point. db9_remap_*
// are driven by the hps_io instance (see the .db9_remap_* bindings there).
// Until a core consumes joydb_*_mapped (Layer B), the matrix stays at identity
// and synthesis prunes it -- binding these is dormant + fleet-safe.
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;

// [MiSTer-DB9 BEGIN] - DB9 remap factory default (used until Main_MiSTer streams UIO 0xFD)
// Derived from CONF_STR J1, same rule as db9_map.cpp; lets the core work on a stock MiSTer binary.
// DB15:  Fire 1=A, Fire 2=B, Start 1P=START, Start 2P=D, Coin=SELECT
// DB9MD: Fire 1=B, Fire 2=C, Start 1P=START, Start 2P=X, Coin=MODE
wire  [35:0] db9_remap_default_db15  = 36'hFFFFB7A54;
wire  [35:0] db9_remap_default_db9md = 36'hFFFFB7A65;
// [MiSTer-DB9 END]
joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_sys            ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .remap_cmd       ( db9_remap_cmd      ),
  .remap_byte_cnt  ( db9_remap_byte_cnt ),
  .remap_din       ( db9_remap_din      ),
  .remap_default_db15  ( db9_remap_default_db15  ),
  .remap_default_db9md ( db9_remap_default_db9md ),
  .joydb_1_mapped  ( joydb_1_mapped     ),
  .joydb_2_mapped  ( joydb_2_mapped     ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: rename USB joystick wires
wire [31:0] joystick_0_USB, joystick_1_USB;
// [MiSTer-DB9 END]

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({1'd0,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB),
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
	.joy_raw(joy_raw_payload),
	// programmable remap matrix selector load (UIO_DB9_MAP 0xFD)
	.db9_remap_cmd(db9_remap_cmd),
	.db9_remap_byte_cnt(db9_remap_byte_cnt),
	.db9_remap_din(db9_remap_din),
	// [MiSTer-DB9 END]
	// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
	.saturn_unlocked(saturn_unlocked)
	// [MiSTer-DB9-Pro END]
);

// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open
// joydb_*_mapped is already in MiSTer-standard J1 order, identical to the USB
// joystick word, so it replaces the USB input as-is.
assign joy1 = joydb_1ena ? (OSD_STATUS ? 16'b0 : joydb_1_mapped) : joystick_0_USB;
assign joy2 = joydb_2ena ? (OSD_STATUS ? 16'b0 : joydb_2_mapped) : joydb_1ena ? joystick_0_USB : joystick_1_USB;
// [MiSTer-DB9-Pro END]

localparam mod_firebird = 0;
localparam mod_demon    = 1;

reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

// Dip switches from MRA file
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


// Combined buttons
wire B1_S = joy1[6];
wire B2_S = joy1[7];
wire B1_C = joy1[8];

wire B1_B = joy1[5];
wire B1_A = joy1[4];
wire B1_U = joy1[3];
wire B1_D = joy1[2];
wire B1_L = joy1[1];
wire B1_R = joy1[0];

wire B2_B = joy2[5];
wire B2_A = joy2[4];
wire B2_U = joy2[3];
wire B2_D = joy2[2];
wire B2_L = joy2[1];
wire B2_R = joy2[0];

// Autocoin option 

wire m_start1;
wire m_start2;
wire m_coin1;

autocoin #(
	.count(64000),
	.delay(2))
autocoin (
  .i_clk(clk_cpu),
  .i_coin(B1_C),
  .i_start1(B1_S),
  .i_start2(B2_S),
  .o_coin(m_coin1),
  .o_start1(m_start1),
  .o_start2(m_start2),
  .enable(sw[1][0])
);

wire hblank, vblank;
wire hs, vs;
wire [8:0] HCount;
wire [8:0] VCount;
wire [7:0] r,g,b;

wire [ 3:0] hoffset, voffset;
assign { voffset, hoffset } = status[31:24];

wire no_rotate = status[2] | direct_video;
wire rotate_ccw = 1;
wire flip = 0;
wire video_rotated;
wire io_flip = status[6];
wire pause_req = status[7];

wire pix_ena;
wire [1:0] pix_cnt;

video_timing VIDEO_TIMING
(
	.RESET(iRST),
	.clk(clk_vid),
	.HOFFSET(hoffset),
	.VOFFSET(voffset),
	.pix_clk(pix_ena),
	.pixcount(pix_cnt),
	.hcnt(HCount),
	.vcnt(VCount),
	.hsync(hs),
	.vsync(vs),
	.hblank(hblank),
	.vblank(vblank)
);

screen_rotate screen_rotate (.*);

arcade_video #(512,24) arcade_video
(
	.*,

	.clk_video(clk_vid),
	.ce_pix(pix_ena),

`ifdef DEBUG_MODE
	.RGB_in(rgb_ovo),
`else
	.RGB_in({r,g,b}),
`endif
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);

wire [15:0] audio;

SPACEFIREBIRD bird 
(
	.I_Firebird(mod == mod_firebird),
	.I_Bullet(sw[1][1]),
	.I_Song(mod == mod_firebird ? 1'b0 : sw[1][2]),

	.O_VIDEO_R(r),
	.O_VIDEO_G(g),
	.O_VIDEO_B(b),
	
	.I_HCOUNT(HCount),
	.I_VCOUNT(VCount),
	.I_FLIP(io_flip),

	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr && !ioctl_index),
	.dn_ld(ioctl_download),

	.SAMPLE_CTL(sample_ctrl),
	.O_AUDIO(audio),

	.in0({B1_A,1'b0,1'b0,B1_B,1'b0,1'b0,B1_L,B1_R}),
	.in1({B2_A,1'b0,1'b0,B2_B,1'b0,1'b0,B2_L,B2_R}),
	.in2({~m_coin1,1'b0,1'b0,1'b0,m_start2,m_start1,1'd0,1'd0}),
	.dipsw1(sw[1][0] ? {2'd0,sw[0][5:4],2'd0,sw[0][1:0]} : {2'd0,sw[0][5:0]}),

// debug display fields
`ifdef DEBUG_MODE	
	.PCADDR(PC),
	.PCDATA(DT),
	.O_FLIP(sflip),
`endif	

	.I_PAUSE(pause_req),
	.RESET(iRST),
	.I_PIX(pix_cnt),
	
	.CPU_CLK(clk_cpu),
	.VID_CLK(clk_vid),
	.SND_CLK(clk_snd),
	.SYS_CLK(clk_sys)
);

////////////////////////////  Samples   ///////////////////////////////////

reg  [27:0] wav_addr;
wire [15:0] wav_data_o;
wire        wav_want_byte;
wire [5:0]  sample_ctrl;

reg  Ready_L;
wire Ready;
reg  [15:0] wav_data;


sdram sdram
(
		 .*,
		 .init(~pll_locked),
		 .clk(clk_mem),

		 .addr(ioctl_download ? ioctl_addr : {wav_addr[24:1],1'd0}),
		 .we(ioctl_download && ioctl_wr && (ioctl_index == 6)),
		 .rd(~ioctl_download & wav_want_byte),
		 .din(ioctl_dout),
		 .dout(wav_data_o),

		 .ready(Ready)
);


always @(posedge clk_mem)
begin
         Ready_L <= Ready;
         // on Ready set keep data
         if(Ready && ~Ready_L) wav_data <= wav_data_o;
end

// Link to Samples module

samples samples
(
	.audio_enabled(1'd1),
	.audio_port_0({4'd0,sample_ctrl}),	
	.audio_port_1(8'd0),

	.wave_addr(wav_addr),        
	.wave_read(wav_want_byte),   
	.wave_data({wav_data,wav_data}),

	.samples_ok(),

	.dl_addr(ioctl_addr),
	.dl_wr(ioctl_wr),
	.dl_data(ioctl_dout),
	.dl_download(ioctl_download && (ioctl_index == 5)),
	
	.CLK_SYS(clk_sys),
	.clock(clk_mem),
	.reset(iRST),
	
	.audio_in(audio),
	.audio_out_L(AUDIO_L),
	.audio_out_R(AUDIO_R)
);


//--
//-- Debug
//--

`ifdef DEBUG_MODE

// For putting characters in at position POS
`define LC(POS, VAL) Line1[POS*5+4:POS*5] <= VAL;

// for putting nibbles in at position POS
`define L4(POS, VAL) Line1[POS*5+3:POS*5] <= VAL;

// for putting 8 bit numbers in at position POS and POS+1
`define L8(POS, VAL) Line1[POS*5+3:POS*5] <= VAL[7:4]; Line1[POS*5+8:POS*5+5] <= VAL[3:0];

// for putting 16 bit numbers in at position POS to POS+3
`define L16(POS, VAL) Line1[POS*5+3:POS*5] <= VAL[15:12]; Line1[POS*5+8:POS*5+5] <= VAL[11:8]; Line1[POS*5+13:POS*5+10] <= VAL[7:4]; Line1[POS*5+18:POS*5+15] <= VAL[3:0];

reg [23:0] rgb_ovo;
reg [149:0] Line1,Line2;

ovo OVERLAY
(
    .i_r(r),
    .i_g(g),
    .i_b(b),
    .i_clk(clk_vid),
	 .i_pix(pix_ena),
	 
	 .i_Hcount(HCount),
	 .i_VCount(VCount),

    .o_r(rgb_ovo[23:16]),
    .o_g(rgb_ovo[15:8]),
    .o_b(rgb_ovo[7:0]),
    .ena(status[11]),

    .in0(Line1),
    .in1(Line2)
);

wire [15:0] PC;
wire [7:0] DT;
wire sflip;

always @(posedge clk_sys)
begin
	`LC(0,5'b10000)
	`L16(1,PC)
	`LC(5,5'b10000)
	`L8(6,DT)
	`LC(8,5'b10000)
	`L4(9,{3'b000,sflip})
	`LC(10,5'b10000)	
end	

`endif

		 
endmodule

