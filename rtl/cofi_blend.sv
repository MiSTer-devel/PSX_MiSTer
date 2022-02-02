// Smart blender module for removing dithering patterns
// Originally based on module cofi from Genesis core

module cofi_blender (
    input        clk,
    input        ce_pixel,
    input        force_blend,      // force blending for current pixel
    input        diff_blend,       // enable blend method based on detecting relative color difference between adjacent pixels
    input        reduced,          // reduce blending strength

    input        hblank,
    input        vblank,
    input        hsync,
    input        vsync,
    input  [7:0] red,
    input  [7:0] green,
    input  [7:0] blue,

    output reg       hblank_out,
    output reg       vblank_out,
    output reg       hsync_out,
    output reg       vsync_out,
    output reg [7:0] red_out,
    output reg [7:0] green_out,
    output reg [7:0] blue_out
);

function bit abs_diff (
    input [7:0] color1,
    input [7:0] color2,
    input [7:0] diff
);
begin
    abs_diff = (( (color1 > color2) ? (color1 - color2) : (color2 - color1) ) > diff) ? 1'b1 : 1'b0;
end 
endfunction

function bit [7:0] blend (
    input [7:0] color,
    input [7:0] color_blend,
    input enable
);
var
    reg [8:0] sum;
begin
    sum = color;
    sum = sum + color_blend;
    blend = enable ? sum[8:1] :color;
end
endfunction

function bit [7:0] blend_pcn (
    input [7:0] color_prev,
    input [7:0] color_curr,
    input [7:0] color_next,
    input enable_prev,
    input enable_next
);
var
    reg [8:0] sum;
    reg [8:0] sum2;
begin
    sum = color_curr + (enable_next ? color_next[7:1] : color_curr[7:1]);
    sum2 = sum + (enable_prev ? color_prev[7:1] : color_curr[7:1]);
    blend_pcn = sum2[8:1];
end
endfunction

reg [2:0] hblank_shift, vblank_shift, hsync_shift, vsync_shift;
reg [6:0] lblend_shift, rblend_shift;
reg [47:0] red_shift, green_shift, blue_shift;

assign hblank_out = hblank_shift[1];
assign vblank_out = vblank_shift[1];
assign hsync_out = hsync_shift[1];
assign vsync_out = vsync_shift[1];

always @(posedge clk) if (ce_pixel) begin
    hblank_shift = {hblank_shift[1:0], hblank};
    vblank_shift = {vblank_shift[1:0], vblank};
    hsync_shift = {hsync_shift[1:0], hsync};
    vsync_shift = {vsync_shift[1:0], vsync};
    red_shift = {red_shift[39:0], red};
    green_shift = {green_shift[39:0], green};
    blue_shift = {blue_shift[39:0], blue};
    lblend_shift = {lblend_shift[5:0], force_blend};
    rblend_shift = {rblend_shift[5:0], force_blend};

    //level difference filter
    if (diff_blend
        && ~abs_diff(red_shift[15:8], red_shift[7:0], 8'd32)
        && ~abs_diff(green_shift[15:8], green_shift[7:0], 8'd32)
        && ~abs_diff(blue_shift[15:8], blue_shift[7:0], 8'd32))
    begin
        lblend_shift[0] = 1'b1;
        rblend_shift[1] = 1'b1;
    end

    // blend adjacent pixels based on rblend and lblend
    red_out   = blend_pcn(blend(red_shift[23:16], red_shift[15:8], reduced),
                          red_shift[15:8],
                          blend(red_shift[7:0], red_shift[15:8] , reduced),
                          rblend_shift[2], lblend_shift[0]);
    green_out = blend_pcn(blend(green_shift[23:16], green_shift[15:8], reduced),
                          green_shift[15:8],
                          blend(green_shift[7:0], green_shift[15:8] , reduced),
                          rblend_shift[2], lblend_shift[0]);
    blue_out  = blend_pcn(blend(blue_shift[23:16], blue_shift[15:8], reduced),
                          blue_shift[15:8],
                          blend(blue_shift[7:0], blue_shift[15:8] , reduced),
                          rblend_shift[2], lblend_shift[0]);
end

endmodule

