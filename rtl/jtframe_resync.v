//============================================================================
//  jtframe_resync - Sync pulse repositioning
//  Based on JTFRAME (J. Tejada) - ported to MiSTer PSX for CRT H/V offset.
//
//  This module re-times the HSYNC and VSYNC pulses by a configurable
//  offset, allowing the user to recenter the picture on a CRT.
//
//  2026 port for PSX_MiSTer
//============================================================================

module jtframe_resync #(parameter BITS=4)(
    input         clk,
    input         pxl_cen,
    input         hs_in,
    input         vs_in,
    input         LVBL,
    input         LHBL,
    input  [BITS - 1:0]  hoffset,
    input  [BITS - 1:0]  voffset,
    output reg    hs_out,
    output reg    vs_out
);

parameter CNTW = 10; // max 1024 pixels/lines

reg [CNTW-1:0]   hs_pos[0:1], vs_hpos[0:1], vs_vpos[0:1],
                 hs_len[0:1], vs_len[0:1],
                 hs_cnt,      vs_cnt,
                 hs_hold,     vs_hold;
reg              last_LHBL, last_LVBL, last_hsin, last_vsin;

wire             hb_edge, hs_edge, hs_n_edge, vb_edge, vs_edge, vs_n_edge;
reg              field;

wire [CNTW-1:0]  hpos_off = { {CNTW-BITS{hoffset[BITS - 1]}}, hoffset[(BITS-1):0]  };
wire [CNTW-1:0]  htrip = hs_pos[field] + hpos_off;
wire [CNTW-1:0]  vs_htrip = vs_hpos[field] + hpos_off;
wire [CNTW-1:0]  vs_vtrip = vs_vpos[field] + { {CNTW-BITS{voffset[BITS-1]}}, voffset[(BITS-1):0]  };

assign hb_edge = LHBL && !last_LHBL;
assign hs_edge = hs_in && !last_hsin;
assign hs_n_edge = !hs_in && last_hsin;
assign vb_edge = LVBL && !last_LVBL;
assign vs_edge = vs_in && !last_vsin;
assign vs_n_edge = !vs_in && last_vsin;

always @(posedge clk) if(pxl_cen) begin
    last_LHBL <= LHBL;
    last_LVBL <= LVBL;
    last_hsin <= hs_in;
    last_vsin <= vs_in;

    hs_cnt <= hb_edge ? {CNTW{1'b0}} : hs_cnt+1'b1;
    if( vb_edge ) begin
        vs_cnt <= {CNTW{1'b0}};
        field <= ~field;
    end else if(hb_edge)
        vs_cnt <= vs_cnt+1'b1;

    if( hs_edge ) hs_pos[field] <= hs_cnt;
    if( hs_n_edge ) hs_len[field] <= hs_cnt - hs_pos[field];

    if( hs_cnt == htrip ) begin
        hs_out <= 1;
        hs_hold <= hs_len[field] - 1'b1;
    end else begin
        if( |hs_hold ) hs_hold <= hs_hold - 1'b1;
        if( hs_hold == 0 ) hs_out <= 0;
    end

    if( vs_edge ) begin
        vs_hpos[field] <= hs_cnt;
        vs_vpos[field] <= vs_cnt;
    end
    if( vs_n_edge ) vs_len[field] <= vs_cnt - vs_vpos[field];

    if( hs_cnt == vs_htrip ) begin
        if( vs_cnt == vs_vtrip ) begin
            vs_hold <= vs_len[field] - 1'b1;
            vs_out <= 1;
        end else begin
            if( |vs_hold ) vs_hold <= vs_hold - 1'b1;
            if( vs_hold == 0 ) vs_out <= 0;
        end
    end

end

`ifdef SIMULATION
initial begin
    hs_cnt = {CNTW{1'b0}};
    vs_cnt = {CNTW{1'b0}};
    hs_out = 0;
    vs_out = 0;
end
`endif

endmodule