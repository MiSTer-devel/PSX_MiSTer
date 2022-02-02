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
	inout  [47:0] HPS_BUS,

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
   output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (MISTER_FB=1 in qsf)
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

assign HDMI_FREEZE = 0;

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign USER_OUT = '1;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[8:7];

assign LED_USER  = cart_download;
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

wire reset = RESET | buttons[1] | status[0] | bios_download | cart_download | cd_download;

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXX XXX XXXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"PSX;SS3E000000:400000;",
	"S1,ISOCUE,Load CD;",
	"F1,EXE,Load Exe;",
	//"h1FS2,ISOBIN,Load to SDRAM2;",
	"-;",
	"SC2,MCD,Mount Memory Card 1;",
	"SC3,MCD,Mount Memory Card 2;",
	"D0RC,Reload Memory Cards;",
	"D0RD,Save Memory Cards;",
	"D0ON,Autosave,Off,On;",
	"D0-;",
	"o4,Savestates to SDCard,On,Off;",
	"o56,Savestate Slot,1,2,3,4;",
	"RH,Save state (Alt-F1);",
	"RI,Restore state (F1);",
	"-;",
	"o78,System Type,NTSC-U,NTSC-J,PAL;",
	"OO,Pad Mode,Digital,Analog;",
	"OG,Fastboot,Off,On;",
	"d1oC,SPU RAM select,DDR3,SDRAM2;",
	"OP,Pause when OSD is open,Off,On;",
	"-;",
	"OM,Dithering,On,Off;",
	"o9,Deinterlacing,Weave,Bob;",
	"OS,FPS Overlay,Off,On;",
	"OT,Error Overlay,On,Off;",
	"-;",

	"P1,Video & Audio;",
	"P1-;",
	"P1o01,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O24,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",	
	"P1O78,Stereo Mix,None,25%,50%,100%;",
	"P1o23,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1oD,Dithering Filter,Off,On;",

   "P2,Debug;",
	"P2-;",
	"P2OE,DDR3 Framebuffer,Off,On;",
	"P2OA,DDR3 FB Color,16,24;",
	"P2OB,VRAMViewer,Off,On;",
	"P2OU,Sound,On,Off;",
	"P2oA,SPU Reverb,On,Off;",
	"P2OV,Fast Memory,Off,On;",
	"P2OJ,RepTimingGPU,Off,On;",
	"P2OK,RepTimingDMA,Off,On;",
	"P2oB,RepTimingSPUDMA,Off,On;",
	"P2OQ,DMAinBLOCKs,Off,On;",
	"P2OL,CD Instant Seek,Off,On;",
	"P2OF,Force 60Hz PAL,Off,On;",
	"P2OR,Textures,On,Off;",

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
wire [15:0] status_menumask = {SDRAM2_EN, 1'b0};
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

wire [16:0] joy;
wire [16:0] joy_unmod;
wire [16:0] joy2;

wire [10:0] ps2_key;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

wire [15:0] joystick_analog_l0;
wire [15:0] joystick_analog_r0;
wire [15:0] joystick_analog_l1;
wire [15:0] joystick_analog_r1;

wire [32:0] RTC_time;

wire [63:0] status_in = cart_download ? {status[63:39],ss_slot,status[36:17],1'b0,status[15:0]} : {status[63:39],ss_slot,status[36:0]};

hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(4), .BLKSZ(3)) hps_io
(
	.clk_sys(clk_1x),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_unmod),
	.joystick_1(joy2),
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
   .joystick_r_analog_1(joystick_analog_r1)
);

assign joy = joy_unmod[16] ? 16'b0 : joy_unmod;

assign sd_rd[0] = 0;
assign sd_wr[0] = 0;

assign sd_wr[1] = 0;

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
	if (cart_download || cd_download || img_mounted[1]) begin
		cart_loaded <= 1;
	end
end

localparam EXE_START = 4194304;
localparam BIOS_START = 2097152;

reg [26:0] ramdownload_wraddr;
reg [31:0] ramdownload_wrdata;
reg        ramdownload_wr;

reg[29:0]  cd_Size;
reg        hasCD = 0;

reg cart_download_1 = 0;
reg cd_download_1 = 0;
reg loadExe = 0;
reg cd_hps_on = 0;

reg sd_mounted2 = 0;
reg sd_mounted3 = 0;

reg memcard1_load = 0;
reg memcard2_load = 0;
reg memcard_save = 0;

wire bk_load     = status[12];
wire bk_save     = status[13];
wire bk_autosave = status[23];

reg old_load = 0; 
reg old_save = 0; 
reg old_save_a = 0;

wire bk_save_a = OSD_STATUS & bk_autosave;

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
   if (cd_download_1 & ~cd_download) begin
      cd_Size   <= ioctl_addr;
      cd_hps_on <= 0;
      hasCD     <= 1;
   end
     
   if (img_mounted[1]) begin
      if (img_size > 0) begin
         cd_Size   <= img_size[29:0];
         cd_hps_on <= 1;
         hasCD     <= 1;
      end else begin
         hasCD     <= 0;
      end
   end
   
   memcard1_load <= 0;
   memcard2_load <= 0;
   memcard_save <= 0;
   
   if (img_mounted[2]) begin
      if (img_size > 0) begin
         sd_mounted2   <= 1;
         memcard1_load <= 1;
      end else begin
         sd_mounted2 <= 0;
      end
   end
   
   if (img_mounted[3]) begin
      if (img_size > 0) begin
         sd_mounted3   <= 1;
         memcard2_load <= 1;
      end else begin
         sd_mounted3 <= 0;
      end
   end
   
   old_load   <= bk_load;
	old_save   <= bk_save;
	old_save_a <= bk_save_a;
   
   if (~old_load & bk_load) begin 
      memcard1_load <= 1;
      memcard2_load <= 1;
   end
   
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
	.joyStart       (joy_unmod[9]  ),
	.joyRewind      (0             ),
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
   .pause(status[25] & OSD_STATUS),
   .loadExe(loadExe),
   .fastboot(status[16]),
   .FASTMEM(status[31]),
   .REPRODUCIBLEGPUTIMING(status[19]),
   .REPRODUCIBLEDMATIMING(status[20]),
   .DMABLOCKATONCE(status[26]),
   .INSTANTSEEK(status[21]),
   .ditherOff(status[22]),
   .analogPad(status[24]),
   .fpscountOn(status[28]),
   .errorOn(~status[29]),
   .noTexture(status[27]),
   .SPUon(~status[30]),
   .SPUSDRAM(status[44] & SDRAM2_EN),
   .REVERBOFF(status[42]),
   .REPRODUCIBLESPUDMA(status[43]),
   // RAM/BIOS interface      
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
   .region          (status[40:39]),
   .hasCD           (hasCD),
   .fastCD          (0),
   .cd_Size         (cd_Size),
   .cd_req          (cd_req),
   .cd_addr         (cd_addr),
   .cd_data         (cd_data),
   .cd_done         (cd_done),
   .cd_hps_on       (cd_hps_on),   
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
   .memcard1_load   (memcard1_load),
   .memcard2_load   (memcard2_load),
   .memcard_save    (memcard_save),
   .memcard1_available (sd_mounted2),
   .memcard1_rd     (sd_rd[2]),
   .memcard1_wr     (sd_wr[2]),
   .memcard1_lba    (sd_lba2),
   .memcard1_ack    (sd_ack[2]),
   .memcard1_write  (sd_buff_wr),
   .memcard1_addr   (sd_buff_addr[8:0]),
   .memcard1_dataIn (sd_buff_dout),
   .memcard1_dataOut(sd_buff_din2),    
   .memcard2_available (sd_mounted3),   
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
   .isPal           (status[40]),
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
   //Keys
   .KeyTriangle({joy2[4], joy[4] }),    
   .KeyCircle  ({joy2[5] ,joy[5] }),       
   .KeyCross   ({joy2[6] ,joy[6] }),       
   .KeySquare  ({joy2[7] ,joy[7] }),       
   .KeySelect  ({joy2[8] ,joy[8] }),       
   .KeyStart   ({joy2[9] ,joy[9] }),        
   .KeyRight   ({joy2[0] ,joy[0] }),
   .KeyLeft    ({joy2[1] ,joy[1] }),
   .KeyUp      ({joy2[3] ,joy[3] }),
   .KeyDown    ({joy2[2] ,joy[2] }),      
   .KeyR1      ({joy2[11],joy[11]}),          
   .KeyR2      ({joy2[13],joy[13]}),          
   .KeyR3      ({joy2[15],joy[15]}),          
   .KeyL1      ({joy2[10],joy[10]}),          
   .KeyL2      ({joy2[12],joy[12]}),          
   .KeyL3      ({joy2[14],joy[14]}),          
   .Analog1XP1(joystick_analog_l0[7:0]),       
   .Analog1YP1(joystick_analog_l0[15:8]),       
   .Analog2XP1(joystick_analog_r0[7:0]),           
   .Analog2YP1(joystick_analog_r0[15:8]),    
   .Analog1XP2(joystick_analog_l1[7:0]),       
   .Analog1YP2(joystick_analog_l1[15:8]),       
   .Analog2XP2(joystick_analog_r1[7:0]),           
   .Analog2YP2(joystick_analog_r1[15:8]),           
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
wire  [31:0] sdr_sdram_dout32;
wire [127:0] sdr_sdram_dout2;
wire  [15:0] sdr_bram_din;
wire         sdr_sdram_ack;
wire         sdr_bram_ack;
wire  [22:0] sdram_addr;
wire   [3:0] sdram_be;
wire         sdram_req;
wire         sdram_ack;
wire         sdram_reqprocessed;
wire         sdram_readack;
wire         sdram_readack2;
wire         sdram_writeack;
wire         sdram_writeack2;
wire         sdram_rnw;
wire         sdram_128;
wire         ram_idle;

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
	.ram_idle(ram_idle),

	.ch1_addr(sdram_addr),
	.ch1_din(),
	.ch1_dout(sdr_sdram_dout),
	.ch1_dout32(sdr_sdram_dout32),
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

	.ch3_addr(0),
	.ch3_din(),
	.ch3_dout(),
	.ch3_req(1'b0),
	.ch3_rnw(1'b1),
	.ch3_ready()
);

wire        cd_req;
wire [26:0] cd_addr;
wire [31:0] cd_data;
wire        cd_done;

wire [31:0] spuram_dataWrite;
wire [18:0] spuram_Adr;
wire  [3:0] spuram_be;
wire        spuram_rnw;
wire        spuram_ena;
wire [31:0] spuram_dataRead;
wire        spuram_done;

assign cd_data = sdr_sdram_dout2[31:0];
assign cd_done = 0; //sdram_readack2;

assign spuram_dataRead = sdr_sdram_dout2[31:0];
assign spuram_done     = sdram_readack2 | sdram_writeack2;


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

assign DDRAM_CLK = clk_2x;

////////////////////////////  VIDEO  ////////////////////////////////////

assign CLK_VIDEO = clk_2x;

wire hs, vs, hbl, vbl, video_interlace;

assign VGA_F1 = status[14] ? 1'b0 : (video_interlace & ~status[41]);
assign VGA_SL = sl[1:0];

wire [2:0] scale = status[4:2];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

wire ce_pix;
wire [7:0] r,g,b;
wire hs_b, vs_b, hb_b, vb_b;
wire [7:0] r_b, g_b, b_b;

cofi_blender blender
(
	.clk(clk_2x),
	.ce_pixel(ce_pix),
	.force_blend(1'b0),
	.diff_blend(status[45]),
	.reduced(1'b1),
	.hblank(hbl),
	.vblank(vbl),
	.hsync(hs),
	.vsync(vs),
	.red(r),
	.green(g),
	.blue(b),
	.hblank_out(hb_b),
	.vblank_out(vb_b),
	.hsync_out(hs_b),
	.vsync_out(vs_b),
	.red_out(r_b),
	.green_out(g_b),
	.blue_out(b_b)
);

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
assign VGA_R    = r_b;
assign VGA_G    = g_b;
assign VGA_B    = b_b;
assign VGA_VS   = vs_b;
assign VGA_HS   = hs_b;
assign VGA_DE   = ~(vb_b | hb_b);

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
