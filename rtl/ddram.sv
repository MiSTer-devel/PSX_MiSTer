//
// ddram.v
// Copyright (c) 2019 Sorgelig
//
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
//
// ------------------------------------------
//

module ddram
(
	input         DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
	
	input  [27:1] ch1_addr,
	output [63:0] ch1_dout,
	input  [15:0] ch1_din,
	input         ch1_req,
	input         ch1_rnw,
	output        ch1_ready,

	input  [27:1] ch2_addr,
	output [31:0] ch2_dout,
	input  [31:0] ch2_din,
	input         ch2_req,
	input         ch2_rnw,
	output        ch2_ready,

	// data is packed 64bit -> 16bit
	input  [25:1] ch3_addr,
	output [15:0] ch3_dout,
	input  [15:0] ch3_din,
	input         ch3_req,
	input         ch3_rnw,
	output        ch3_ready,

	// save state
	input  [27:1] ch4_addr,
	output [63:0] ch4_dout,
	input  [63:0] ch4_din,
	input         ch4_req,
	input         ch4_rnw,
	input  [7:0]  ch4_be,
	output        ch4_ready,
   
   // framebuffer
	input  [27:1] ch5_addr,
	input  [63:0] ch5_din,
	input         ch5_req,
	output        ch5_ready
);

reg  [7:0] ram_burst;
reg [63:0] ram_q[4:1];
reg [63:0] ram_data;
reg [27:1] ram_address;
reg        ram_read = 0;
reg        ram_write = 0;
reg  [7:0] ram_be;

reg  [5:1] ready;

assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = ram_read ? 8'hFF : ram_be;
assign DDRAM_ADDR     = {4'b0011, ram_address[27:3]}; // RAM at 0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_data;
assign DDRAM_WE       = ram_write;

assign ch1_dout  = ch1_addr[2] ? {ram_q[1][31:0], ram_q[1][63:32]} : ram_q[1];
assign ch2_dout  = ch2_addr[2] ? ram_q[2][63:32] : ram_q[2][31:0];
assign ch3_dout  = {ram_q[3][39:32], ram_q[3][7:0]};
assign ch4_dout  = ram_q[4];
assign ch1_ready = ready[1];
assign ch2_ready = ready[2];
assign ch3_ready = ready[3];
assign ch4_ready = ready[4];
assign ch5_ready = ready[5];

reg [63:0] next_q[2:1];
reg [27:1] cache_addr[2:1];
reg  [1:0] state  = 0;
reg  [2:1] cached = 0;
reg  [2:0] ch = 0; 
reg  [5:1] ch_rq;

always @(posedge DDRAM_CLK) begin


	ch_rq <= ch_rq | {ch5_req, ch4_req, ch3_req, ch2_req, ch1_req};
	ready <= 0;

	if(!DDRAM_BUSY) begin
		ram_write <= 0;
		ram_read  <= 0;

		case(state)
			0: if(ch_rq[1] || ch1_req) begin
					ch_rq[1]         <= 0;
					ch               <= 1;
					ram_data         <= {4{ch1_din}};
					ram_be           <= 8'h03 << {ch1_addr[2:1],1'b0};
					if(~ch1_rnw) begin
						ram_address   <= ch1_addr;
						ram_write     <= 1;
						ram_burst     <= 1;
						cached[1]     <= 0;
						ready[1]      <= 1;
					end
					else if(cached[1] && cache_addr[1][27:3] == ch1_addr[27:3]) begin
						ready[1]      <= 1;
					end
					else if(cached[1] && (cache_addr[1][27:3]+1'd1) == ch1_addr[27:3]) begin
						ram_q[1]      <= next_q[1];
						cache_addr[1] <= ch1_addr;
						ram_address   <= ch1_addr + 8'd4;
						ram_read      <= 1;
						ram_burst     <= 1;
						cached[1]     <= 1;
						ready[1]      <= 1;
						state         <= 2;
					end
					else begin
						ram_address   <= ch1_addr;
						cache_addr[1] <= ch1_addr;
						ram_read      <= 1;
						ram_burst     <= 2;
						cached[1]     <= 1;
						state         <= 1;
					end
				end
			   else if(ch_rq[2] || ch2_req) begin
					ch_rq[2]         <= 0;
					ch               <= 2;
					ram_data         <= {2{ch2_din}};
					ram_be           <= ch2_addr[2] ? 8'hF0 : 8'h0F;
					if(~ch2_rnw) begin
						ram_address   <= ch2_addr;
						ram_write     <= 1;
						ram_burst     <= 1;
						cached[2]     <= 0;
						ready[2]      <= 1;
					end
					else if(cached[2] && cache_addr[2][27:3] == ch2_addr[27:3]) begin
						ready[2]      <= 1;
					end
					else if(cached[2] && (cache_addr[2][27:3]+1'd1) == ch2_addr[27:3]) begin
						ram_q[2]      <= next_q[2];
						cache_addr[2] <= ch2_addr;
						ram_address   <= ch2_addr + 8'd4;
						ram_read      <= 1;
						ram_burst     <= 1;
						cached[2]     <= 1;
						ready[2]      <= 1;
						state         <= 2;
					end
					else begin
						ram_address   <= ch2_addr;
						cache_addr[2] <= ch2_addr;
						ram_read      <= 1;
						ram_burst     <= 2;
						cached[2]     <= 1;
						state         <= 1;
					end
				end
			   else if(ch_rq[3] || ch3_req) begin
					ch_rq[3]         <= 0;
					ch               <= 3;
					ram_address      <= {ch3_addr, 2'b00};
					ram_data         <= {24'd0, ch3_din[15:8], 24'd0, ch3_din[7:0]};
					ram_be           <= 8'hFF;
					ram_burst        <= 1;
					if(~ch3_rnw) begin
						ram_write     <= 1;
						cached[2]     <= 0;
						ready[3]      <= 1;
					end
					else begin
						ram_read      <= 1;
						state         <= 1;
					end
				end
			   else if(ch_rq[4] || ch4_req) begin
					ch_rq[4]         <= 0;
					ch               <= 4;
					ram_data         <= ch4_din;
					ram_be           <= ch4_be;
					ram_address      <= ch4_addr;
					ram_burst        <= 1;
					if(~ch4_rnw) begin
						ram_write     <= 1;
						ready[4]      <= 1;
					end
					else begin
						ram_read      <= 1;
						state         <= 1;
					end
            end
            else if(ch_rq[5] || ch5_req) begin
					ch_rq[5]         <= 0;
					ch               <= 5;
					ram_data         <= ch5_din;
					ram_be           <= 8'hFF;
               ram_address      <= ch5_addr;
               ram_write        <= 1;
               ram_burst        <= 1;
               ready[5]         <= 1;
				end

			1: if(DDRAM_DOUT_READY) begin
					ram_q[ch]        <= DDRAM_DOUT;
					ready[ch]        <= 1;
					state            <= {ram_burst[1], 1'b0};
				end

			2: if(DDRAM_DOUT_READY) begin
					next_q[ch]       <= DDRAM_DOUT;
					state            <= 0;
				end
		endcase
	end
end

endmodule
