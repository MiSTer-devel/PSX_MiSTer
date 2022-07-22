//============================================================================
//  PSX
//  Copyright (C) 2019 Robert Peip
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
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

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

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
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign HDMI_FREEZE = 1'b0;

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[8:7];

assign LED_USER  = exe_download | bk_pending;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [11:0] DisplayWidth;
wire [11:0] DisplayHeight;
wire [ 9:0] DisplayOffsetX;
wire [ 8:0] DisplayOffsetY;

assign FB_BASE    = status[11] ? 32'h30000000 : (32'h30000000 + (DisplayOffsetX * 2) + (DisplayOffsetY * 2048));
assign FB_EN      = status[14];
assign FB_FORMAT  = status[10] ? 5'b00101 : 5'b01100;
assign FB_WIDTH   = status[11] ? 12'd1024 : DisplayWidth;
assign FB_HEIGHT  = status[11] ? 12'd512  : DisplayHeight;
assign FB_STRIDE  = 14'd2048;
assign FB_FORCE_BLANK = 0;


///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire pll_locked;
wire clk_1x;
wire clk_2x;
wire clk_3x;
wire clk_vid;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_1x),
	.outclk_1(clk_2x),
	.outclk_2(clk_3x),
	.locked(pll_locked)
);

pll2 pll2
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
   .reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);


wire FFrequest = joy[17] && ~FB_LL && ~DIRECT_VIDEO;
wire syncVideoOut = status[57] && ~FB_LL && ~DIRECT_VIDEO;
wire syncVideoClock = status[56] && ~FB_LL && ~DIRECT_VIDEO;

always @(posedge CLK_50M) begin : cfg_block
	reg pald = 0, pald2 = 0;
	reg pdbg = 0, pdbg2 = 0; 
	reg pffw = 0, pffw2 = 0;
	reg [3:0] state = 0;

	pald  <= isPal;
	pald2 <= pald;

	pdbg  <= syncVideoClock;
	pdbg2 <= pdbg;

	pffw  <= fast_forward;
	pffw2 <= pffw;

	cfg_write <= 0;
	if(pald2 != pald || pdbg2 != pdbg || pffw2 != pffw) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
         3: begin
					cfg_address <= 5;
					cfg_data <= pffw2 ? 131842 : pdbg2 ? 771 : 1028;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= pffw2 ? 2147483648 : pdbg2 ? 551954751 : pald2 ? 2201376898 : 2537930535;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

reg fast_forward;
reg ff_latch;

always @(posedge clk_1x) begin : ffwd
	reg last_ffw;
	reg ff_was_held;
	longint ff_count;

	last_ffw <= FFrequest;

	if (FFrequest)
		ff_count <= ff_count + 1;

	if (~last_ffw & FFrequest) begin
		ff_latch <= 0;
		ff_count <= 0;
	end

	if ((last_ffw & ~FFrequest)) begin
		ff_was_held <= 0;

		if (ff_count < 10000000 && ~ff_was_held) begin
			ff_was_held <= 1;
			ff_latch <= 1;
		end
	end

	fast_forward <= (FFrequest | ff_latch);
end

wire reset_or = RESET | buttons[1] | status[0] | bios_download | exe_download | cdDownloadReset;

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6            7         8         9
// 01234567890123456789012345678901 23456789012345678901234567890123 45678901234567890123456789012345
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV 
//  X XXXXXXXXX  XXXXXXXXXXX XXXXXX XXXXXXXXXXXXXXXXXXXXXXXXXXXXX XX XXXXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"PSX;SS3E000000:400000;",
	"H7S1,CUECHD,Load CD;",
	"h7-,Reload core for CD;",
	"F1,EXE,Load Exe;",
	"-;",
	"d6C,Cheats;",
	"h6O[6],Cheats Enabled,Yes,No;",
	"-;",
	"hA-,Memcard Status: not saved;",
	"HB-,Memcard Status: saved;",
	"hC-,Memcard Status: saving...;",
	"RD,Save Memory Cards;",
	"O[71],Save to SDCard,On Open OSD,Manual;",
	"SC2,SAVMCD,Mount Memory Card 1;",
	"SC3,SAVMCD,Mount Memory Card 2;",
	"O[63],Automount Memory Card 1,Yes,No;",
	"-;",
	"O[36],Savestates to SDCard,On,Off;",
	"O[68],Autoincrement Slot,Off,On;",
	"O[38:37],Savestate Slot,1,2,3,4;",
	"RH,Save state (Alt-F1);",
	"RI,Restore state (F1);",
	"-;",
	"O[40:39],System Type,Auto,NTSC-U,NTSC-J,PAL;",
	"-;",
	"D8O[48:45],Pad1,Dualshock,Off,Digital,Analog,GunCon,NeGcon,Wheel-NegCon,Wheel-Analog,Mouse,Justifier,SNAC-port1,Analog Joystick;",
	"D8O[52:49],Pad2,Dualshock,Off,Digital,Analog,GunCon,NeGcon,Wheel-NegCon,Wheel-Analog,Mouse,Justifier,SNAC-port2,Analog Joystick;",
	"D8h2O[9],Show Crosshair,Off,On;",
	"D8h4O[31],DS Mode,L3+R3+Up/Dn | Click,L1+L2+R1+R2+Up/Dn;",
	"O[66],Multitap,Off,Port1: 4 x Digital;",
	"-;",
	"O[28],FPS Overlay,Off,On;",
	"O[29],Error Overlay,On,Off;",
	"O[59],CD Slow Overlay,Off,On;",
	"h9O[70],CD Overlay,Read,Read+Seek;",
	"-;",

	"P1,Video & Audio;",
	"P1-;",
	"P1O[33:32],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[35:34],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1O[62],Fixed HBlank,On,Off;",
	"P1O[55],Fixed VBlank,Off,On;",
	"d5P1O[4:3],Vertical Crop,Off,On(224/270),On(216/256);",
	"P1O[67],Horizontal Crop,Off,On;",
	"P1O[22],Dithering,On,Off;",
	"P1O[41],Deinterlacing,Weave,Bob;",
	"P1O[60],Sync 480i for HDMI,Off,On;",
	"P1O[24],Rotate,Off,On;",
	"P1O[54:53],Widescreen Hack,Off,3:2,5:3,16:9;",
	"P1O[5],Texture Filter,Off,On;",
	"P1O[73],Dither 24 Bit for VGA,Off,On;",
	"P1-;",
	"d1P1O[44],SPU RAM select,DDR3,SDRAM2;",
	"P1O[8:7],Stereo Mix,None,25%,50%,100%;",

	"P2,Miscellaneous;",
	"P2-;",
	"P2O[16],Fastboot,Off,On;",
	"P2O[42],CD Lid,Closed,Open;",
	"P2O[64],Pause when OSD open,On,Off;",
	"P2-;",
	"P2-,(U) = unsafe -> can crash;",
	"P2O[21],CD Fast Seek,Off,On(U);",
	"P2O[58],Turbo(Cheats Off),Off,On(U);",
	"P2O[72],Pause when CD slow,On,Off(U);",
	"P2O[15],PAL 60Hz Hack,Off,On(U);",
	
	"h3-;",
	"h3P3,Debug;",
	"h3P3-;",
	"h3P3O[14],DDR3 Framebuffer,Off,On;",
	"h3P3O[10],DDR3 FB Color,16,24;",
	"h3P3O[11],VRAMViewer,Off,On;",
	"h3P3O[57],Sync Video Out,Off,On;",
	"h3P3O[56],Sync Video Clock,Off,On;",
	"h3P3O[30],Sound,On,Off;",
	"h3P3O[19],RepTimingGPU,Off,On;",
	"h3P3O[20],RepTimingDMA,Off,On;",
	"h3P3O[43],RepTimingSPUDMA,Off,On;",
	"h3P3O[26],DMAinBLOCKs,Off,On;",
	"h3P3O[27],Textures,On,Off;",
	"h3P3O[69],LBA Overlay,Off,On;",
	"h3P3T1,Advance Pause;",

	"-   ;",
	"R0,Reset;",
	"J1,Triangle,Circle,Cross,Square,Select,Start,L1,R1,L2,R2,L3,R3,Savestates,Fastforward,Pause(Core),Toggle Dualshock;",
	"jn,Triangle,Circle,Cross,Square,Select,Start,L1,R1,L2,R2,L3,R3,X,X;",
	"I,",
	"Load=DPAD Up|Save=Down|Slot=L+R,",
	"Active Slot 1,",
	"Active Slot 2,",
	"Active Slot 3,",
	"Active Slot 4,",
	"Save to state 1,",
	"Restore state 1,",
	"Save to state 2,",
	"Restore state 2,",
	"Save to state 3,",
	"Restore state 3,",
	"Save to state 4,",
	"Restore state 4,",
	"Rewinding...,",
	"Slot 1 Analog,",
	"Slot 1 Digital,",
	"Slot 2 Analog,",
	"Slot 2 Digital,",
	"Region Unknown->US,",
	"Region JP,",
	"Region US,",
	"Region EU,",
	"Saving Memcard;",
	"V,v",`BUILD_DATE
};

reg dbg_enabled = 0;
wire  [1:0] buttons;
wire [127:0] status;
wire [15:0] status_menumask = {saving_memcard, (bk_pending | saving_memcard), bk_pending, status[59], multitap, biosMod, ~status[58], status[55], (PadPortDS1 | PadPortDS2), dbg_enabled, (PadPortGunCon1 | PadPortGunCon2 | PadPortJustif1 | PadPortJustif2), SDRAM2_EN, 1'b0};
wire        forced_scandoubler;
reg  [31:0] sd_lba0 = 0;
reg  [31:0] sd_lba1;
reg  [ 6:0] sd_lba2;
reg  [ 6:0] sd_lba3;
reg   [3:0] sd_rd;
reg   [3:0] sd_wr;
wire  [3:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din2;
wire [15:0] sd_buff_din3;
wire        sd_buff_wr;
wire  [3:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        ioctl_download;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 0;

wire [19:0] joy;
wire [19:0] joy_unmod;
wire [19:0] joy2;
wire [19:0] joy3;
wire [19:0] joy4;

wire [10:0] ps2_key;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

wire [15:0] joystick_analog_l0;
wire [15:0] joystick_analog_r0;
wire [15:0] joystick_analog_l1;
wire [15:0] joystick_analog_r1;
wire [15:0] joystick_analog_l2;
wire [15:0] joystick_analog_r2;
wire [15:0] joystick_analog_l3;
wire [15:0] joystick_analog_r3;

wire [24:0] mouse;

wire [15:0] joystick1_rumble;
wire [15:0] joystick2_rumble;
wire [15:0] joystick3_rumble;
wire [15:0] joystick4_rumble;
wire [32:0] RTC_time;

wire [127:0] status_in = {status[127:39],ss_slot,status[36:19], 2'b00, status[16:0]};

wire bk_pending;
wire DIRECT_VIDEO;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(4), .BLKSZ(3)) hps_io
(
	.clk_sys(clk_1x),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(EXT_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_unmod),
	.joystick_1(joy2),
	.joystick_2(joy3),
	.joystick_3(joy4),
	.ps2_key(ps2_key),

	.status(status),
	.status_in(status_in),
	.status_set(statusUpdate),
	.status_menumask(status_menumask),
	.info_req(psx_info_req),
	.info(psx_info),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.sd_lba('{sd_lba0, sd_lba1, sd_lba2, sd_lba3}),
	.sd_blk_cnt('{0,0, 0, 0}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{0, 0, sd_buff_din2, sd_buff_din3}),
	.sd_buff_wr(sd_buff_wr),

	.TIMESTAMP(RTC_time),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus),

   .joystick_l_analog_0(joystick_analog_l0),
   .joystick_r_analog_0(joystick_analog_r0),  
   .joystick_l_analog_1(joystick_analog_l1),
   .joystick_r_analog_1(joystick_analog_r1),
   .ps2_mouse(mouse),
   .joystick_0_rumble(paused ? 16'h0000 : joystick1_rumble),
   .joystick_1_rumble(paused ? 16'h0000 : joystick2_rumble),
   
   .direct_video(DIRECT_VIDEO)
);

assign joy = joy_unmod[16] ? 20'b0 : joy_unmod;

assign sd_rd[0] = 0;
assign sd_wr[0] = 0;

assign sd_wr[1] = 0;

wire [35:0] EXT_BUS;

//////////////////////////  ROM DETECT  /////////////////////////////////

reg bios_download, exe_download, cdinfo_download, code_download;
always @(posedge clk_1x) begin
	bios_download    <= ioctl_download & (ioctl_index[5:0] == 0);
	exe_download     <= ioctl_download & (ioctl_index == 1);
	cdinfo_download  <= ioctl_download & (ioctl_index == 251);
	code_download    <= ioctl_download & (ioctl_index == 255);
end

reg cart_loaded = 0;
always @(posedge clk_1x) begin
	if (exe_download || img_mounted[1]) begin
		cart_loaded <= 1;
	end
end

localparam EXE_START = 4194304;
localparam BIOS_START = 2097152;

reg [26:0] ramdownload_wraddr;
reg [31:0] ramdownload_wrdata;
reg        ramdownload_wr;

reg        hasCD = 0;

reg exe_download_1 = 0;
reg cdinfo_download_1 = 0;
reg loadExe = 0;

reg sd_mounted2 = 0;
reg sd_mounted3 = 0;

reg memcard1_load = 0;
reg memcard2_load = 0;
reg memcard_save = 0;

wire saving_memcard;

reg memcard1_inserted = 0;
reg memcard2_inserted = 0;
reg [25:0] memcard1_cnt = 0;
reg [25:0] memcard2_cnt = 0;

wire bk_save     = status[13];
wire bk_autosave = ~status[71];

reg old_save = 0; 
reg old_save_a = 0;

wire bk_save_a = OSD_STATUS & bk_autosave;

reg cdbios = 0;
reg  [1:0] region;
reg  [1:0] biosregion;
wire [1:0] region_out;
reg        isPal;
reg biosMod = 0;

always @(posedge clk_1x) begin
	ramdownload_wr <= 0;
	if(exe_download | bios_download | cdinfo_download) begin
      if (ioctl_wr) begin
         if(~ioctl_addr[1]) begin
            ramdownload_wrdata[15:0] <= ioctl_dout;
            if (bios_download)         ramdownload_wraddr  <= {6'd1, ioctl_index[7:6], ioctl_addr[18:0]};
            else if (exe_download)     ramdownload_wraddr  <= ioctl_addr[20:0] + EXE_START[26:0];                              
            else if (cdinfo_download)  ramdownload_wraddr  <= ioctl_addr[26:0];      
         end else begin
            ramdownload_wrdata[31:16] <= ioctl_dout;
            ramdownload_wr            <= 1;
            ioctl_wait                <= 1;
            if (cdinfo_download) ioctl_wait <= 0;
         end
      end
      if(sdramCh3_done) ioctl_wait <= 0;
   end else begin 
      ioctl_wait <= 0;
	end
   exe_download_1  <= exe_download;
   loadExe         <= exe_download_1 & ~exe_download;  

   if (loadExe) biosMod <= 1'b1;
     
   if (img_mounted[1]) begin
      if (img_size > 0) begin
         hasCD     <= 1;
      end else begin
         hasCD     <= 0;
      end
   end
  
   case(status[40:39])
      0: begin
            case(region_out)
               0: begin region = 2'b00; isPal <= 0; end   // unknown => default to NTSC          
               1: begin region = 2'b01; isPal <= 0; end   // JP
               2: begin region = 2'b00; isPal <= 0; end   // US
               3: begin region = 2'b10; isPal <= 1; end   // EU
            endcase
         end
      1: begin region = 2'b00; isPal <= 0; end
      2: begin region = 2'b01; isPal <= 0; end
      3: begin region = 2'b10; isPal <= 1; end
	endcase
   
   if (bios_download && ioctl_index[7:6] == 2'b11) cdbios <= 1'b1;
   
   if (cdbios)
      biosregion <= 2'b11;
   else
      biosregion <= region;
   
   memcard1_load <= 0;
   memcard2_load <= 0;
   memcard_save <= 0;
   
   // memcard 1
   if (img_mounted[2]) begin
      memcard1_inserted <= 0;
      memcard1_cnt      <= 26'd0;
      if (img_size > 0) begin
         sd_mounted2       <= 1;
         memcard1_load     <= 1;
      end else begin
         sd_mounted2       <= 0;
      end
   end
   
   if (sd_mounted2) begin // delay memcard inserted for ~2 seconds on card change
      if (memcard1_cnt[25]) begin
         memcard1_inserted <= 1;
      end else begin
         memcard1_cnt <= memcard1_cnt + 1'd1;
      end
   end
   
   // memcard 2
   if (img_mounted[3]) begin
      memcard2_inserted <= 0;
      memcard2_cnt      <= 26'd0;
      if (img_size > 0) begin
         sd_mounted3   <= 1;
         memcard2_load <= 1;
      end else begin
         sd_mounted3 <= 0;
      end
   end
   
   if (sd_mounted3) begin
      if (memcard2_cnt[25]) begin
         memcard2_inserted <= 1;
      end else begin
         memcard2_cnt <= memcard2_cnt + 1'd1;
      end
   end
   
	old_save   <= bk_save;
	old_save_a <= bk_save_a;
   
   if ((~old_save & bk_save) | (~old_save_a & bk_save_a)) memcard_save <= 1;
   
end

///////////////////////////  SAVESTATE  /////////////////////////////////

wire [1:0] ss_slot;
wire [7:0] ss_info;
wire ss_save, ss_load, ss_info_req;
wire statusUpdate;

savestate_ui savestate_ui
(
	.clk            (clk_1x        ),
	.ps2_key        (ps2_key[10:0] ),
	.allow_ss       (cart_loaded   ),
	.joySS          (joy_unmod[16] ),
	.joyRight       (joy_unmod[0]  ),
	.joyLeft        (joy_unmod[1]  ),
	.joyDown        (joy_unmod[2]  ),
	.joyUp          (joy_unmod[3]  ),
	.joyRewind      (0             ),
	.rewindEnable   (0             ), 
	.status_slot    (status[38:37] ),
	.autoincslot    (status[68]    ),
	.OSD_saveload   (status[18:17] ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (ss_info_req   ),
	.ss_info        (ss_info       ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 25;

////////////////////////////  PAD  ///////////////////////////////////

// 0000 -> DualShock
// 0001 -> off
// 0010 -> digital
// 0011 -> analog
// 0100 -> Namco GunCon lightgun
// 0101 -> Namco NeGcon
// 0110 -> Wheel Negcon
// 0111 -> Wheel Analog
// 1000 -> mouse
// 1001 -> Konami Justifier lightgun
// 1010 -> SNAC
// 1011 -> Analog Joystick
// 1100..1111 -> reserved

wire PadPortDS1      = (status[48:45] == 4'b0000);
wire PadPortEnable1  = (status[48:45] != 4'b0001);
wire PadPortDigital1 = (status[48:45] == 4'b0010);
wire PadPortAnalog1  = (status[48:45] == 4'b0011) || (status[48:45] == 4'b0111);
wire PadPortGunCon1  = (status[48:45] == 4'b0100);
wire PadPortNeGcon1  = (status[48:45] == 4'b0101) || (status[48:45] == 4'b0110);
wire PadPortWheel1   = (status[48:45] == 4'b0110) || (status[48:45] == 4'b0111);
wire PadPortMouse1   = (status[48:45] == 4'b1000);
wire PadPortJustif1  = (status[48:45] == 4'b1001);
wire snacPort1       = (status[48:45] == 4'b1010) && ~multitap;
wire PadPortStick1   = (status[48:45] == 4'b1011);
   
wire PadPortDS2      = (status[52:49] == 4'b0000);
wire PadPortEnable2  = (status[52:49] != 4'b0001) && ~multitap;
wire PadPortDigital2 = (status[52:49] == 4'b0010);
wire PadPortAnalog2  = (status[52:49] == 4'b0011) || (status[52:49] == 4'b0111);
wire PadPortGunCon2  = (status[52:49] == 4'b0100);
wire PadPortNeGcon2  = (status[52:49] == 4'b0101) || (status[52:49] == 4'b0110);
wire PadPortWheel2   = (status[52:49] == 4'b0110) || (status[52:49] == 4'b0111);
wire PadPortMouse2   = (status[52:49] == 4'b1000);
wire PadPortJustif2  = (status[52:49] == 4'b1001);
wire snacPort2       = (status[52:49] == 4'b1010) && ~multitap;
wire PadPortStick2   = (status[52:49] == 4'b1011);

wire multitap       = status[66];

wire [1:0] padMode;
reg  [1:0] padMode_1;

reg [7:0] psx_info;
reg psx_info_req;

wire resetFromCD;
reg  cdDownloadReset = 0;

reg [3:0] ToggleDS = 0;
reg [3:0] joy19_1 = 0;

always @(posedge clk_1x) begin

   psx_info_req <= 0;
   padMode_1    <= padMode;
   
   cdinfo_download_1 <= cdinfo_download;

   if (ss_info_req) begin
      psx_info_req <= 1;
      psx_info     <= ss_info;
   end else if (saving_memcard) begin
      psx_info_req <= 1;
      psx_info     <= 8'd23;
   end else if (padMode_1[0] != padMode[0] && ~multitap) begin
      psx_info_req <= 1;
      if (padMode[0])  psx_info <= 8'd15;
      if (!padMode[0]) psx_info <= 8'd16;
   end else if (padMode_1[1] != padMode[1] && ~multitap) begin
      psx_info_req <= 1;
      if (padMode[1])  psx_info <= 8'd17;
      if (!padMode[1]) psx_info <= 8'd18;
   end else if (cdinfo_download_1 && ~cdinfo_download) begin
      if (status[40:39] == 2'b00) begin
         psx_info_req <= 1;
         case(region_out)
            0: begin psx_info <= 8'd19; end   // unknown => default to NTSC          
            1: begin psx_info <= 8'd20; end   // JP
            2: begin psx_info <= 8'd21; end   // US
            3: begin psx_info <= 8'd22; end   // EU
         endcase
      end
   end
   
   cdDownloadReset <= 0;
   if (cdinfo_download_1 && ~cdinfo_download && resetFromCD) begin
      cdDownloadReset <= 1;
   end
   
   if (joy[14] && joy[15] && joy[8]) dbg_enabled <= 1;  // L3+R3+Select
   
   // DS toggle
   joy19_1 <= {joy4[19] ,joy3[19] ,joy2[19] ,joy[19] };
   ToggleDS[0] <=  joy[19] & ~joy19_1[0];
   ToggleDS[1] <= joy2[19] & ~joy19_1[1];
   ToggleDS[2] <= joy3[19] & ~joy19_1[2];
   ToggleDS[3] <= joy4[19] & ~joy19_1[3];

end

////////////////////////////  PAUSE and RESET  ///////////////////////////
reg paused = 0;
reg [9:0] unpause = 0;
reg status1_1;
wire isPaused;

reg reset = 0;

reg buttonpause_1 = 0;
reg button_paused = 0;

always @(posedge clk_1x) begin

   paused <= 0;

   // pause from OSD open
   if (~status[64] & OSD_STATUS & (unpause == 0)) begin
      paused <= 1;
   end
   
   // pause from button
   buttonpause_1 <= joy[18];
   if (joy[18] & ~buttonpause_1) begin
      button_paused <= ~button_paused;
   end
   if (button_paused) begin
      paused <= 1;
   end
   
   // Advance Pause OSD trigger
   status1_1 <= status[1];
   if (status[1] & ~status1_1) begin
      unpause <= 1023;
   end else if (unpause > 0) begin
      unpause <= unpause - 1'd1;
   end
   
   // reset
   reset <= 0;
   if (reset_or) begin
      reset    <= 1;
   end

end

////////////////////////////  SYSTEM  ///////////////////////////////////

psx_mister
psx
(
   .clk1x(clk_1x),          
   .clk2x(clk_2x),
   .clkvid(clk_vid),
   .reset(reset),
   .isPaused(isPaused),
   // commands 
   .pause(paused),
   .loadExe(loadExe),
   .fastboot(status[16]),
   .FASTMEM(0),
   .TURBO(status[58]),
   .REPRODUCIBLEGPUTIMING(status[19]),
   .REPRODUCIBLEDMATIMING(status[20]),
   .DMABLOCKATONCE(status[26]),
   .INSTANTSEEK(status[21]),
   .ditherOff(status[22]),
   .showGunCrosshairs(status[9]),
   .fpscountOn(status[28]),
   .cdslowOn(status[59]),
   .testSeek(status[70]),
   .pauseOnCDSlow(~status[72]),
   .errorOn(~status[29]),
   .LBAOn(status[69]),
   .PATCHSERIAL(0), //.PATCHSERIAL(status[54]),
   .noTexture(status[27]),
   .textureFilter(status[5]),
   .dither24(status[73]),
   .syncVideoOut(syncVideoOut),
   .syncInterlace(status[60]),
   .rotate180(status[24]),
   .fixedVBlank(status[55]),
   .vCrop(status[4:3]),
   .hCrop(status[67]),
   .SPUon(~status[30]),
   .SPUSDRAM(status[44] & SDRAM2_EN),
   .REVERBOFF(0),
   .REPRODUCIBLESPUDMA(status[43]),
   .WIDESCREEN(status[54:53]),
   // RAM/BIOS interface      
   .biosregion(biosregion),
   .ram_refresh(sdr_refresh),
   .ram_dataWrite(sdr_sdram_din),
   .ram_dataRead(sdr_sdram_dout),
   .ram_dataRead32(sdr_sdram_dout32),
   .ram_Adr(sdram_addr),
   .ram_be(sdram_be), 
   .ram_rnw(sdram_rnw),  
   .ram_ena(sdram_req), 
   .ram_128(sdram_128), 
   .ram_done(sdram_ack),
   .ram_idle(sdram_idle),
   .ram_reqprocessed(sdram_reqprocessed),
   // vram/ddr3
   .DDRAM_BUSY      (DDRAM_BUSY      ),
   .DDRAM_BURSTCNT  (DDRAM_BURSTCNT  ),
   .DDRAM_ADDR      (DDRAM_ADDR      ),
   .DDRAM_DOUT      (DDRAM_DOUT      ),
   .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
   .DDRAM_RD        (DDRAM_RD        ),
   .DDRAM_DIN       (DDRAM_DIN       ),
   .DDRAM_BE        (DDRAM_BE        ),
   .DDRAM_WE        (DDRAM_WE        ),
   // cd
   .region          (region),
   .region_out      (region_out),
   .hasCD           (hasCD),
   .LIDopen         (status[42]),
   .fastCD          (0),
   .trackinfo_data  (ramdownload_wrdata),
   .trackinfo_addr  (ramdownload_wraddr[10:2]),
   .trackinfo_write (ramdownload_wr && cdinfo_download),
   .resetFromCD     (resetFromCD),
   .cd_hps_req      (sd_rd[1]),  
   .cd_hps_lba      (sd_lba1),  
   .cd_hps_ack      (sd_ack[1]),
   .cd_hps_write    (sd_buff_wr),
   .cd_hps_data     (sd_buff_dout), 
   // spuram
   .spuram_dataWrite(spuram_dataWrite),
   .spuram_Adr      (spuram_Adr      ),
   .spuram_be       (spuram_be       ),
   .spuram_rnw      (spuram_rnw      ),
   .spuram_ena      (spuram_ena      ),
   .spuram_dataRead (spuram_dataRead ),
   .spuram_done     (spuram_done     ),
   // memcard
   .memcard_changed (bk_pending),
   .saving_memcard  (saving_memcard),
   .memcard1_load   (memcard1_load),
   .memcard2_load   (memcard2_load),
   .memcard_save    (memcard_save),
   .memcard1_mounted   (sd_mounted2),
   .memcard1_available (memcard1_inserted),
   .memcard1_rd     (sd_rd[2]),
   .memcard1_wr     (sd_wr[2]),
   .memcard1_lba    (sd_lba2),
   .memcard1_ack    (sd_ack[2]),
   .memcard1_write  (sd_buff_wr),
   .memcard1_addr   (sd_buff_addr[8:0]),
   .memcard1_dataIn (sd_buff_dout),
   .memcard1_dataOut(sd_buff_din2),    
   .memcard2_mounted   (sd_mounted3),
   .memcard2_available (memcard2_inserted),   
   .memcard2_rd     (sd_rd[3]),
   .memcard2_wr     (sd_wr[3]),
   .memcard2_lba    (sd_lba3),
   .memcard2_ack    (sd_ack[3]),
   .memcard2_write  (sd_buff_wr),
   .memcard2_addr   (sd_buff_addr[8:0]),
   .memcard2_dataIn (sd_buff_dout),
   .memcard2_dataOut(sd_buff_din3), 
   // video
   .videoout_on     (~status[14]),
   .isPal           (isPal),
   .pal60           (status[15]),
   .hsync           (hs),
   .vsync           (vs),
   .hblank          (hbl),
   .vblank          (vbl),
   .DisplayWidth    (DisplayWidth), 
   .DisplayHeight   (DisplayHeight),
   .DisplayOffsetX  (DisplayOffsetX),
   .DisplayOffsetY  (DisplayOffsetY),
   .video_ce        (ce_pix),
   .video_interlace (video_interlace),
   .video_r         (r),
   .video_g         (g),
   .video_b         (b),
   .video_isPal     (video_isPal),   
   .video_hResMode  (video_hResMode),
   //Keys
   .DSAltSwitchMode(status[31]),
   .PadPortEnable1 (PadPortEnable1),
   .PadPortDigital1(PadPortDigital1),
   .PadPortAnalog1 (PadPortAnalog1),
   .PadPortMouse1  (PadPortMouse1 ),
   .PadPortGunCon1 (PadPortGunCon1),
   .PadPortNeGcon1 (PadPortNeGcon1),
   .PadPortWheel1  (PadPortWheel1),
   .PadPortDS1     (PadPortDS1),
   .PadPortJustif1 (PadPortJustif1),
   .PadPortStick1  (PadPortStick1),
   .PadPortEnable2 (PadPortEnable2),
   .PadPortDigital2(PadPortDigital2),
   .PadPortAnalog2 (PadPortAnalog2),
   .PadPortMouse2  (PadPortMouse2 ),
   .PadPortGunCon2 (PadPortGunCon2),
   .PadPortNeGcon2 (PadPortNeGcon2),
   .PadPortWheel2  (PadPortWheel2),
   .PadPortDS2     (PadPortDS2),
   .PadPortJustif2 (PadPortJustif2),
   .PadPortStick2  (PadPortStick2),
   .KeyTriangle({joy4[4], joy3[4], joy2[4], joy[4] }),
   .KeyCircle  ({joy4[5] ,joy3[5] ,joy2[5] ,joy[5] }),
   .KeyCross   ({joy4[6] ,joy3[6] ,joy2[6] ,joy[6] }),
   .KeySquare  ({joy4[7] ,joy3[7] ,joy2[7] ,joy[7] }),
   .KeySelect  ({joy4[8] ,joy3[8] ,joy2[8] ,joy[8] }),
   .KeyStart   ({joy4[9] ,joy3[9] ,joy2[9] ,joy[9] }),
   .KeyRight   ({joy4[0] ,joy3[0] ,joy2[0] ,joy[0] }),
   .KeyLeft    ({joy4[1] ,joy3[1] ,joy2[1] ,joy[1] }),
   .KeyUp      ({joy4[3] ,joy3[3] ,joy2[3] ,joy[3] }),
   .KeyDown    ({joy4[2] ,joy3[2] ,joy2[2] ,joy[2] }),
   .KeyR1      ({joy4[11],joy3[11],joy2[11],joy[11]}),
   .KeyR2      ({joy4[13],joy3[13],joy2[13],joy[13]}),
   .KeyR3      ({joy4[15],joy3[15],joy2[15],joy[15]}),
   .KeyL1      ({joy4[10],joy3[10],joy2[10],joy[10]}),
   .KeyL2      ({joy4[12],joy3[12],joy2[12],joy[12]}),
   .KeyL3      ({joy4[14],joy3[14],joy2[14],joy[14]}),
   .ToggleDS   (ToggleDS),
   .Analog1XP1(joystick_analog_l0[7:0]),       
   .Analog1YP1(joystick_analog_l0[15:8]),       
   .Analog2XP1(joystick_analog_r0[7:0]),           
   .Analog2YP1(joystick_analog_r0[15:8]),    
   .Analog1XP2(joystick_analog_l1[7:0]),       
   .Analog1YP2(joystick_analog_l1[15:8]),       
   .Analog2XP2(joystick_analog_r1[7:0]),           
   .Analog2YP2(joystick_analog_r1[15:8]),           
   .Analog1XP3(joystick_analog_l2[7:0]),
   .Analog1YP3(joystick_analog_l2[15:8]),
   .Analog2XP3(joystick_analog_r2[7:0]),
   .Analog2YP3(joystick_analog_r2[15:8]),
   .Analog1XP4(joystick_analog_l3[7:0]),
   .Analog1YP4(joystick_analog_l3[15:8]),
   .Analog2XP4(joystick_analog_r3[7:0]),
   .Analog2YP4(joystick_analog_r3[15:8]),
   .RumbleDataP1(joystick1_rumble),
   .RumbleDataP2(joystick2_rumble),
   .RumbleDataP3(joystick3_rumble),
   .RumbleDataP4(joystick4_rumble),
   .padMode(padMode),
   .MouseEvent(mouse[24]),
   .MouseLeft(mouse[0]),
   .MouseRight(mouse[1]),
   .MouseX({mouse[4],mouse[15:8]}),
   .MouseY({mouse[5],mouse[23:16]}),
   .multitap(multitap),
   //snac
   .snacPort1(snacPort1),
   .snacPort2(snacPort2),
   .selectedPort1Snac(selectedPort1Snac),
   .selectedPort2Snac(selectedPort2Snac),
   .irq10Snac(irq10Snac),
   .transmitValueSnac(transmitValueSnac),
   .clk9Snac(clk9Snac),
   .receiveBufferSnac(receiveBufferSnac),
   .beginTransferSnac(beginTransferSnac),
   .actionNextSnac(actionNextSnac),
   .receiveValidSnac(receiveValidSnac),
   .ackSnac(~ack),//using real ack not the 1 cycle ack
	
   //sound       
	.sound_out_left(AUDIO_L),
	.sound_out_right(AUDIO_R),
   //savestates
   .increaseSSHeaderCount (!status[36]),
   .save_state            (ss_save),
   .load_state            (ss_load),
   .savestate_number      (ss_slot),
   .state_loaded          (),
   .rewind_on             (0), //(status[27]),
   .rewind_active         (0), //(status[27] & joy[15]),
   //cheats
   .cheat_clear(gg_reset),
   .cheats_enabled(~status[6] && ~status[58] && ~ioctl_download),
   .cheat_on(gg_valid),
   .cheat_in(gg_code),
   .cheats_active(gg_active),

   .Cheats_BusAddr(cheats_addr),
   .Cheats_BusRnW(cheats_rnw),
   .Cheats_BusByteEnable(cheats_be),
   .Cheats_BusWriteData(cheats_dout),
   .Cheats_Bus_ena(cheats_ena),
   .Cheats_BusReadData(cheats_din),
   .Cheats_BusDone(sdramCh3_done)
);

////////////////////////////  MEMORY  ///////////////////////////////////

localparam ROM_START = (65536+131072)*4;

wire         sdr_refresh;
wire  [31:0] sdr_sdram_din;
wire [127:0] sdr_sdram_dout;
wire  [31:0] sdr_sdram_dout32;
wire [127:0] sdr_sdram_dout2;
wire  [15:0] sdr_bram_din;
wire         sdr_sdram_ack;
wire         sdr_bram_ack;
wire  [22:0] sdram_addr;
wire   [3:0] sdram_be;
wire         sdram_req;
wire         sdram_ack;
wire         sdram_idle;
wire         sdram_reqprocessed;
wire         sdram_readack;
wire         sdram_readack2;
wire         sdram_writeack;
wire         sdram_writeack2;
wire         sdram_rnw;
wire         sdram_128;

wire [20:0] cheats_addr;
wire cheats_rnw;
wire [3:0] cheats_be;
wire [31:0] cheats_dout;
wire cheats_ena;
wire [31:0] cheats_din;
wire sdramCh3_done;

assign sdram_ack = sdram_readack | sdram_writeack;

sdram sdram
(
   .SDRAM_DQ   (SDRAM_DQ),
   .SDRAM_A    (SDRAM_A),
   .SDRAM_DQML (SDRAM_DQML),
   .SDRAM_DQMH (SDRAM_DQMH),
   .SDRAM_BA   (SDRAM_BA),
   .SDRAM_nCS  (SDRAM_nCS),
   .SDRAM_nWE  (SDRAM_nWE),
   .SDRAM_nRAS (SDRAM_nRAS),
   .SDRAM_nCAS (SDRAM_nCAS),
   .SDRAM_CKE  (SDRAM_CKE),
   .SDRAM_CLK  (SDRAM_CLK),
   
   .SDRAM_EN(1),
	.init(~pll_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),
	
	.refreshForce(sdr_refresh),
	.ram_idle(sdram_idle),

	.ch1_addr(sdram_addr),
	.ch1_din(),
	.ch1_dout(sdr_sdram_dout),
	.ch1_dout32(sdr_sdram_dout32),
	.ch1_req(sdram_req & sdram_rnw),
	.ch1_rnw(1'b1),
	.ch1_128(sdram_128),
	.ch1_ready(sdram_readack),
	.ch1_reqprocessed(sdram_reqprocessed),

	.ch2_addr (sdram_addr),
	.ch2_din  (sdr_sdram_din),
	.ch2_dout (),
	.ch2_req  (sdram_req & ~sdram_rnw),
	.ch2_rnw  (1'b0),
	.ch2_be   (sdram_be),
	.ch2_ready(sdram_writeack),

	.ch3_addr ((exe_download | bios_download) ? ramdownload_wraddr : cheats_addr),
	.ch3_din  ((exe_download | bios_download) ? ramdownload_wrdata : cheats_dout),
	.ch3_dout (cheats_din),
	.ch3_req  ((exe_download | bios_download) ? ramdownload_wr     : cheats_ena),
	.ch3_rnw  (cheats_rnw),
	.ch3_be   ((exe_download | bios_download) ? 4'b1111            : cheats_be),
	.ch3_ready(sdramCh3_done)
);

wire [31:0] spuram_dataWrite;
wire [18:0] spuram_Adr;
wire  [3:0] spuram_be;
wire        spuram_rnw;
wire        spuram_ena;
wire [31:0] spuram_dataRead;
wire        spuram_done;

assign spuram_dataRead = sdr_sdram_dout2[31:0];
assign spuram_done     = sdram_readack2 | sdram_writeack2;

`ifdef MISTER_DUAL_SDRAM

sdram sdram2
(
	.SDRAM_DQ   (SDRAM2_DQ),
   .SDRAM_A    (SDRAM2_A),
   .SDRAM_DQML (),
   .SDRAM_DQMH (),
   .SDRAM_BA   (SDRAM2_BA),
   .SDRAM_nCS  (SDRAM2_nCS),
   .SDRAM_nWE  (SDRAM2_nWE),
   .SDRAM_nRAS (SDRAM2_nRAS),
   .SDRAM_nCAS (SDRAM2_nCAS),
   .SDRAM_CKE  (),
   .SDRAM_CLK  (SDRAM2_CLK),
   .SDRAM_EN   (SDRAM2_EN),

	.init(~pll_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),
	
	.refreshForce(1'b0),
	.ram_idle(),

	.ch1_addr(spuram_Adr),
	.ch1_din(),
	.ch1_dout(sdr_sdram_dout2),
	.ch1_req(spuram_ena & spuram_rnw),
	.ch1_rnw(1'b1),
	.ch1_128(1'b0),
	.ch1_ready(sdram_readack2),
	.ch1_reqprocessed(),

	.ch2_addr (spuram_Adr),
	.ch2_din  (spuram_dataWrite),
	.ch2_dout (),
	.ch2_req  (spuram_ena & ~spuram_rnw),
	.ch2_rnw  (1'b0),
   .ch2_be   (spuram_be),
	.ch2_ready(sdram_writeack2),

	.ch3_addr(0),
	.ch3_din(),
	.ch3_dout(),
	.ch3_req(1'b0),
	.ch3_rnw(1'b1),
	.ch3_ready()
);

`else

wire SDRAM2_EN = 0;

assign sdr_sdram_dout2 = '0;
assign sdram_readack2 = '0;
assign sdram_writeack2 = '0;

`endif


assign DDRAM_CLK = clk_2x;

////////////////////////////  VIDEO  ////////////////////////////////////

assign CLK_VIDEO = clk_vid;

wire hs, vs, hbl, vbl, video_interlace, video_isPal;

wire [2:0] video_hResMode;

wire ce_pix;
wire [7:0] r,g,b;

//video_mixer #(.LINE_LENGTH(800), .GAMMA(1)) video_mixer
//(
//	.*,
//	.hq2x(scale==1),
//	.HSync (hs),
//	.VSync (vs),
//	.HBlank(hbl),
//	.VBlank(vbl),
//	.R(r),
//	.G(g),
//	.B(b)
//);

typedef struct {
	logic [7:0] red;
	logic [7:0] green;
	logic [7:0] blue;
	logic       hs;
	logic       vs;
	logic       hb;
	logic       vb;
	logic       interlace;
} vid_info;

vid_info video;

assign CE_PIXEL = ce_pix;
assign VGA_R    = video.red;
assign VGA_G    = video.green;
assign VGA_B    = video.blue;
assign VGA_VS   = video.vs;
assign VGA_HS   = video.hs;
assign VGA_DE   = ~(video.vb | video.hb);
assign VGA_F1 = status[14] ? 1'b0 : (video.interlace & ~status[41]);
assign VGA_SL = 0;
logic [11:0] aspect_x, aspect_y;

wire [1:0] ar = status[33:32];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? ((status[54:53] == 1) ? 3 : (status[54:53] == 2) ? 5 : (status[54:53] == 3) ? 16 : status[11] ? 12'd2 : aspect_x) : (ar - 1'd1)),
	.ARY((!ar) ? ((status[54:53] == 1) ? 2 : (status[54:53] == 2) ? 3 : (status[54:53] == 3) ?  9 : status[11] ? 12'd1 : aspect_y) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[35:34])
);

// Res  Div Padding
// 256  10  +25
// 320  8   +32
// 368  7   +37
// 512  5   +51
// 640  4   +64

localparam reg [23:0] aspect_ratio_lut_ntsc[128] = '{
    24'h37015B, 24'h2B4113, 24'h1A10A7, 24'hEB45EF, 24'hA00411, 24'hF8365B, 24'hA31435, 24'h6A42C3, 
    24'h85D381, 24'hF8F691, 24'h581257, 24'h1860A7, 24'hFD56D4, 24'h6EF303, 24'h497202, 24'hDA1601, 
    24'hF8D6E6, 24'h8513B7, 24'hB014F3, 24'h3C51B5, 24'h3971A3, 24'hC02583, 24'hD09606, 24'h4E1245, 
    24'hFEF776, 24'hC555D0, 24'hBD559D, 24'hE686E1, 24'hF7C771, 24'hC4F5F4, 24'h655315, 24'hB5158B, 
    24'h2C015B, 24'h1750B9, 24'hC74637, 24'hF857CB, 24'h89B459, 24'h800411, 24'hC87668, 24'hA21536, 
    24'hFB3820, 24'h443238, 24'hE17761, 24'hFD3856, 24'h207113, 24'h204113, 24'h3941EB, 24'hE6F7C8, 
    24'h28015B, 24'hD55745, 24'hD21733, 24'hE9F810, 24'hC0A6AD, 24'h99955A, 24'hA0359D, 24'h7FF482, 
    24'hD5B792, 24'hE5C82F, 24'hF558C9, 24'h35D1F0, 24'h6EF404, 24'h93155A, 24'h5BF35D, 24'h9F75DD, 
    24'h6E0411, 24'h2DF1B5, 24'h44D292, 24'h1160A7, 24'hB4F6D4, 24'hD49810, 24'hD057F1, 24'h91B595, 
    24'hB006C7, 24'hF959A6, 24'hE338D6, 24'hC1378D, 24'hC557C0, 24'hF579B0, 24'h7E1500, 24'hABD6D9, 
    24'hFE3A2E, 24'hD3D886, 24'h54736A, 24'hFF3A5E, 24'hE19935, 24'hF42A03, 24'h356233, 24'hFEBA8B, 
    24'h957637, 24'hEFAA03, 24'h43F2DA, 24'hA6F70A, 24'h20015B, 24'h24D191, 24'h72E4E9, 24'hC1E853, 
    24'hDC097D, 24'hD09909, 24'hFE8B13, 24'hD5E959, 24'hFEFB31, 24'h2B81EB, 24'h8A5620, 24'h2B91F0, 
    24'h2AF1EB, 24'hD3F982, 24'hED9AB4, 24'h163101, 24'h724531, 24'hDCBA12, 24'hC50907, 24'hFB7B92, 
    24'h580411, 24'hFDDBC7, 24'hAA77F1, 24'hD259D7, 24'h2ED233, 24'h2431B5, 24'hC1992B, 24'h20F191, 
    24'h7665A7, 24'h42D334, 24'hD09A0A, 24'hF17BAB, 24'hFFFC6B, 24'h6B653B, 24'h5153FA, 24'hFD9C73 
};                                                                                                  
                                                                                                       
localparam reg [23:0] aspect_ratio_lut_pal[160] = '{                                                   
    24'hE8F4D9, 24'h41015D, 24'h40815D, 24'h8EB30A, 24'hF8D557, 24'h1C009B, 24'h1CB0A0, 24'h473190,    
    24'h711280, 24'hCEF49C, 24'hD734D4, 24'hCAC495, 24'h4791A1, 24'hF695A7, 24'hC7549A, 24'hC31489, 
    24'hAEB417, 24'hB8C45B, 24'hA2C3DD, 24'hBCF484, 24'hD2E513, 24'hC2A4B7, 24'hEFF5DA, 24'h85D349, 
    24'h18809B, 24'h0C9050, 24'hF59626, 24'hE595C9, 24'h35C15D, 24'hF81655, 24'h0EC061, 24'hEA160D, 
    24'h68D2BA, 24'hD735A2, 24'h4731E0, 24'hE9A631, 24'hDC35DF, 24'h6D12ED, 24'h96D412, 24'hB87502, 
    24'hCFF5AE, 24'h73732C, 24'hF1D6AF, 24'h7CA377, 24'h30C15D, 24'hA7A4B7, 24'h5C629D, 24'h3941A1, 
    24'h4A221F, 24'hF5B712, 24'hD5F631, 24'h8ED428, 24'h8BC417, 24'hE236A8, 24'hA854FB, 24'hEAE6FD, 
    24'hD73670, 24'hD5666B, 24'hFD97AB, 24'hA8751F, 24'hCDA649, 24'hCE1655, 24'h5C92DC, 24'h3BC1DB, 
    24'hAEB574, 24'hB5A5B3, 24'hFE8807, 24'h2B015D, 24'h13009B, 24'hB6F5DC, 24'hA5E557, 24'hC7D677, 
    24'hD1A6D1, 24'h099050, 24'hEF37DB, 24'hB8C619, 24'h25B140, 24'h4FD2A9, 24'hE1978E, 24'hD7373E, 
    24'h28515D, 24'hE437C1, 24'hD35737, 24'hF4D866, 24'hF97899, 24'h42724D, 24'h5572F9, 24'h27015D, 
    24'hCF0745, 24'h6D83DD, 24'hFFB910, 24'hE35818, 24'hEB2869, 24'hB1565F, 24'hF3F8CE, 24'hE05822, 
    24'h10A09B, 24'hEFF8C7, 24'h9E35D0, 24'h87B502, 24'hBAF6EE, 24'hD7D809, 24'hD7380C, 24'hF59939, 
    24'h2E31BE, 24'hE0B883, 24'h6B8417, 24'h93F5A7, 24'h09E061, 24'hE3B8C6, 24'hBCE74F, 24'h2FC1DB, 
    24'h22F15D, 24'h818513, 24'h5ED3BB, 24'hFF3A15, 24'h5AB399, 24'hB52737, 24'hF0199A, 24'hEE5992, 
    24'hBDB7A6, 24'hC74811, 24'h3FD298, 24'h77F4E5, 24'h4552D7, 24'h1390CE, 24'hE4D973, 24'h25B190, 
    24'h91960F, 24'hBBD7D9, 24'h20815D, 24'h788513, 24'h20415D, 24'h9BF69E, 24'h8EB614, 24'h8435A7, 
    24'hF8DAAE, 24'h9B26AF, 24'h0E009B, 24'h8EA631, 24'h1CB140, 24'h1B112F, 24'hD05925, 24'hD1F940, 
    24'h89060F, 24'hD7098B, 24'h88060F, 24'h4172ED, 24'hD739A8, 24'hDBE9E7, 24'h656495, 24'hFF8B97, 
    24'hD1A98B, 24'hA6D79F, 24'hB4E84B, 24'hEC7AE1, 24'hFF1BC7, 24'h5C944A, 24'hC31912, 24'hEE8B21 
};

logic [11:0] h_pos, v_pos, vb_pos, v_total;
logic [11:0] hb_start_lut[8];
logic [11:0] hb_end_lut[8];
logic [11:0] hb_start, hb_end;

// FIXME: this should be adjusted if hsync changes size to maintain center
assign hb_start_lut = '{12'd63,  12'd50,  12'd36,  12'd31,  12'd24,  12'd0, 12'd0, 12'd0};
assign hb_end_lut =   '{12'd767, 12'd613, 12'd441, 12'd383, 12'd305, 12'd0, 12'd0, 12'd0};

always_comb begin
	hb_start = hb_start_lut[video_hResMode];
	hb_end = hb_end_lut[video_hResMode];
end

always_ff @(posedge CLK_VIDEO) if (CE_PIXEL) begin
	logic old_vb;
	old_vb <= vbl;
	video.hs <= hs;
	video.vs <= vs;
	video.vb <= vbl;
	video.interlace <= video_interlace;
	video.red <= (vbl || hbl) ? 8'd0 : r;
	video.green <= (vbl || hbl) ? 8'd0 : g;
	video.blue <= (vbl || hbl) ? 8'd0 : b;
	{aspect_x, aspect_y} <= video_isPal ? aspect_ratio_lut_pal[v_total] : aspect_ratio_lut_ntsc[v_total];

	VGA_DISABLE <= fast_forward;

	h_pos <= h_pos + 1'd1;
	if (~old_vb && vbl)
		vb_pos <= 0;

	if (video.hs && ~hs) begin
		h_pos <= 0;
		if (~vbl)
			v_pos <= v_pos + 1'd1;
		else
			vb_pos <= vb_pos + 1'd1;
	end
	
	if (~video.vs && vs) begin
		v_pos <= 0;

		if (v_pos < 128)
			v_total <= 6'd0;
		else if (video_isPal && v_pos > 287)
			v_total <= 8'd159;		
		else if (~video_isPal && v_pos > 255)
			v_total <= 7'd127;
		else
			v_total <= v_pos - 8'd128;
	end
	
	if (vb_pos > (video_isPal ? 161 : 135))
		video.vb <= 0;

	if (h_pos == hb_start)
		video.hb <= 0;
	if (h_pos == hb_end)
		video.hb <= 1;
	if (status[62] || (status[54:53] > 0))
		video.hb <= hbl;
	
end

////////////////////////////  CODES  ///////////////////////////////////

// Code layout:
// {code flags,     32'b address, 32'b compare, 32'b replace}
//  127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.
reg [127:0] gg_code;
reg gg_valid;
reg gg_reset;
reg code_download_1;
wire gg_active;
always_ff @(posedge clk_1x) begin

   gg_reset <= 0;
   code_download_1 <= code_download;
	if (code_download && ~code_download_1) begin
      gg_reset <= 1;
   end

   gg_valid <= 0;
	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
			14: begin
				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
				gg_valid          <= 1;          // Clock it in
			end
		endcase
	end
end

wire clk8Snac;
wire clk9Snac;
wire oldClk8;
wire oldClk9;
wire selectedPort1Snac;
wire selectedPort2Snac;
wire oldselectedPort1;
wire oldselectedPort2;
wire [7:0]transmitValueSnac;
wire [7:0]receiveBufferSnac;
wire receiveValidSnac;
wire beginTransferSnac;
wire actionNextSnac;
wire actionNextPadSnac;
reg [7:0]Send;
reg [7:0]Receive;
wire Cmd;
wire Dat;
wire ack;
wire oldAck;
//wire ackSnac;
wire [15:0]ackTimer;
wire ackNone;
wire oneTime;
wire [3:0]bitCnt;
wire [8:0]byteCnt;
wire [8:0]bytesLeft;
wire [7:0]pad1ID;
wire [7:0]pad2ID;
wire [7:0]targetID;
wire irq10Snac;
wire csync;
wire MCtransfer;
wire PStransfer;
wire [7:0]PSdatalength;

reg USER_IN3_1;
reg USER_IN4_1;
reg USER_IN6_1;

reg USER_IN3_2;
reg USER_IN4_2;
reg USER_IN6_2;

assign clk8Snac = bitCnt < 8 ? clk9Snac : 1'b1;

always @(posedge clk_1x) 
begin

   USER_IN3_1 <= USER_IN[3];
   USER_IN4_1 <= USER_IN[4];
   USER_IN6_1 <= USER_IN[6];
   
   USER_IN3_2 <= USER_IN3_1;
   USER_IN4_2 <= USER_IN4_1;
   USER_IN6_2 <= USER_IN6_1;

	if (snacPort1 || snacPort2) begin
		USER_OUT[0] <= ~selectedPort2Snac;
		USER_OUT[1] <= ~selectedPort1Snac;
		USER_OUT[2] <= Cmd;
		USER_OUT[3] <= 1'b1; //ACK
		USER_OUT[4] <= 1'b1; //DAT
		USER_OUT[5] <= oldClk8;	
		ack         <= (snacPort1 || snacPort2) ? USER_IN3_2 : 1'b1;
		Dat         <= USER_IN4_2;	
		
		if ((pad1ID == 8'h63 || pad2ID == 8'h63) && (pad1ID != 8'h31 || pad2ID != 8'h31)) begin //quirk for guncon, irq is N/C in guncon. so using irq line and outputting csync on snac for g-con. only if justifier isn't connected
			USER_OUT[6] <= ~csync;
			irq10Snac   <= 1'b0;
			csync       <= VGA_HS ^ VGA_VS;//real csync shifts HSync during VSync, should be close enough to work	with guncon
		end
		else begin
			USER_OUT[6] <= 1'b1;		
			irq10Snac   <= ~USER_IN6_2;
		end
	end
	else begin
		USER_OUT  <= '1;
		irq10Snac <= 1'b0;
		ack       <= 1'b1;
		Dat       <= 1'b1;
	end
		
	oldselectedPort1 <= selectedPort1Snac;
	oldselectedPort2 <= selectedPort2Snac;

	if ((~oldselectedPort1 && selectedPort1Snac) || (~oldselectedPort2 && selectedPort2Snac)) begin
		byteCnt <= 9'd0;
	end

	if (beginTransferSnac) begin
		bitCnt  <= 4'd0;
		byteCnt <= byteCnt + 9'd1 ;
	end
	
	oldClk8 <= clk8Snac;
	oldClk9 <= clk9Snac;
	
	if (oldClk9 && ~clk9Snac) begin	//send on falling edge
		if (bitCnt < 8) begin
			if (bitCnt==0) begin
				Cmd  <= transmitValueSnac[0];
				Send <= {1'b1, transmitValueSnac[7:1]};
			end
			else begin
				Cmd  <= Send[0];
				Send <= {1'b1, Send[7:1]};
			end
		end	
		else begin
			Cmd  <= 1'b1;
			Send <= Send;
		end
	end	
	
	if(~oldClk8 && clk8Snac) begin //receive on rising edge
		Receive <= { Dat, Receive[7:1]};
		bitCnt <= bitCnt + 1'b1;
		if(bitCnt == 4'd7) begin//check for ack 
			oneTime <= 1'b1;
			if (MCtransfer) ackTimer <= 16'd60000;//very late ack after 7th byte. around 56000 cycles (1.7ms) with a sony MC. 3rd party MCs don't seem to do this
			else begin
				if (byteCnt == bytesLeft + 3) ackTimer <= 16'd400;//only wait around 150 on last byte
				else ackTimer <= 16'd1800;//1st byte of multitap(1375) cycles to ack,digital(460),analog(350-400),ds2(250-400),mouse(120),guncon(270)
			end
		end	
	end

	if (ackTimer > 0) begin
		ackTimer <= ackTimer - 16'd1;
	end	
	
	oldAck <= ack;
	if(oldAck && ~ack) begin //ack received
		actionNextPadSnac <= 1'b1;
		ackTimer <= 8'd255;//a delay between ack and next action. too small might cause a hang. using acktimer 1-255
	end
	else if(ackTimer == 1) begin //wait over
		actionNextPadSnac <= 1'b1;
		oneTime <= 1'b0;		
	end
	else if (ackTimer == 16'd258) begin //no ack
		ackNone <= 1'b1;
		actionNextPadSnac <= 1'b1;
	end
	else if (ackTimer == 16'd256) begin //reset if no ack
		oneTime <= 1'b0;
		ackTimer <= 16'd0;
	end	
	else begin
		actionNextPadSnac <= 1'b0;
		ackNone <= 1'b0;
	end
		
	if (actionNextPadSnac && ((snacPort1 && selectedPort1Snac) || (snacPort2 && selectedPort2Snac))) begin //logic for joypad.vhd
		if (oneTime) begin
			if (ackNone) begin
				if (byteCnt < (bytesLeft + 4)) begin // no ack on last byte of transfer
					receiveBufferSnac <= Receive;
					receiveValidSnac <= 1'b1;
					actionNextSnac <= 1'b1;
				end
				else
					actionNextSnac <= 1'b1;
				end	
			else begin
				if (byteCnt < 3) begin
					receiveBufferSnac <= Receive;
					receiveValidSnac <= 1'b1;
					//ackSnac <= 1'b1;
				end
				else begin
					if (byteCnt < (bytesLeft + 4)) begin
						receiveBufferSnac <= Receive;
						receiveValidSnac <= 1'b1;
						//ackSnac <= 1'b1;
					end
				end
				actionNextSnac <= 1'b1;	
			end
		end
		else begin
			actionNextSnac <= 1'b1;	
		end
	end	
	else begin
		receiveBufferSnac <= 8'd0;
		receiveValidSnac <= 1'b0;
		actionNextSnac <= 1'b0;
		//ackSnac <= 1'b0;
	end	
	
	if (receiveValidSnac) begin
		if (byteCnt == 1) begin
			targetID <= transmitValueSnac;
		end
		if (byteCnt == 2) begin 
			if (targetID == 8'h81 || targetID == 8'h82 || targetID == 8'h83 || targetID == 8'h84) begin 	//memcard quirks
				MCtransfer <= 1'b1;
				if (transmitValueSnac == 8'h52) bytesLeft <= 9'd137;//read
				if (transmitValueSnac == 8'h57) bytesLeft <= 9'd135;//write
				if (transmitValueSnac == 8'h53) bytesLeft <= 9'd7;//ID Cmd
				//pocketstation
				if (transmitValueSnac == 8'h50) bytesLeft <= 9'd0;//Change a FUNC 03h related value
				if (transmitValueSnac == 8'h58) bytesLeft <= 9'd2;//Get an ID or Version value
				if (transmitValueSnac == 8'h59) bytesLeft <= 9'd6;//Prepare File Execution with Dir_index, and Parameter
				if (transmitValueSnac == 8'h5A) bytesLeft <= 9'd18;//Get Dir_index, ComFlags, F_SN, Date, and Time
				if (transmitValueSnac == 8'h5D) bytesLeft <= 9'd3;//Execute Custom Download Notification					
				if (transmitValueSnac == 8'h5E) bytesLeft <= 9'd3;//Get-and-Send ComFlags.bit1,3,2
				if (transmitValueSnac == 8'h5F) bytesLeft <= 9'd1;//Get-and-Send ComFlags.bit0				
				if (transmitValueSnac == 8'h5B) begin//Execute Function and transfer data from Pocketstation to PSX--variable length
					bytesLeft <= 9'd3;
					PStransfer <= 1'b1;
				end	
				if (transmitValueSnac == 8'h5C) begin//Execute Function and transfer data from PSX to Pocketstation--variable length
					bytesLeft <= 9'd3;
					PStransfer <= 1'b1;
				end
			end 
			else begin //joypad quirks
				MCtransfer <= 1'b0;
				if (selectedPort1Snac) pad1ID <= Receive;
				if (selectedPort2Snac) pad2ID <= Receive;

				if (Receive == 8'h80) bytesLeft <= 9'd32; //for multitap
				else bytesLeft <= {5'd0, (Receive[3:0] + Receive[3:0])};	
			end
		end
		if (byteCnt == 4 && PStransfer == 1) begin //for pocketstation
			bytesLeft <= bytesLeft + Receive;
			PSdatalength <=  Receive;
		end
		if ((byteCnt == PSdatalength + 5) && PStransfer == 1) begin 
			bytesLeft <= bytesLeft + Receive;
			PStransfer <= 1'b0;
		end		
	end
end

endmodule
