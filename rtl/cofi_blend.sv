// Smart blender based on module cofi from Genesis core
// Added patterns recognition blending with HUD filter
// Added color difference based blending

module cofi_blender (
    input        clk,
    input        ce_pixel,
    input        force_blend,   // force blending for current pixel
    input        pattern_blend, // enable blend method based on dithering pattern recognition
    input        hud_filter,    // disables pattern based blending based on absolute RGB values
    input        diff_blend,    // enable blend method based on detecting relative color difference between adjacent pixels

    input        debug_view,    //highlights parts of frame which are not blended in red

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

function bit [7:0] color_blend (
    input [7:0] color_prev,
    input [7:0] color_curr
);
var
    reg [8:0] sum;
begin
    sum = color_curr;
    sum = sum + color_prev;
    color_blend = sum[8:1];
end
endfunction

reg hblank_back4, hblank_back3, hblank_back2, hblank_back1;
reg vblank_back4, vblank_back3, vblank_back2, vblank_back1;
reg hsync_back4, hsync_back3, hsync_back2, hsync_back1;
reg vsync_back4, vsync_back3, vsync_back2, vsync_back1;
reg blend_back5, blend_back4, blend_back3, blend_back2, blend_back1, blend_adaptive;

reg [7:0] red_back5, red_back4, red_back3, red_back2, red_back1;
reg [7:0] green_back5, green_back4, green_back3, green_back2, green_back1;
reg [7:0] blue_back5, blue_back4, blue_back3, blue_back2, blue_back1;

wire filter_red = abs_diff(red_back4, red_back3, 8'd166);
wire filter_green = (abs_diff(green_back4, green_back3, 8'd130) && abs_diff(blue_back4, green_back3, 8'd160 && abs_diff(green_back4, blue_back3, 8'd160)));
wire filter_blue = abs_diff(blue_back4, blue_back3, 8'd208);
wire filter_color = filter_red || filter_green || filter_blue;

always @(posedge clk) if (ce_pixel) begin
        hblank_out = hblank_back1;
        vblank_out = vblank_back1;
        hsync_out     = hsync_back1;
        vsync_out     = vsync_back1;

        // delay signals
        hblank_back1 = hblank_back2;
        hblank_back2 = hblank_back3;
        hblank_back3 = hblank_back4;
        hblank_back4 = hblank;
        vblank_back1 = vblank_back2;
        vblank_back2 = vblank_back3;
        vblank_back3 = vblank_back4;
        vblank_back4 = vblank;
        hsync_back1 = hsync_back2;
        hsync_back2 = hsync_back3;
        hsync_back3 = hsync_back4;
        hsync_back4 = hsync;
        vsync_back1 = vsync_back2;
        vsync_back2 = vsync_back3;
        vsync_back3 = vsync_back4;
        vsync_back4 = vsync;

        // get history of colors
        red_back1 = red_back2;
        red_back2 = red_back3;
        red_back3 = red_back4;
        red_back4 = red_back5;
        red_back5 = red;
        
        green_back1 = green_back2;
        green_back2 = green_back3;
        green_back3 = green_back4;
        green_back4 = green_back5;
        green_back5 = green;
        
        blue_back1 = blue_back2;
        blue_back2 = blue_back3;
        blue_back3 = blue_back4;
        blue_back4 = blue_back5;
        blue_back5 = blue;
        
        blend_back1 = blend_back2;
        blend_back2 = blend_back3;
        blend_back3 = blend_back4;
        blend_back4 = blend_back5;
        blend_back5 = force_blend;

        if (pattern_blend) begin
            if ( //bAbA filter
                    (
                        {red_back4, green_back4, blue_back4} == {red_back2, green_back2, blue_back2}
                    ) && (
                        {red_back3, green_back3, blue_back3} == {red_back1, green_back1, blue_back1}
                    ) && (hud_filter ? ~filter_color : 1'b1)
                )
                    {blend_back3, blend_back2} = 2'b11;
                    
            if ( //bbAbb filter
                    (
                        {red_back5, green_back5, blue_back5} == {red_back4, green_back4, blue_back4}
                    ) && (
                        {red_back4, green_back4, blue_back4} == {red_back2, green_back2, blue_back2}
                    ) && (
                        {red_back2, green_back2, blue_back2} == {red_back1, green_back1, blue_back1}
                    ) && (hud_filter ? ~filter_color : 1'b1)
                )
                    {blend_back4, blend_back3, blend_back2} = 3'b111;
        end
                
        if //level difference filter
            (diff_blend && ~abs_diff(red_back4, red_back3, 8'd32) && ~abs_diff(green_back4, green_back3, 8'd32) && ~abs_diff(blue_back4, blue_back3, 8'd32))
                blend_back3 = 1'b1;

        // blend adjacent pixels
        red_out    = blend_back1 ? color_blend(red_back1, red_back2) : (debug_view ? 8'hff : red_back1);
        green_out  = blend_back1 ? color_blend(green_back1, green_back2) : green_back1;
        blue_out   = blend_back1 ? color_blend(blue_back1,  blue_back2) : blue_back1;
end

endmodule
