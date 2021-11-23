//============================================================================
//  GBA
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
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to clk_1x.
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

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,

`ifdef USE_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
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

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
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

`ifdef USE_DDRAM
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
`endif

`ifdef USE_SDRAM
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
`endif

`ifdef DUAL_SDRAM
	//Secondary SDRAM
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

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign USER_OUT = '1;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[8:7];

assign LED_USER  = cart_download | bk_pending;
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
assign FB_PAL_CLK = 0;
assign FB_PAL_ADDR= 0;
assign FB_PAL_DOUT= 0;
assign FB_PAL_WR  = 0;


///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire pll_locked;
wire clk_1x;
wire clk_2x;
wire clk_3x;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_1x),
	.outclk_1(clk_2x),
	.outclk_2(clk_3x),
	.locked(pll_locked)
);

//reg clk1xToggle;
//
//reg clk1xToggle2x;
//reg clk2xIndex;
//
//reg clk1xToggle_1;
//reg clk3xcnt[1:0];
//reg clk3xIndex;
//
//always @(posedge clk_1x) begin
//	clk1xToggle <= ~clk1xToggle;
//end
//
//always @(posedge clk2x) begin
//	clk1xToggle2x <= ~clk1xToggle2x;
//   clk2xIndex    <= 1'b0;
//   if (clk1xToggle2x == clk1xToggle) begin
//      clk2xIndex <= 1'b1;
//   end
//end
//
//always @(posedge clk3x) begin
//	clk1xToggle_1 <= ~clk1xToggle;
//   if (clk1xToggle ~= clk1xToggle_1) begin
//      clk3xcnt <= 2'b00;
//   end else begin
//      clk3xcnt <= clk3xcnt + 1;
//   end
//   clk3xIndex <= 1'b0;
//   if (clk3xcnt = 1) begin
//      clk3xIndex <= 1'b1;
//   end
//end

wire reset = RESET | buttons[1] | status[0] | cart_download | bk_loading | cd_download;

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXX XXXXXXXXXXXX X   X     XXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"PlayStation;SS3E000000:400000;",
	"FS,EXE,Load Exe;",
	"FS2,ISOBIN,Load Iso;",
	"-;",
	"D0RC,Reload Backup RAM;",
	"D0RD,Save Backup RAM;",
	"D0ON,Autosave,Off,On;",
	"D0-;",
	"o4,Savestates to SDCard,On,Off;",
	"o56,Savestate Slot,1,2,3,4;",
	"RH,Save state (Alt-F1);",
	"RI,Restore state (F1);",
	"- ;",
	"OA,Color,16,24;",
	"OE,DDR3 Framebuffer,Off,On;",
	"OB,VRAMViewer,Off,On;",
	"OF,System Type,NTSC,PAL;",
	"OG,Fastboot,Off,On;",
   "OJ,RepTimingGPU,Off,On;",
   "OK,RepTimingDMA,Off,On;",
   "OL,CD Disable,Off,On;",
	"- ;",

	"P1,Video & Audio;",
	"P1-;",
	"P1o01,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O24,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",	
	"P1O78,Stereo Mix,None,25%,50%,100%;",
	"P1o23,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",

	"P3,Miscellaneous;",
	"P3-;",
	"D5P3O5,Pause when OSD is open,Off,On;",
	"P3OR,Rewind Capture,Off,On;",

	"- ;",
	"R0,Reset;",
	"J1,Triangle,Circle,Cross,Square,Select,Start,L1,R1,L2,R2,L3,R3,Rewind,Savestates;",
	"jn,Triangle,Circle,Cross,Square,Select,Start,L1,R1,L2,R2,L3,R3,X,X;",
	"I,",
	"Slot=DPAD|Save/Load=Start+DPAD,",
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
	"Restore state 4;",
	"Rewinding...;",
	"V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [63:0] status;
wire [15:0] status_menumask = {~bk_ena};
wire        forced_scandoubler;
reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        ioctl_download;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 0;

wire [16:0] joy;
wire [16:0] joy_unmod;
wire [10:0] ps2_key;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

wire [15:0] joystick_analog_0;

wire [32:0] RTC_time;

wire [63:0] status_in = cart_download ? {status[63:39],ss_slot,status[36:17],1'b0,status[15:0]} : {status[63:39],ss_slot,status[36:0]};

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io
(
	.clk_sys(clk_1x),
	.HPS_BUS(HPS_BUS),
	.conf_str(CONF_STR),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_unmod),
	.ps2_key(ps2_key),

	.status(status),
	.status_in(status_in),
	.status_set(cart_download | statusUpdate),
	.status_menumask(status_menumask),
	.info_req(ss_info_req),
	.info(ss_info),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.TIMESTAMP(RTC_time),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus),

   .joystick_analog_0(joystick_analog_0)
);

assign joy = joy_unmod[16] ? 16'b0 : joy_unmod;

//////////////////////////  ROM DETECT  /////////////////////////////////

reg bios_download, cart_download, cd_download;
always @(posedge clk_1x) begin
	//code_download <= ioctl_download & &ioctl_index;
	bios_download <= ioctl_download & (ioctl_index == 0);
	cart_download <= ioctl_download & (ioctl_index == 1);
	cd_download   <= ioctl_download & (ioctl_index[5:0] == 2);
end

reg cart_loaded = 0;
always @(posedge clk_1x) begin
	if (cart_download || cd_download) begin
		cart_loaded <= 1;
	end
end

localparam EXE_START = 4194304;
localparam BIOS_START = 2097152;

reg [26:0] ramdownload_wraddr;
reg [31:0] ramdownload_wrdata;
reg        ramdownload_wr;

reg[29:0]  cd_Size;

reg cart_download_1 = 0;
reg cd_download_1 = 0;
reg loadExe = 0;

always @(posedge clk_1x) begin
	ramdownload_wr <= 0;
	if(cart_download | bios_download | cd_download) begin
      if (ioctl_wr) begin
         if(~ioctl_addr[1]) begin
            ramdownload_wrdata[15:0] <= ioctl_dout;
            if (bios_download)      ramdownload_wraddr  <= ioctl_addr[26:0] + BIOS_START[26:0];
            else if (cart_download) ramdownload_wraddr  <= ioctl_addr[26:0] + EXE_START[26:0];                          
            else if (cd_download)   ramdownload_wraddr  <= ioctl_addr[26:0] ;      
         end else begin
            ramdownload_wrdata[31:16] <= ioctl_dout;
            ramdownload_wr            <= 1;
            ioctl_wait                <= 1;
         end
      end
      if(sdram_writeack | sdram_writeack2) ioctl_wait <= 0;
   end else begin 
      ioctl_wait <= 0;
	end
   cart_download_1 <= cart_download;
   loadExe         <= cart_download_1 & ~cart_download;   
   
   cd_download_1 <= cd_download;
   if (cd_download_1 & ~cd_download) cd_Size <= ioctl_addr;
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
	.joyStart       (joy_unmod[9]  ),
	.joyRewind      (joy_unmod[11] ),
	.rewindEnable   (status[27]    ), 
	.status_slot    (status[38:37] ),
	.OSD_saveload   (status[18:17] ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (ss_info_req   ),
	.ss_info        (ss_info       ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 27;

////////////////////////////  SYSTEM  ///////////////////////////////////

psx_mister
psx
(
   .clk1x(clk_1x),          
   .clk2x(clk_2x),
   .reset(reset),
   // commands 
   .loadExe(loadExe),
   .fastboot(status[16]),
   .REPRODUCIBLEGPUTIMING(status[19]),
   .REPRODUCIBLEDMATIMING(status[20]),
   .CDDISABLE(status[21]),
   // RAM/BIOS interface      
   .ram_refresh(sdr_refresh),
   .ram_dataWrite(sdr_sdram_din),
   .ram_dataRead(sdr_sdram_dout),
   .ram_Adr(sdram_addr),
   .ram_be(sdram_be), 
   .ram_rnw(sdram_rnw),  
   .ram_ena(sdram_req), 
   .ram_128(sdram_128), 
   .ram_done(sdram_ack),
   .ram_reqprocessed(sdram_reqprocessed),
   .ram_idle(ram_idle),
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
   .fastCD          (0),
   .cd_Size         (cd_Size),
   .cd_req          (cd_req),
   .cd_addr         (cd_addr),
   .cd_data         (cd_data),
   .cd_done         (cd_done),
   // video
   .videoout_on     (~status[14]),
   .isPal           (status[15]),
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
   //Keys
   .KeyTriangle(joy[4]),    
   .KeyCircle(joy[5]),       
   .KeyCross(joy[6]),       
   .KeySquare(joy[7]),       
   .KeySelect(joy[8]),       
   .KeyStart(joy[9]),        
	.KeyRight(joy[0]),
	.KeyLeft(joy[1]),
	.KeyUp(joy[3]),
	.KeyDown(joy[2]),      
   .KeyR1(joy[11]),          
   .KeyR2(joy[13]),          
   .KeyR3(joy[15]),          
   .KeyL1(joy[10]),          
   .KeyL2(joy[12]),          
   .KeyL3(joy[14]),          
   .Analog1X(joystick_analog_0[7:0]),       
   .Analog1Y(joystick_analog_0[15:8]),       
   .Analog2X(8'b0),       
   .Analog2Y(8'b0),       
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
   .rewind_active         (0)  //(status[27] & joy[15])
);

////////////////////////////  MEMORY  ///////////////////////////////////

localparam ROM_START = (65536+131072)*4;

wire         sdr_refresh;
wire  [31:0] sdr_sdram_din;
wire [127:0] sdr_sdram_dout;
wire [127:0] sdr_sdram_dout2;
wire  [15:0] sdr_bram_din;
wire         sdr_sdram_ack;
wire         sdr_bram_ack;
wire  [22:0] sdram_addr;
wire   [3:0] sdram_be;
wire         sdram_req;
wire         sdram_ack;
wire         sdram_ack2;
wire         sdram_reqprocessed;
wire         sdram_readack;
wire         sdram_readack2;
wire         sdram_writeack;
wire         sdram_writeack2;
wire         sdram_rnw;
wire         sdram_128;
wire         ram_idle;

assign sdram_ack = sdram_readack | sdram_writeack;
assign sdram_ack2 = sdram_readack2 | sdram_writeack2;

sdram sdram
(
	.*,
   .SDRAM_EN(1),
	.init(~pll_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),
	
	.refreshForce(sdr_refresh),
	.ram_idle(ram_idle),

	.ch1_addr(sdram_addr),
	.ch1_din(),
	.ch1_dout(sdr_sdram_dout),
	.ch1_req(sdram_req & sdram_rnw),
	.ch1_rnw(1'b1),
	.ch1_128(sdram_128),
	.ch1_ready(sdram_readack),
	.ch1_reqprocessed(sdram_reqprocessed),

	.ch2_addr ((cart_download | bios_download) ? ramdownload_wraddr : sdram_addr),
	.ch2_din  ((cart_download | bios_download) ? ramdownload_wrdata : sdr_sdram_din),
	.ch2_dout (),
	.ch2_req  ((cart_download | bios_download) ? ramdownload_wr     : (sdram_req & ~sdram_rnw)),
	.ch2_rnw  (1'b0),
   .ch2_be   ((cart_download | bios_download) ? 4'b1111            : sdram_be),
	.ch2_ready(sdram_writeack),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(sdr_bram_din),
	.ch3_req(bram_req),
	.ch3_rnw(~bk_loading),
	.ch3_ready(sdr_bram_ack)
);

wire        cd_req;
wire [26:0] cd_addr;
wire [31:0] cd_data;
wire        cd_done;

assign cd_data = sdr_sdram_dout2[31:0];
assign cd_done = sdram_readack2;

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

	.ch1_addr(cd_addr),
	.ch1_din(),
	.ch1_dout(sdr_sdram_dout2),
	.ch1_req(cd_req),
	.ch1_rnw(1'b1),
	.ch1_128(1'b0),
	.ch1_ready(sdram_readack2),
	.ch1_reqprocessed(),

	.ch2_addr (ramdownload_wraddr),
	.ch2_din  (ramdownload_wrdata),
	.ch2_dout (),
	.ch2_req  ((cd_download) ? ramdownload_wr     : 1'b0),
	.ch2_rnw  (1'b0),
   .ch2_be   (4'b1111),
	.ch2_ready(sdram_writeack2),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(),
	.ch3_req(1'b0),
	.ch3_rnw(1'b1),
	.ch3_ready()
);

//wire [63:0] ss_dout, ss_din;
//wire [27:2] ss_addr;
//wire [7:0]  ss_be;
//wire        ss_rnw, ss_req, ss_ack;

assign DDRAM_CLK = clk_2x;
//ddram ddram
//(
//	.*,
//
//	.ch1_addr(romcopy_active ? romcopy_readpos[26:1]+ROM_START[26:1] : {sdram_addr, 1'b0}),
//	.ch1_din(16'b0),
//	.ch1_dout({ddr_sdram_dout2, ddr_sdram_dout1}),
//	.ch1_req(romcopy_active ? romcopy_ddrreq : sdram_req & ~sdram_en),
//	.ch1_rnw(1'b1),
//	.ch1_ready(ddr_sdram_ack),
//
//	.ch2_addr({bus_addr, 1'b0}),
//	.ch2_din(bus_din),
//	.ch2_dout(ddr_bus_dout),
//	.ch2_req(~cart_download & bus_req & ~sdram_en),
//	.ch2_rnw(bus_rd),
//	.ch2_ready(ddr_bus_ack),
//
//	.ch3_addr({sd_lba[7:0],bram_addr}),
//	.ch3_din(bram_dout),
//	.ch3_dout(ddr_bram_din),
//	.ch3_req(bram_req & ~sdram_en),
//	.ch3_rnw(~bk_loading),
//	.ch3_ready(ddr_bram_ack),
//
//	.ch4_addr({ss_addr, 1'b0}),
//	.ch4_din(ss_din),
//	.ch4_dout(ss_dout),
//	.ch4_req(ss_req),
//	.ch4_rnw(ss_rnw),
//	.ch4_be(ss_be),
//	.ch4_ready(ss_ack),
//   
//   .ch5_addr({fb_addr, 1'b0}),
//   .ch5_din(fb_din),
//   .ch5_req(fb_req),
//   .ch5_ready(fb_ack)
//   
//);

/////////////////

//wire [127:0] time_din_h = {32'd0, time_din, "RT"};
wire [15:0] bram_dout;
wire [15:0] bram_din = sdr_bram_din;
wire        bram_ack = sdr_bram_ack;
assign sd_buff_din = bram_buff_out;
wire [15:0] bram_buff_out;

altsyncram	altsyncram_component
(
	.address_a (bram_addr),
	.address_b (sd_buff_addr),
	.clock0 (clk_1x),
	.clock1 (clk_1x),
	.data_a (bram_din),
	.data_b (sd_buff_dout),
	.wren_a (~bk_loading & bram_ack),
	.wren_b (sd_buff_wr),
	.q_a (bram_dout),
	.q_b (bram_buff_out),
	.byteena_a (1'b1),
	.byteena_b (1'b1),
	.clocken0 (1'b1),
	.clocken1 (1'b1),
	.rden_a (1'b1),
	.rden_b (1'b1)
);
defparam
	altsyncram_component.address_reg_b = "CLOCK1",
	altsyncram_component.clock_enable_input_a = "BYPASS",
	altsyncram_component.clock_enable_input_b = "BYPASS",
	altsyncram_component.clock_enable_output_a = "BYPASS",
	altsyncram_component.clock_enable_output_b = "BYPASS",
	altsyncram_component.indata_reg_b = "CLOCK1",
	altsyncram_component.intended_device_family = "Cyclone V",
	altsyncram_component.lpm_type = "altsyncram",
	altsyncram_component.numwords_a = 256,
	altsyncram_component.numwords_b = 256,
	altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
	altsyncram_component.outdata_aclr_a = "NONE",
	altsyncram_component.outdata_aclr_b = "NONE",
	altsyncram_component.outdata_reg_a = "UNREGISTERED",
	altsyncram_component.outdata_reg_b = "UNREGISTERED",
	altsyncram_component.power_up_uninitialized = "FALSE",
	altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.widthad_a = 8,
	altsyncram_component.widthad_b = 8,
	altsyncram_component.width_a = 16,
	altsyncram_component.width_b = 16,
	altsyncram_component.width_byteena_a = 1,
	altsyncram_component.width_byteena_b = 1,
	altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";

reg [7:0] bram_addr;
reg bram_tx_start = 0;
reg bram_tx_finish;
reg bram_req;

always @(posedge clk_1x) begin
	reg state;

	bram_req <= 0;

	if (bram_tx_start) begin
		if (~&bram_addr)
			bram_tx_finish <= 1;
	end else if(~bram_tx_start) {bram_addr, state, bram_tx_finish} <= 0;
	else if(~bram_tx_finish) begin
		if(!state) begin
			bram_req <= 1;
			state <= 1;
		end
		else if(bram_ack) begin
			state <= 0;
			if(~&bram_addr) bram_addr <= bram_addr + 1'd1;
			else bram_tx_finish <= 1;
		end
	end
end

////////////////////////////  VIDEO  ////////////////////////////////////

assign CLK_VIDEO = clk_2x;

wire hs, vs, hbl, vbl, video_interlace;

assign VGA_F1 = status[14] ? 1'b0 : video_interlace;
assign VGA_SL = sl[1:0];

wire [2:0] scale = status[4:2];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

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

assign CE_PIXEL = ce_pix;
assign VGA_R    = r;
assign VGA_G    = g;
assign VGA_B    = b;
assign VGA_VS   = vs;
assign VGA_HS   = hs;
assign VGA_DE   = ~(vbl | hbl);

wire [1:0] ar = status[33:32];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? (status[11] ? 12'd2 : 12'd4) : (ar - 1'd1)),
	.ARY((!ar) ? (status[11] ? 12'd1 : 12'd3) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[35:34])
);


/////////////////////////  STATE SAVE/LOAD  /////////////////////////////
//wire bk_load     = status[12];
//wire bk_save     = status[13];
//wire bk_autosave = status[23];
//wire bk_write    = (save_eeprom|save_sram|save_flash) && bus_req;

reg  bk_ena      = 0;
reg  bk_pending  = 0;
reg  bk_loading  = 0;
assign sd_lba = 0;

//reg bk_record_rtc = 0;
//
//wire extra_data_addr = sd_lba[8:0] > save_sz;
//
//always @(posedge clk_1x) begin
//	if (bk_write)      bk_pending <= 1;
//	else if (bk_state) bk_pending <= 0;
//end
//reg use_img;
//reg [8:0] save_sz;
//
//always @(posedge clk_1x) begin : size_block
//	reg old_downloading;
//
//	old_downloading <= cart_download;
//	if(~old_downloading & cart_download) {use_img, save_sz} <= 0;
//
//	if(bus_req & ~use_img) begin
//		if(save_eeprom) save_sz <= save_sz | 8'hF;
//		if(save_sram)   save_sz <= save_sz | 8'h3F;
//		if(save_flash)  save_sz <= save_sz | {flash_1m, 7'h7F};
//	end
//
//	if(img_mounted && img_size && !img_readonly) begin
//		use_img <= 1;
//		if (!(img_size[17:9] & (img_size[17:9] - 9'd1))) // Power of two
//			save_sz <= img_size[17:9] - 1'd1;
//		else                                             // Assume one extra sector of RTC data
//			save_sz <= img_size[17:9] - 2'd2;
//	end
//
//	bk_ena <= |save_sz;
//end
//
//reg  bk_state  = 0;
//wire bk_save_a = OSD_STATUS & bk_autosave;
//
//always @(posedge clk_1x) begin
//	reg old_load = 0, old_save = 0, old_save_a = 0, old_ack;
//	reg [1:0] state;
//
//	old_load   <= bk_load;
//	old_save   <= bk_save;
//	old_save_a <= bk_save_a;
//	old_ack    <= sd_ack;
//
//	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;
//
//	if(!bk_state) begin
//		bram_tx_start <= 0;
//		state <= 0;
//		sd_lba <= 0;
//		time_dout <= {5'd0, RTC_time, 42'd0};
//		bk_loading <= 0;
//		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save) | (~old_save_a & bk_save_a & bk_pending) | (cart_download & img_mounted))) begin
//			bk_state <= 1;
//			bk_loading <= bk_load | img_mounted;
//		end
//	end
//	else if(bk_loading) begin
//		case(state)
//			0: begin
//					sd_rd <= 1;
//					state <= 1;
//				end
//			1: if(old_ack & ~sd_ack) begin
//					bram_tx_start <= 1;
//					state <= 2;
//				end
//			2: if(bram_tx_finish) begin
//					bram_tx_start <= 0;
//					state <= 0;
//					sd_lba <= sd_lba + 1'd1;
//
//					// always read max possible size
//					if(sd_lba[8:0] == 9'h100) begin
//						bk_record_rtc <= 0;
//						bk_state <= 0;
//						RTC_load <= 0;
//					end
//				end
//		endcase
//
//		if (extra_data_addr) begin
//			if (~|sd_buff_addr && sd_buff_wr && sd_buff_dout == "RT") begin
//				bk_record_rtc <= 1;
//				RTC_load <= 0;
//			end
//		end
//
//		if (bk_record_rtc) begin
//			if (sd_buff_addr < 6 && sd_buff_addr >= 1)
//				time_dout[{sd_buff_addr[2:0] - 3'd1, 4'b0000} +: 16] <= sd_buff_dout;
//
//			if (sd_buff_addr > 5)
//				RTC_load <= 1;
//
//			if (&sd_buff_addr)
//				bk_record_rtc <= 0;
//		end
//	end
//	else begin
//		case(state)
//			0: begin
//					bram_tx_start <= 1;
//					state <= 1;
//				end
//			1: if(bram_tx_finish) begin
//					bram_tx_start <= 0;
//					sd_wr <= 1;
//					state <= 2;
//				end
//			2: if(old_ack & ~sd_ack) begin
//					state <= 0;
//					sd_lba <= sd_lba + 1'd1;
//
//					if (sd_lba[8:0] == {1'b0, save_sz} + (has_rtc ? 9'd1 : 9'd0))
//						bk_state <= 0;
//				end
//		endcase
//	end
//end

////////////////////////////  CODES  ///////////////////////////////////

// Code layout:
// {code flags,     32'b address, 32'b compare, 32'b replace}
//  127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.
//reg [127:0] gg_code;
//reg gg_valid;
//reg gg_reset;
//reg ioctl_download_1;
//wire gg_active;
//always_ff @(posedge clk_1x) begin
//
//   gg_reset <= 0;
//   ioctl_download_1 <= ioctl_download;
//	if (ioctl_download && ~ioctl_download_1 && ioctl_index == 255) begin
//      gg_reset <= 1;
//   end
//
//   gg_valid <= 0;
//	if (code_download & ioctl_wr) begin
//		case (ioctl_addr[3:0])
//			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
//			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
//			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
//			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
//			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
//			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
//			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
//			14: begin
//				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
//				gg_valid          <= 1;          // Clock it in
//			end
//		endcase
//	end
//end

endmodule
