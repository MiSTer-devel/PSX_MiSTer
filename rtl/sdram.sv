//
// sdram
// Copyright (c) 2015-2019 Sorgelig
//
// Some parts of SDRAM code used from project:
// http://hamsterworks.co.nz/mediawiki/index.php/Simple_SDRAM_Controller
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module sdram
(
	input              init,        // reset to initialize RAM
	input              clk,         // clock ~100MHz
	input              clk_base,    // clock ~33MHz
                      
	input              SDRAM_EN,    // Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0 
   
	inout  reg [15:0]  SDRAM_DQ,    // 16 bit bidirectional data bus
	output reg [12:0]  SDRAM_A,     // 13 bit multiplexed address bus
	output             SDRAM_DQML,  // two byte masks
	output             SDRAM_DQMH,  // 
	output reg  [1:0]  SDRAM_BA,    // two banks
	output             SDRAM_nCS,   // a single chip select
	output             SDRAM_nWE,   // write enable
	output             SDRAM_nRAS,  // row address select
	output             SDRAM_nCAS,  // columns address select
	output             SDRAM_CKE,   // clock enable
	output             SDRAM_CLK,   // clock for chip

	input              refreshForce,                   
	output             ram_idle,    // used to tell the core a write command on ch2 will be accepted instantly               

	input      [26:0]  ch1_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
	output reg [127:0] ch1_dout,    // data output to cpu
	output reg [31:0]  ch1_dout32,  // data output to cpu
	input      [15:0]  ch1_din,     // data input from cpu
	input              ch1_req,     // request
	input              ch1_rnw,     // 1 - read, 0 - write
	input              ch1_dma,     // 1 - read 128bit for dma
	input      [ 1:0]  ch1_cntDMA,  // count of words-1 for dma read
	input              ch1_cache,   // 1 - read 128bit for cache
	output reg         ch1_ready,
	output reg [ 3:0]  cache_wr,    
	output reg [31:0]  cache_data,  
	output reg [ 7:0]  cache_addr,  
	output reg         dma_wr,  
	output reg         dma_reqprocessed,  
	output reg [31:0]  dma_data,  

	input      [26:0]  ch2_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
	output reg [31:0]  ch2_dout,    // data output to cpu
	input      [31:0]  ch2_din,     // data input from cpu
	input              ch2_req,     // request
	input              ch2_rnw,     // 1 - read, 0 - write
   input      [3:0]   ch2_be,      
	output reg         ch2_ready,
                      
	input      [26:0]  ch3_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
	output reg [31:0]  ch3_dout,    // data output to cpu
	input      [31:0]  ch3_din,     // data input from cpu
	input              ch3_req,     // request
	input              ch3_rnw,     // 1 - read, 0 - write
	input      [3:0]   ch3_be,
	output reg         ch3_ready,

	input      [26:0]  dmafifo_adr,   
	input      [31:0]  dmafifo_data, 
	input              dmafifo_empty, 
	output reg         dmafifo_read
);

assign SDRAM_nCS  = chip;
assign SDRAM_nRAS = command[2];
assign SDRAM_nCAS = command[1];
assign SDRAM_nWE  = command[0];
assign SDRAM_CKE  = 1;
assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];

localparam BURST_LENGTH        = 8;
//(BURST_LENGTH == 8) ? 3'b011 : (BURST_LENGTH == 4) ? 3'b010 : (BURST_LENGTH == 2) ? 3'b001 : 3'b000;  // 000=1, 001=2, 010=4, 011=8
// we do 4 bursts of 2 words(16bit) for every read. The reason is that a burst of 8 will wrap inside the page. e.g. reading address 6,7,8,.. is not possible, it will read 6,7,0,.. instead
// as bursts of 2 can be done back-to-back, this does not have any latency or bandwidth penalty compared to full 8 word burst
localparam BURST_CODE          = 3'b001;   
localparam ACCESS_TYPE         = 1'b0;     // 0=sequential, 1=interleaved
localparam CAS_LATENCY         = 3'd2;     // 2 for < 100MHz, 3 for >100MHz
localparam OP_MODE             = 2'b00;    // only 00 (standard operation) allowed
localparam NO_WRITE_BURST      = 1'b1;     // 0= write burst enabled, 1=only single access write
localparam MODE                = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_CODE};

localparam sdram_startup_cycles= 14'd12100;// 100us, plus a little more, @ 100MHz
localparam cycles_per_refresh  = 14'd780;  // (64000*100)/8192-1 Calc'd as (64ms @ 100MHz)/8192 rose
localparam startup_refresh_max = 14'b11111111111111;

// SDRAM commands
wire [2:0] CMD_NOP             = 3'b111;
wire [2:0] CMD_ACTIVE          = 3'b011;
wire [2:0] CMD_READ            = 3'b101;
wire [2:0] CMD_WRITE           = 3'b100;
wire [2:0] CMD_PRECHARGE       = 3'b010;
wire [2:0] CMD_AUTO_REFRESH    = 3'b001;
wire [2:0] CMD_LOAD_MODE       = 3'b000;

reg [13:0] refresh_count = startup_refresh_max - sdram_startup_cycles;
reg  [2:0] command;
reg        chip;

localparam STATE_STARTUP = 0;
localparam STATE_WAIT    = 1;
localparam STATE_RW1     = 2;
localparam STATE_RW2     = 3;
localparam STATE_IDLE    = 4;
localparam STATE_IDLE_1  = 5;
localparam STATE_IDLE_2  = 6;
localparam STATE_IDLE_3  = 7;
localparam STATE_IDLE_4  = 8;
localparam STATE_IDLE_5  = 9;
localparam STATE_IDLE_6  = 10;
localparam STATE_IDLE_7  = 11;
localparam STATE_IDLE_8  = 12;
localparam STATE_IDLE_9  = 13;
localparam STATE_RFSH    = 14;

reg clk1xToggle     = 0;
reg clk1xToggle3X   = 0;
reg clk1xToggle3X_1 = 0;
reg clk3xIndex      = 0;

reg ram_idleNext    = 0;

assign ram_idle = ram_idleNext && !ch3_req;

reg [10:0] lastbank;

// ch3 buffered for timing closure
reg [26:0]  ch3buf_addr;
reg [31:0]  ch3buf_din; 
reg         ch3buf_rnw; 
reg [3:0]   ch3buf_be;

always @(posedge clk_base) begin

   ch1_ready <= ch1_ready_ramclock;
	ch2_ready <= ch2_ready_ramclock;
	ch3_ready <= ch3_ready_ramclock;

	dma_reqprocessed <= dma_reqprocessed_ramclock;
   
   clk1xToggle <= !clk1xToggle;
      
   ram_idleNext <= 0;
   if (state == STATE_IDLE || state == STATE_IDLE_1 || state == STATE_IDLE_2 || (state == STATE_RW1 && saved_wr) || state == STATE_RW2) begin
      if (refresh_count < (cycles_per_refresh - 14'd16) && !ch1_rq && !ch2_rq && !ch3_rq) begin
         ram_idleNext <= 1;
      end
   end
   
   if (ch1_ready_ramclock) begin
      ch1_dout32 <= ch1_dout[31:0];
   end
   
   dma_wr  <= 0;
   dma_ack <= 0;

   if (dma_wr) begin
      if (dma_counter < dma_count) begin
         dma_wr      <= 1;
         dma_counter <= dma_counter + 1'b1;
         if (dma_counter == 0) dma_data <= ch1_dout[ 63:32];
         if (dma_counter == 1) dma_data <= ch1_dout[ 95:64];
         if (dma_counter == 2) dma_data <= ch1_dout[127:96];
      end
   end
   
   if (dma_done) begin
      dma_ack     <= 1;
      dma_wr      <= 1;
      dma_data    <= ch1_dout[31:0];
      dma_counter <= 0;
      dma_count   <= dma_count_3x;
   end
   
end

reg ch1_ready_ramclock = 0;
reg ch2_ready_ramclock = 0;
reg ch3_ready_ramclock = 0;
reg refreshForce_1 = 0;

reg cache_buffer      = 0;
reg cache_buffer_next = 0;

reg cache_done_0  = 0;
reg cache_done_1  = 0;
reg cache_done_2  = 0;
reg cache_done_3  = 0;
reg [3:0] cache_wr_next = 0;

reg       dma_buffer    = 0;
reg       dma_done      = 0;
reg       dma_ack       = 0;
reg [1:0] dma_count_3x  = 0;
reg [1:0] dma_count     = 0;
reg [1:0] dma_counter   = 0;
reg       dma_reqprocessed_ramclock = 0;

reg  [3:0] state = STATE_STARTUP;

reg ch1_rq, ch2_rq, ch3_rq, refreshForce_req;
reg saved_wr;
reg saved_128read = 0;

reg [CAS_LATENCY+BURST_LENGTH:0] data_ready_delay1, data_ready_delay2, data_ready_delay3;

reg [12:0] cas_addr;
reg [31:0] saved_data;
reg  [3:0] saved_be;
reg [15:0] dq_reg;

reg [1:0] ch;

always @(posedge clk) begin
  
   clk1xToggle3X   <= clk1xToggle;
   clk1xToggle3X_1 <= clk1xToggle3X;
   clk3xIndex      <= clk1xToggle3X_1 == clk1xToggle;
	
	ch1_rq <= ch1_rq | (ch1_req & clk3xIndex);
	ch2_rq <= ch2_rq | (ch2_req & clk3xIndex);
	ch3_rq <= ch3_rq | (ch3_req & clk3xIndex);
   
   ch3buf_addr <= ch3_addr;
   ch3buf_din  <= ch3_din;
   ch3buf_rnw  <= ch3_rnw;
   ch3buf_be   <= ch3_be;
	
	if (ch1_ready) ch1_ready_ramclock <= 0;
	if (ch2_ready) ch2_ready_ramclock <= 0;
	if (ch3_ready) ch3_ready_ramclock <= 0;
	
	if (dma_ack) dma_done <= 0;

	if (dma_reqprocessed) dma_reqprocessed_ramclock <= 0;

	dmafifo_read <= 0;

	refreshForce_1 <= refreshForce;
	refreshForce_req <= refreshForce_req | (refreshForce & ~refreshForce_1);

	refresh_count <= refresh_count+1'b1;

	data_ready_delay1 <= data_ready_delay1>>1;
	data_ready_delay2 <= data_ready_delay2>>1;
	data_ready_delay3 <= data_ready_delay3>>1;

	dq_reg <= SDRAM_DQ;
   
   cache_wr     <= 0;
   cache_done_0 <= 0;
   cache_done_1 <= 0;
   cache_done_2 <= 0;
   cache_done_3 <= 0;
   if (cache_done_0) begin cache_data <= ch1_dout[ 31: 0]; cache_wr <= cache_wr_next; cache_wr_next <= { cache_wr_next[2:0], 1'b0 }; end
   if (cache_done_1) begin cache_data <= ch1_dout[ 63:32]; cache_wr <= cache_wr_next; cache_wr_next <= { cache_wr_next[2:0], 1'b0 }; end
   if (cache_done_2) begin cache_data <= ch1_dout[ 95:64]; cache_wr <= cache_wr_next; cache_wr_next <= { cache_wr_next[2:0], 1'b0 }; end
   if (cache_done_3) begin cache_data <= ch1_dout[127:96]; cache_wr <= cache_wr_next; cache_wr_next <= { cache_wr_next[2:0], 1'b0 }; end
      
   if(data_ready_delay1[7]) ch1_dout[ 15: 00]  <= dq_reg;
   if(data_ready_delay1[6]) ch1_dout[ 31: 16]  <= dq_reg;
   if(data_ready_delay1[5]) ch1_dout[ 47: 32]  <= dq_reg;
   if(data_ready_delay1[4]) ch1_dout[ 63: 48]  <= dq_reg;
   if(data_ready_delay1[3]) ch1_dout[ 79: 64]  <= dq_reg;
   if(data_ready_delay1[2]) ch1_dout[ 95: 80]  <= dq_reg;
   if(data_ready_delay1[1]) ch1_dout[111: 96]  <= dq_reg;
   if(data_ready_delay1[0]) ch1_dout[127:112]  <= dq_reg;
   if(data_ready_delay1[6] && ~dma_buffer && ~cache_buffer_next) ch1_ready_ramclock <= 1;
   if(data_ready_delay1[2] && cache_buffer_next)                 ch1_ready_ramclock <= 1;
   if(data_ready_delay1[6] && dma_buffer)                        dma_done <= 1;

   if(data_ready_delay1[7]) cache_buffer_next <= cache_buffer;
   if(data_ready_delay1[6] && cache_buffer_next) cache_done_0 <= 1;
   if(data_ready_delay1[4] && cache_buffer_next) cache_done_1 <= 1;
   if(data_ready_delay1[2] && cache_buffer_next) cache_done_2 <= 1;
   if(data_ready_delay1[0] && cache_buffer_next) cache_done_3 <= 1;

	if(data_ready_delay2[7]) ch2_dout[15:00]    <= dq_reg;
	if(data_ready_delay2[6]) ch2_dout[31:16]    <= dq_reg;
	if(data_ready_delay2[2]) ch2_ready_ramclock <= 1;

	if(data_ready_delay3[7]) ch3_dout[15:00]    <= dq_reg;
	if(data_ready_delay3[6]) ch3_dout[31:16]    <= dq_reg;
	if(data_ready_delay3[2]) ch3_ready_ramclock <= 1;

	SDRAM_DQ <= 16'bZ;
   
   if (SDRAM_EN) begin
   
      command <= CMD_NOP;
      case (state)
         STATE_STARTUP: begin
            SDRAM_A    <= 0;
            SDRAM_BA   <= 0;
   
            if (refresh_count == (startup_refresh_max-64)) chip <= 0;
            if (refresh_count == (startup_refresh_max-32)) chip <= 1;
   
            // All the commands during the startup are NOPS, except these
            if (refresh_count == startup_refresh_max-63 || refresh_count == startup_refresh_max-31) begin
               // ensure all rows are closed
               command     <= CMD_PRECHARGE;
               SDRAM_A[10] <= 1;  // all banks
               SDRAM_BA    <= 2'b00;
            end
            if (refresh_count == startup_refresh_max-55 || refresh_count == startup_refresh_max-23) begin
               // these refreshes need to be at least tREF (66ns) apart
               command     <= CMD_AUTO_REFRESH;
            end
            if (refresh_count == startup_refresh_max-47 || refresh_count == startup_refresh_max-15) begin
               command     <= CMD_AUTO_REFRESH;
            end
            if (refresh_count == startup_refresh_max-39 || refresh_count == startup_refresh_max-7) begin
               // Now load the mode register
               command     <= CMD_LOAD_MODE;
               SDRAM_A     <= MODE;
            end
   
            if (!refresh_count) begin
               state   <= STATE_IDLE;
               refresh_count <= 0;
            end
         end
   
         STATE_IDLE_9: begin
            state <= STATE_IDLE_8;
            if (saved_128read) begin
               cas_addr[8:0] <= cas_addr[8:0] + 2'd2;
            end
         end
         
         STATE_IDLE_8: begin
            state   <= STATE_IDLE_7;
            if (saved_128read) begin
               command <= CMD_READ;
               SDRAM_A <= cas_addr;
            end
         end
         
         STATE_IDLE_7: begin
            state <= STATE_IDLE_6;
            if (saved_128read) begin
               cas_addr[8:0] <= cas_addr[8:0] + 2'd2;
            end
         end
         
         STATE_IDLE_6: begin 
            state <= STATE_IDLE_5;
            if (saved_128read) begin
               command <= CMD_READ;
               SDRAM_A <= cas_addr;
            end
         end
         
         STATE_IDLE_5: begin 
            state <= STATE_IDLE_4;
            if (saved_128read) begin
               cas_addr[8:0] <= cas_addr[8:0] + 2'd2;
            end
         end
         
         STATE_IDLE_4: begin
            state <= STATE_IDLE_3;
            if (saved_128read) begin
               command       <= CMD_READ;
               SDRAM_A       <= cas_addr;
               saved_128read <= 0;
            end
         end
         
         STATE_IDLE_3: begin
            state <= STATE_IDLE_2;
         end
         
         STATE_IDLE_2: begin
            state <= STATE_IDLE_1;
         end
         
         STATE_IDLE_1: begin
            state      <= STATE_IDLE;
            // mask possible refresh to reduce colliding.
            if (refresh_count > cycles_per_refresh) begin
               //------------------------------------------------------------------------
               //-- Start the refresh cycle. 
               //-- This tasks tRFC (66ns), so 7 idle cycles are needed @ 120MHz
               //------------------------------------------------------------------------
               state    <= STATE_RFSH;
               command  <= CMD_AUTO_REFRESH;
               chip     <= 0;
               refresh_count <= refresh_count - cycles_per_refresh + 1'd1;
            end
         end
   
         STATE_RFSH: begin
            state    <= STATE_IDLE_5;
            command  <= CMD_AUTO_REFRESH;
            chip     <= 1;
         end
   
         STATE_IDLE: begin
            saved_128read <= 0;
            if (refreshForce_req || refresh_count > cycles_per_refresh) begin
               state            <= STATE_RFSH;
               command          <= CMD_AUTO_REFRESH;
               chip             <= 0;
               refreshForce_req <= 0;
               if (refresh_count > cycles_per_refresh)
                  refresh_count <= refresh_count - cycles_per_refresh + 1'd1;
               else
                  refresh_count <= 14'd0;
               
            end else if(~dmafifo_empty) begin
               {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b0, dmafifo_adr[25:1]};
               chip         <= dmafifo_adr[26];
               saved_data   <= dmafifo_data;
               saved_wr     <= 1'b1;
               saved_be     <= 4'b1111;
               ch           <= 1;
               command      <= CMD_ACTIVE;
               state        <= STATE_WAIT;
               dmafifo_read <= 1'b1;
               lastbank     <= dmafifo_adr[20:10];
            end else if(ch1_req | ch1_rq) begin
               {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b1, ch1_addr[25:1]};
               chip         <= ch1_addr[26];
               saved_data   <= ch1_din;
               saved_wr     <= ~ch1_rnw;
               ch           <= 0;
               ch1_rq       <= 0;
               command      <= CMD_ACTIVE;
               state        <= STATE_WAIT;

               cache_buffer <= ch1_cache;
               cache_addr   <= ch1_addr[11:4];
               if (ch1_addr[3:2] == 2'b00) cache_wr_next <= 4'b0001;
               if (ch1_addr[3:2] == 2'b01) cache_wr_next <= 4'b0010;
               if (ch1_addr[3:2] == 2'b10) cache_wr_next <= 4'b0100;
               if (ch1_addr[3:2] == 2'b11) cache_wr_next <= 4'b1000;
               
               dma_buffer                <= ch1_dma;
               dma_reqprocessed_ramclock <= ch1_dma;
               dma_count_3x              <= ch1_cntDMA;
               
               saved_128read <= ch1_dma | ch1_cache;
               
            end else if(ch2_req | ch2_rq) begin
               {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {~ch2_be[1:0], ch2_rnw, ch2_addr[25:1]};
               chip       <= ch2_addr[26];
               saved_data <= ch2_din;
               saved_wr   <= ~ch2_rnw;
               saved_be   <= ch2_be;
               ch         <= 1;
               ch2_rq     <= 0;
               command    <= CMD_ACTIVE;
               state      <= STATE_WAIT;
               ch2_ready_ramclock <= 1;
            end else if(ch3_rq) begin
               {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {~ch3buf_be[1:0], ch3buf_rnw, ch3buf_addr[25:1]};
               chip       <= ch3buf_addr[26];
               saved_data <= ch3buf_din;
               saved_wr   <= ~ch3buf_rnw;
               saved_be   <= ch3buf_be;
               ch         <= 2;
               ch3_rq     <= 0;
               command    <= CMD_ACTIVE;
               state      <= STATE_WAIT;
            end
         end
   
         STATE_WAIT: state <= STATE_RW1;
         STATE_RW1: begin
            SDRAM_A <= cas_addr;
            if(saved_wr) begin
               command  <= CMD_WRITE;
               SDRAM_DQ <= saved_data[15:0];
               if(!ch) begin
                  ch1_ready_ramclock  <= 1;
                  state <= STATE_IDLE_2;
               end
               else begin
                  state <= STATE_RW2;
               end
            end
            else begin
               command <= CMD_READ;
               state   <= STATE_IDLE_9;
                  if(ch == 0) data_ready_delay1[CAS_LATENCY+BURST_LENGTH] <= 1;
               else if(ch == 1) data_ready_delay2[CAS_LATENCY+BURST_LENGTH] <= 1;
               else             data_ready_delay3[CAS_LATENCY+BURST_LENGTH] <= 1;
            end
         end
   
         STATE_RW2: begin
            if(ch == 1) begin
               SDRAM_A[0]           <= 1;
               command              <= CMD_WRITE;
               SDRAM_DQ             <= saved_data[31:16];
               SDRAM_A[12:11]       <= ~saved_be[3:2];
               if(~dmafifo_empty && (lastbank == dmafifo_adr[20:10])) begin
                  cas_addr[8:0]     <= dmafifo_adr[9:1];
                  saved_data        <= dmafifo_data;
                  state             <= STATE_RW1;
                  dmafifo_read      <= 1'b1;
               end else begin
                  state             <= STATE_IDLE_2;
                  SDRAM_A[10]       <= 1;
               end
            end
            else begin
               state                <= STATE_IDLE_2;
               SDRAM_A[10]          <= 1;
               SDRAM_A[0]           <= 1;
               command              <= CMD_WRITE;
               SDRAM_DQ             <= saved_data[31:16];
               SDRAM_A[12:11]       <= ~saved_be[3:2];
               ch3_ready_ramclock   <= 1;
            end
         end
      endcase
   
      if (init) begin
         state <= STATE_STARTUP;
         refresh_count <= startup_refresh_max - sdram_startup_cycles;
      end
   end
	else begin
		SDRAM_A <= 'Z;
		SDRAM_BA <= 'Z;
		command <= 'Z;
		chip <= 'Z;
	end   
end

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(SDRAM_EN),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

endmodule
