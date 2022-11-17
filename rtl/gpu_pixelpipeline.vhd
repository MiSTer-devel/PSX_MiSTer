library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity gpu_pixelpipeline is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      noTexture            : in  std_logic;
      render24             : in  std_logic;
      
      drawMode_in          : in  unsigned(13 downto 0) := (others => '0');
      DrawPixelsMask_in    : in  std_logic;
      SetMask_in           : in  std_logic;
      
      clearCacheTexture    : in  std_logic;
      clearCachePalette    : in  std_logic;
      
      fifoOut_idle         : in  std_logic;
      pipeline_busy        : out std_logic;
      pipeline_stall       : out std_logic;
      pipeline_new         : in  std_logic;
      pipeline_texture     : in  std_logic;
      pipeline_transparent : in  std_logic;
      pipeline_rawTexture  : in  std_logic;
      pipeline_dithering   : in  std_logic;
      pipeline_x           : in  unsigned(9 downto 0);
      pipeline_y           : in  unsigned(8 downto 0);
      pipeline_cr          : in  unsigned(7 downto 0);
      pipeline_cg          : in  unsigned(7 downto 0);
      pipeline_cb          : in  unsigned(7 downto 0);
      pipeline_u           : in  unsigned(7 downto 0);
      pipeline_v           : in  unsigned(7 downto 0);
      pipeline_filter      : in  std_logic;   
      pipeline_u11         : in  unsigned(7 downto 0);
      pipeline_v11         : in  unsigned(7 downto 0);
      pipeline_uAcc        : in  unsigned(7 downto 0);
      pipeline_vAcc        : in  unsigned(7 downto 0);
      
      requestVRAMEnable    : out std_logic;
      requestVRAMXPos      : out unsigned(9 downto 0);
      requestVRAMYPos      : out unsigned(8 downto 0);
      requestVRAMSize      : out unsigned(10 downto 0);
      requestVRAMIdle      : in  std_logic;
      requestVRAMDone      : in  std_logic;
      vram_DOUT            : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY      : in  std_logic;
      
      vramLineData         : in  std_logic_vector(15 downto 0);
      vramLineData2        : in  std_logic_vector(15 downto 0);
      
      textPalInNew         : in  std_logic;
      textPalInX           : in  unsigned(9 downto 0);   
      textPalInY           : in  unsigned(8 downto 0); 
      
      pixelStall           : in  std_logic;
      pixelColor           : out std_logic_vector(15 downto 0);
      pixelColor2          : out std_logic_vector(15 downto 0);
      pixelAddr            : out unsigned(19 downto 0);
      pixelWrite           : out std_logic
   );
end entity;

architecture arch of gpu_pixelpipeline is
  
   type tDitherMatrix is array(0 to 3, 0 to 3) of integer range -4 to 4;
   constant	DITHERMATRIX : tDitherMatrix := 
   (
		(-4, +0, -3, +1),
		(+2, -2, +3, -1),
		(-3, +1, -4, +0),
		(+3, -1, +2, -2)
	);
   
   type t_filterarray_u2  is array(0 to 3) of unsigned(1 downto 0);
   type t_filterarray_u8  is array(0 to 3) of unsigned(7 downto 0);
   type t_filterarray_u9  is array(0 to 3) of unsigned(8 downto 0);
   type t_filterarray_u10 is array(0 to 3) of unsigned(9 downto 0);
   type t_filterarray_u20 is array(0 to 3) of unsigned(19 downto 0);
   type t_filterarray_b8  is array(0 to 3) of std_logic_vector(7 downto 0);
   type t_filterarray_b10 is array(0 to 3) of std_logic_vector(9 downto 0);
   type t_filterarray_b16 is array(0 to 3) of std_logic_vector(15 downto 0);
   type t_filterarray_b64 is array(0 to 3) of std_logic_vector(63 downto 0);
   
   signal drawMode            : unsigned(13 downto 0) := (others => '0');
   signal DrawPixelsMask      : std_logic := '0';
   signal SetMask             : std_logic := '0';
   signal palette8bit         : std_logic := '0';
  
   signal tag_addr            : t_filterarray_u8;
   signal tag_data            : t_filterarray_u10;
   signal tag_data_1          : t_filterarray_u10;
      
   signal tag_address_a       : unsigned(7 downto 0) := (others => '0');
   signal tag_data_a          : std_logic_vector(9 downto 0) := (others => '0');
   signal tag_wren_a          : std_logic := '0';
   signal tag_q_b             : t_filterarray_b10;
      
   signal tagValid            : std_logic_vector(0 to 255) := (others => '0');
      
   signal cache_address_a     : unsigned(7 downto 0) := (others => '0');
   signal cache_wren_a        : std_logic := '0';
   signal cache_address_b     : t_filterarray_u8;
   signal tag_addr_1          : t_filterarray_u8;
   signal cache_q_b           : t_filterarray_b64;
   signal cachehit            : std_logic_vector(0 to 3);
   signal cacherequest        : std_logic_vector(0 to 3) := (others => '0');
      
   signal CLUTaddrA           : unsigned(5 downto 0) := (others => '0');
   signal CLUTwrenA           : std_logic;
   signal CLUTaddrB           : t_filterarray_b8;
   signal CLUTDataB           : t_filterarray_b16;
  
   signal clearCacheBuffer    : std_logic := '0';
   
   signal textPalReq          : std_logic := '0';
   signal textPalReqX         : unsigned(9 downto 0) := (others => '0');  
   signal textPalReqY         : unsigned(8 downto 0) := (others => '0'); 
  
   signal textPalFetched      : std_logic := '0';
   signal textPalX            : unsigned(9 downto 0) := (others => '0');   
   signal textPalY            : unsigned(8 downto 0) := (others => '0'); 
   signal textPalFetchNext    : integer range 0 to 3;
  
   type tState is
   (
      IDLE,
      REQUESTMORETEXTURE,
      REQUESTTEXTURE,
      WAITTEXTURE,
      REQUESTPALETTE,
      WAITPALETTE
   );
   signal state : tState := IDLE;
   
   signal pipeline_stall_1    : std_logic := '0';
   
   signal reqVRAMXPos         : unsigned(9 downto 0)  := (others => '0');
   signal reqVRAMYPos         : unsigned(8 downto 0)  := (others => '0');
   signal reqVRAMSize         : unsigned(10 downto 0) := (others => '0');
  
   signal stageS_valid        : std_logic := '0';
   signal stageS_texture      : std_logic := '0';
   signal stageS_transparent  : std_logic := '0';
   signal stageS_rawTexture   : std_logic := '0';
   signal stageS_dithering    : std_logic := '0';
   signal stageS_x            : unsigned(9 downto 0) := (others => '0');
   signal stageS_y            : unsigned(8 downto 0) := (others => '0');
   signal stageS_cr           : unsigned(7 downto 0) := (others => '0');
   signal stageS_cg           : unsigned(7 downto 0) := (others => '0');
   signal stageS_cb           : unsigned(7 downto 0) := (others => '0');
   signal stageS_u            : unsigned(7 downto 0) := (others => '0');
   signal stageS_v            : unsigned(7 downto 0) := (others => '0');
   signal stageS_filter       : std_logic := '0';   
   signal stageS_u11          : unsigned(7 downto 0) := (others => '0');
   signal stageS_v11          : unsigned(7 downto 0) := (others => '0');   
   signal stageS_uAcc         : unsigned(7 downto 0) := (others => '0');
   signal stageS_vAcc         : unsigned(7 downto 0) := (others => '0');
   signal stageS_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stageS_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');

   signal stage0_valid        : std_logic := '0';
   signal stage0_texture      : std_logic := '0';
   signal stage0_transparent  : std_logic := '0';
   signal stage0_rawTexture   : std_logic := '0';
   signal stage0_dithering    : std_logic := '0';
   signal stage0_x            : unsigned(9 downto 0) := (others => '0');
   signal stage0_y            : unsigned(8 downto 0) := (others => '0');
   signal stage0_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage0_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage0_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage0_u            : unsigned(7 downto 0) := (others => '0');
   signal stage0_v            : unsigned(7 downto 0) := (others => '0');
   signal stage0_filter       : std_logic := '0';   
   signal stage0_u11          : unsigned(7 downto 0) := (others => '0');
   signal stage0_v11          : unsigned(7 downto 0) := (others => '0');   
   signal stage0_uAcc         : unsigned(7 downto 0) := (others => '0');
   signal stage0_vAcc         : unsigned(7 downto 0) := (others => '0');
   signal stage0_oldPixel     : std_logic_vector(15 downto 0);
   signal stage0_oldPixel2    : std_logic_vector(15 downto 0);
   
   signal stage0_u_array      : t_filterarray_u8;
   signal stage0_v_array      : t_filterarray_u8;
   signal stage0_textaddr     : t_filterarray_u20;
   signal stage0_textaddr_1   : t_filterarray_u20;
   
   signal stage1_valid        : std_logic := '0';
   signal stage1_texture      : std_logic := '0';
   signal stage1_transparent  : std_logic := '0';
   signal stage1_rawTexture   : std_logic := '0';
   signal stage1_dithering    : std_logic := '0';
   signal stage1_x            : unsigned(9 downto 0) := (others => '0');
   signal stage1_y            : unsigned(8 downto 0) := (others => '0');
   signal stage1_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage1_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage1_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage1_u            : t_filterarray_u8;
   signal stage1_filter       : std_logic := '0';   
   signal stage1_uAcc         : unsigned(7 downto 0) := (others => '0');
   signal stage1_vAcc         : unsigned(7 downto 0) := (others => '0');
   signal stage1_oldPixel     : std_logic_vector(15 downto 0);
   signal stage1_oldPixel2    : std_logic_vector(15 downto 0);
   
   signal stage1_u_mux        : t_filterarray_u2;
   signal texdata_raw         : t_filterarray_b16;
   
   signal stage2_valid        : std_logic := '0';
   signal stage2_texture      : std_logic := '0';
   signal stage2_transparent  : std_logic := '0';
   signal stage2_rawTexture   : std_logic := '0';
   signal stage2_dithering    : std_logic := '0';
   signal stage2_x            : unsigned(9 downto 0) := (others => '0');
   signal stage2_y            : unsigned(8 downto 0) := (others => '0');
   signal stage2_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage2_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage2_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage2_filter       : std_logic := '0';   
   signal stage2_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage2_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');
   signal stage2_texdata      : t_filterarray_b16;
   
   signal texdata_palette     : t_filterarray_b16;
   
   type ttexcolor is array(0 to 3, 0 to 2) of unsigned(4 downto 0); 
   signal texcolor            : ttexcolor;
   
   signal colorIgnore         : std_logic_vector(0 to 3);
   
   signal filtermults         : t_filterarray_u9;
   
   type tcolormults is array(0 to 3, 0 to 2) of unsigned(13 downto 0); 
   signal colormults          : tcolormults;   
   
   type tcolormultadds is array(0 to 2) of unsigned(14 downto 0); 
   signal colormultadds       : tcolormultadds;
   
   type tfiltercolors is array(0 to 2) of unsigned(7 downto 0);
   signal filtercolors        : tfiltercolors;
   
   signal filtercolor_alpha   : std_logic; 
   
   signal useFilter           : std_logic;
   signal texdata_r           : unsigned(7 downto 0);
   signal texdata_g           : unsigned(7 downto 0);
   signal texdata_b           : unsigned(7 downto 0);
   signal texdata_alpha       : std_logic; 
   
   signal stage3_valid        : std_logic := '0';
   signal stage3_texture      : std_logic := '0';
   signal stage3_transparent  : std_logic := '0';
   signal stage3_rawTexture   : std_logic := '0';
   signal stage3_dithering    : std_logic := '0';
   signal stage3_x            : unsigned(9 downto 0) := (others => '0');
   signal stage3_y            : unsigned(8 downto 0) := (others => '0');
   signal stage3_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage3_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage3_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage3_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage3_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');
   signal stage3_tex_r        : unsigned(4 downto 0) := (others => '0');
   signal stage3_tex_g        : unsigned(4 downto 0) := (others => '0');
   signal stage3_tex_b        : unsigned(4 downto 0) := (others => '0');
   signal stage3_tex_alpha    : std_logic := '0';
   signal stage3_useFilter    : std_logic := '0';
   
   signal stage4_valid        : std_logic := '0';
   signal stage4_texture      : std_logic := '0';
   signal stage4_transparent  : std_logic := '0';
   signal stage4_rawTexture   : std_logic := '0';
   signal stage4_dithering    : std_logic := '0';
   signal stage4_x            : unsigned(9 downto 0) := (others => '0');
   signal stage4_y            : unsigned(8 downto 0) := (others => '0');
   signal stage4_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage4_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage4_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage4_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage4_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');
   signal stage4_ditherAdd    : integer range -4 to 4;
   signal stage4_tex_r        : unsigned(7 downto 0) := (others => '0');
   signal stage4_tex_g        : unsigned(7 downto 0) := (others => '0');
   signal stage4_tex_b        : unsigned(7 downto 0) := (others => '0');
   signal stage4_tex_alpha    : std_logic := '0';
   signal stage4_useFilter    : std_logic := '0';
   
   signal stage5_valid        : std_logic := '0';
   signal stage5_transparent  : std_logic := '0';
   signal stage5_alphacheck   : std_logic := '0';
   signal stage5_alphabit     : std_logic := '0';
   signal stage5_x            : unsigned(9 downto 0) := (others => '0');
   signal stage5_y            : unsigned(8 downto 0) := (others => '0');
   signal stage5_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage5_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage5_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage5_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage5_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');
   
   signal stage6_valid        : std_logic := '0';
   signal stage6_alphabit     : std_logic := '0';
   signal stage6_x            : unsigned(9 downto 0) := (others => '0');
   signal stage6_y            : unsigned(8 downto 0) := (others => '0');
   signal stage6_cr           : std_logic_vector(7 downto 0) := (others => '0');
   signal stage6_cg           : std_logic_vector(7 downto 0) := (others => '0');
   signal stage6_cb           : std_logic_vector(7 downto 0) := (others => '0');
  
begin 

   pipeline_stall <= '1' when (pixelStall = '1' or state /= IDLE) else '0';

   requestVRAMEnable <= '1'         when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or (state = REQUESTPALETTE and fifoOut_idle = '1'))) else '0';
   requestVRAMXPos   <= reqVRAMXPos when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or (state = REQUESTPALETTE and fifoOut_idle = '1'))) else (others => '0');
   requestVRAMYPos   <= reqVRAMYPos when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or (state = REQUESTPALETTE and fifoOut_idle = '1'))) else (others => '0');
   requestVRAMSize   <= reqVRAMSize when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or (state = REQUESTPALETTE and fifoOut_idle = '1'))) else (others => '0');
   
   stage0_u_array(0) <= stage0_u; 
   stage0_u_array(1) <= stage0_u;
   stage0_u_array(2) <= stage0_u11;
   stage0_u_array(3) <= stage0_u11;
   
   stage0_v_array(0) <= stage0_v; 
   stage0_v_array(1) <= stage0_v11;
   stage0_v_array(2) <= stage0_v;
   stage0_v_array(3) <= stage0_v11;

   gfiltermemmult : for i in 0 to 3 generate
   begin
   
      itagram : entity mem.RamMLAB
      GENERIC MAP 
      (
         width                               => 10,
         widthad                             => 8
      )
      PORT MAP (
         inclock    => clk2x,
         wren       => tag_wren_a,
         data       => tag_data_a,
         wraddress  => std_logic_vector(tag_address_a),
         rdaddress  => std_logic_vector(tag_addr(i)),
         q          => tag_q_b(i)
      );
      
      -- 64x64 pixel for 4bit mode, 32*64 for 8bit mode, 32*32 for 15 bit mode
      tag_addr(i) <= stage0_textaddr(i)(16 downto 11) & stage0_textaddr(i)(4 downto 3) when drawMode(8) = '0' else 
                  stage0_textaddr(i)(15 downto 11) & stage0_textaddr(i)(5 downto 3);
      
      
      tag_data(i) <= drawMode(8) & stage0_textaddr(i)(19 downto 17) & stage0_textaddr(i)(10 downto 5) when drawMode(8) = '0' else
                     drawMode(8) & stage0_textaddr(i)(19 downto 16) & stage0_textaddr(i)(10 downto 6);
      
      stage0_textaddr(i)(19 downto 11) <= drawMode(4) & stage0_v_array(i);
      stage0_textaddr(i)(0)            <= '0';
      stage0_textaddr(i)(10 downto 1)  <= (drawMode(3 downto 0) & "000000") + stage0_u_array(i)(7 downto 2) when drawMode(8 downto 7) = "00" else
                                          (drawMode(3 downto 0) & "000000") + stage0_u_array(i)(7 downto 1) when drawMode(8 downto 7) = "01" else
                                          (drawMode(3 downto 0) & "000000") + stage0_u_array(i);
      
      icache: entity work.dpram
      generic map ( addr_width => 8, data_width => 64)
      port map
      (
         clock_a     => clk2x,
         address_a   => std_logic_vector(cache_address_a),
         data_a      => vram_DOUT,
         wren_a      => cache_wren_a,
         
         clock_b     => clk2x,
         address_b   => std_logic_vector(cache_address_b(i)),
         data_b      => x"0000000000000000",
         wren_b      => '0',
         q_b         => cache_q_b(i)
      );
      
      cache_address_b(i) <= tag_addr_1(i) when (pipeline_stall = '1') else tag_addr(i);
   
      cachehit(i)        <= '1' when (unsigned(tag_q_b(i)) = tag_data(i) and tagValid(to_integer(tag_addr(i))) = '1') else '0';
   
      stage1_u_mux(i)    <= stage1_u(i)(3 downto 2) when drawMode(8 downto 7) = "00" else
                            stage1_u(i)(2 downto 1) when drawMode(8 downto 7) = "01" else
                            stage1_u(i)(1 downto 0);
   
      texdata_raw(i)     <= cache_q_b(i)(15 downto  0) when (stage1_u_mux(i) = "00") else
                            cache_q_b(i)(31 downto 16) when (stage1_u_mux(i) = "01") else
                            cache_q_b(i)(47 downto 32) when (stage1_u_mux(i) = "10") else
                            cache_q_b(i)(63 downto 48);
      
      iCLUTram: entity work.dpram_dif
      generic map 
      ( 
         addr_width_a  => 6,
         data_width_a  => 64,
         addr_width_b  => 8,
         data_width_b  => 16
      )
      port map
      (
         clock_a     => clk2x,
         address_a   => std_logic_vector(CLUTaddrA),
         data_a      => vram_DOUT,
         wren_a      => CLUTwrenA,
         
         clock_b     => clk2x,
         clken_b     => (not pipeline_stall),
         address_b   => CLUTaddrB(i),
         data_b      => x"0000",
         wren_b      => '0',
         q_b         => CLUTDataB(i)
      );
      
      CLUTaddrB(i) <= x"0" & texdata_raw(i)( 3 downto  0) when (drawMode(7) = '0' and stage1_u(i)(1 downto 0) = "00") else
                      x"0" & texdata_raw(i)( 7 downto  4) when (drawMode(7) = '0' and stage1_u(i)(1 downto 0) = "01") else
                      x"0" & texdata_raw(i)(11 downto  8) when (drawMode(7) = '0' and stage1_u(i)(1 downto 0) = "10") else
                      x"0" & texdata_raw(i)(15 downto 12) when (drawMode(7) = '0' and stage1_u(i)(1 downto 0) = "11") else
                      texdata_raw(i)( 7 downto 0) when (drawMode(7) = '1' and stage1_u(i)(0) = '0') else
                      texdata_raw(i)(15 downto 8);

      texdata_palette(i) <= stage2_texdata(i) when (drawMode(8) = '1') else CLUTDataB(i);                     
          
      colorIgnore(i) <= '1' when (texdata_palette(i) = x"0000") else '0';
          
      texcolor(i,0) <= unsigned(texdata_palette(i)( 4 downto  0));
      texcolor(i,1) <= unsigned(texdata_palette(i)( 9 downto  5));
      texcolor(i,2) <= unsigned(texdata_palette(i)(14 downto 10));
          
   end generate;
   
   cache_wren_a      <= '1' when (vram_DOUT_READY = '1' and state = WAITTEXTURE) else '0';
                     
   CLUTwrenA         <= '1' when (vram_DOUT_READY = '1' and state = WAITPALETTE) else '0';

   filtercolor_alpha <= texdata_palette(0)(15) or texdata_palette(1)(15) or texdata_palette(2)(15) or texdata_palette(3)(15);
   
   useFilter         <= '1' when (stage2_filter = '1' and colorIgnore = "0000") else '0';

   gfilterColormult : for i in 0 to 2 generate
   begin
   
      colormultadds(i) <= resize(colormults(0,i), 15) + resize(colormults(1,i), 15) + resize(colormults(2,i), 15) + resize(colormults(3,i), 15);
      
      filtercolors(i) <= colormultadds(i)(14 downto 7);
      
   end generate;
   

   
   
   pipeline_busy <= pipeline_stall or stage0_valid or stage1_valid or stage2_valid or stage3_valid or stage4_valid or stage5_valid or stage6_valid;
   
   process (clk2x)
      variable selectIndex : integer range 0 to 3;
      variable colorTr     : unsigned(15 downto 0);
      variable colorTg     : unsigned(15 downto 0);
      variable colorTb     : unsigned(15 downto 0);      
      variable colorDr     : integer range -4 to 4095;
      variable colorDg     : integer range -4 to 4095;
      variable colorDb     : integer range -4 to 4095;
      variable colorBGr    : unsigned(7 downto 0);
      variable colorBGg    : unsigned(7 downto 0);
      variable colorBGb    : unsigned(7 downto 0);
      variable colorMixr   : integer range -255 to 511;
      variable colorMixg   : integer range -255 to 511;
      variable colorMixb   : integer range -255 to 511;
   begin
      if rising_edge(clk2x) then
         
         tag_wren_a    <= '0';
         
         -- must be done here, so it also is effected when ce is off = paused
         if (state = WAITTEXTURE) then
            if (requestVRAMDone = '1') then 
               if (cacherequest = "0000") then
                  state <= IDLE;
               else
                  state <= REQUESTMORETEXTURE;
               end if;
            end if;
            if (vram_DOUT_READY = '1') then
               tag_wren_a    <= '1';
               tagValid(to_integer(tag_address_a)) <= '1';
            end if;
         end if;
               
         if (state = WAITPALETTE) then
            if (requestVRAMDone = '1') then
               textPalFetchNext <= 0;
               if (textPalFetchNext > 0) then
                  case (textPalFetchNext) is
                     when 3      => reqVRAMSize <= to_unsigned(192, 11);
                     when 2      => reqVRAMSize <= to_unsigned(128, 11);
                     when others => reqVRAMSize <= to_unsigned( 64, 11);
                  end case;
                  state          <= REQUESTPALETTE;
                  reqVRAMXPos    <= (others => '0');
               else
                  state <= IDLE;
               end if;
            end if;
            if (vram_DOUT_READY = '1') then
               CLUTaddrA <= CLUTaddrA + 1;
            end if;
         end if;
         
         
         if (reset = '1') then
         
            state          <= IDLE;
            stage0_valid   <= '0';
            stage1_valid   <= '0';
            stage3_valid   <= '0';
            stage4_valid   <= '0';
            stage5_valid   <= '0';
            stage6_valid   <= '0';
            textPalFetched <= '0';
         
         elsif (ce = '1') then
            
            stage6_valid    <= '0';
            stage6_alphabit <= '0';
            stage6_cb       <= (others => '0');
            stage6_cg       <= (others => '0');
            stage6_cr       <= (others => '0');
            stage6_y        <= (others => '0');
            stage6_x        <= (others => '0');
            
            pipeline_stall_1 <= pipeline_stall;
            
            -- fetch of texture and palette data
            case (state) is
               when IDLE =>
                  if (clearCacheBuffer = '1' and pipeline_busy = '0') then
                     clearCacheBuffer <= '0';
                     tagValid         <= (others => '0');
                  end if;
                  if (textPalReq = '1' and pipeline_busy = '0') then
                     textPalReq     <= '0';
                     state          <= REQUESTPALETTE;
                     CLUTaddrA      <= (others => '0');
                     textPalFetched <= '1';
                     textPalX       <= textPalReqX;
                     textPalY       <= textPalReqY;
                     reqVRAMXPos    <= textPalReqX;
                     reqVRAMYPos    <= textPalReqY;
                     if (drawMode_in(7) = '1') then
                        case to_integer(textPalReqX) is
                           when 960    => reqVRAMSize <= to_unsigned( 64, 11); textPalFetchNext <= 3;
                           when 896    => reqVRAMSize <= to_unsigned(128, 11); textPalFetchNext <= 2;
                           when 832    => reqVRAMSize <= to_unsigned(192, 11); textPalFetchNext <= 1;
                           when others => reqVRAMSize <= to_unsigned(256, 11); textPalFetchNext <= 0;
                        end case;
                     else
                        reqVRAMSize <= to_unsigned(16, 11);
                     end if;
                  elsif (stage0_valid = '1' and stage0_texture = '1' and stage0_filter = '1' and cachehit /= "1111") then
                     state        <= REQUESTMORETEXTURE;
                     cacherequest <= not cachehit;
                  elsif (stage0_valid = '1' and stage0_texture = '1' and cachehit(0) = '0') then
                     state           <= REQUESTTEXTURE;
                     cacherequest    <= (others => '0');
                     tag_data_a      <= std_logic_vector(tag_data(0));
                     tag_address_a   <= tag_addr(0);
                     cache_address_a <= tag_addr(0);
                     
                     reqVRAMXPos <= stage0_textaddr(0)(10 downto 1);
                     reqVRAMYPos <= stage0_textaddr(0)(19 downto 11);
                     reqVRAMSize <= to_unsigned(1, 11);
                  end if;
               
               when REQUESTMORETEXTURE =>
                  state           <= REQUESTTEXTURE;
                  selectIndex := 0;
                  for i in 1 to 3 loop
                     if (cacherequest(i) = '1') then
                        selectIndex := i;
                     end if;
                  end loop;
                     
                  tag_data_a      <= std_logic_vector(tag_data_1(selectIndex));
                  tag_address_a   <= tag_addr_1(selectIndex);
                  cache_address_a <= tag_addr_1(selectIndex);
                  
                  reqVRAMXPos <= stage0_textaddr_1(selectIndex)(10 downto 1);
                  reqVRAMYPos <= stage0_textaddr_1(selectIndex)(19 downto 11);
                  reqVRAMSize <= to_unsigned(1, 11);  
               
               when REQUESTTEXTURE =>
                  -- cannot wait for fifoOut_idle here as this would kill the performance completly 
                  -- also it's totally unclear what real hardware does when primitives draw into their own texture
                  if (requestVRAMIdle = '1') then
                     state       <= WAITTEXTURE;
                  end if;
                  for i in 0 to 3 loop
                     if (tag_address_a = tag_addr_1(i)) then
                        cacherequest(i) <= '0';
                     end if;
                  end loop;
               
               when WAITTEXTURE => null; -- handled outside due to ce
               
               when REQUESTPALETTE =>
                  if (requestVRAMIdle = '1' and fifoOut_idle = '1') then
                     state       <= WAITPALETTE;
                  end if;
 
               when WAITPALETTE => null; -- handled outside due to ce
               
            end case;
            
            -- new palette request 
            if (pipeline_busy = '0') then
               drawMode       <= drawMode_in;      
               DrawPixelsMask <= DrawPixelsMask_in;
               SetMask        <= SetMask_in; 
            end if;
            
            if (textPalInNew = '1' and drawMode_in(8) = '0' and (textPalFetched = '0' or textPalInX /= textPalX or textPalInY /= textPalY or palette8bit /= drawMode_in(7) or textPalReq = '1')) then
               textPalReq  <= not noTexture;
               textPalReqX <= textPalInX;
               textPalReqY <= textPalInY;
               palette8bit <= drawMode_in(7);
            end if;
            
            -- clear cache request
            if (clearCacheTexture = '1') then
               clearCacheBuffer <= '1';
            end if;
                        
            if (clearCachePalette = '1') then
               textPalFetched   <= '0';
            end if;
            
            -- pixel pipeline
            if (pipeline_stall = '1' and pipeline_stall_1 = '0') then
               stageS_valid         <= pipeline_new and ((not DrawPixelsMask) or (not vramLineData(15)));
               stageS_texture       <= pipeline_texture;
               stageS_transparent   <= pipeline_transparent;
               stageS_rawTexture    <= pipeline_rawTexture; 
               stageS_dithering     <= pipeline_dithering; 
               stageS_x             <= pipeline_x; 
               stageS_y             <= pipeline_y; 
               stageS_cr            <= pipeline_cr;
               stageS_cg            <= pipeline_cg;
               stageS_cb            <= pipeline_cb;
               stageS_u             <= pipeline_u; 
               stageS_v             <= pipeline_v;
               stageS_filter        <= pipeline_filter;
               stageS_u11           <= pipeline_u11;   
               stageS_v11           <= pipeline_v11;                
               stageS_uAcc          <= pipeline_uAcc;   
               stageS_vAcc          <= pipeline_vAcc; 
               stageS_oldPixel      <= vramLineData;
               stageS_oldPixel2     <= vramLineData2;
            end if;
            
            if (pipeline_stall = '0') then
            
               -- stage 0 - receive
               if (pipeline_stall_1 = '1') then
                  stage0_valid         <= stageS_valid;      
                  stage0_texture       <= stageS_texture and (not noTexture);    
                  stage0_transparent   <= stageS_transparent;
                  stage0_rawTexture    <= stageS_rawTexture; 
                  stage0_dithering     <= stageS_dithering; 
                  stage0_x             <= stageS_x;          
                  stage0_y             <= stageS_y;          
                  stage0_cr            <= stageS_cr;         
                  stage0_cg            <= stageS_cg;         
                  stage0_cb            <= stageS_cb;         
                  stage0_u             <= stageS_u;          
                  stage0_v             <= stageS_v;   
                  stage0_filter        <= stageS_filter;
                  stage0_u11           <= stageS_u11;   
                  stage0_v11           <= stageS_v11;                     
                  stage0_uAcc          <= stageS_uAcc;   
                  stage0_vAcc          <= stageS_vAcc;                     
                  stage0_oldPixel      <= stageS_oldPixel;  
                  stage0_oldPixel2     <= stageS_oldPixel2;  
               else
                  stage0_valid         <= pipeline_new and ((not DrawPixelsMask) or (not vramLineData(15)));
                  stage0_texture       <= pipeline_texture and (not noTexture);    
                  stage0_transparent   <= pipeline_transparent;
                  stage0_rawTexture    <= pipeline_rawTexture; 
                  stage0_dithering     <= pipeline_dithering; 
                  stage0_x             <= pipeline_x; 
                  stage0_y             <= pipeline_y; 
                  stage0_cr            <= pipeline_cr;
                  stage0_cg            <= pipeline_cg;
                  stage0_cb            <= pipeline_cb;
                  stage0_u             <= pipeline_u; 
                  stage0_v             <= pipeline_v;
                  stage0_filter        <= pipeline_filter;
                  stage0_u11           <= pipeline_u11;   
                  stage0_v11           <= pipeline_v11;                   
                  stage0_uAcc          <= pipeline_uAcc;   
                  stage0_vAcc          <= pipeline_vAcc;   
                  stage0_oldPixel      <= vramLineData;
                  stage0_oldPixel2     <= vramLineData2;
               end if;

               -- stage1 - fetch texture
               stage1_valid       <= stage0_valid;      
               stage1_texture     <= stage0_texture;    
               stage1_transparent <= stage0_transparent;
               stage1_rawTexture  <= stage0_rawTexture; 
               stage1_dithering   <= stage0_dithering; 
               stage1_x           <= stage0_x;          
               stage1_y           <= stage0_y;          
               stage1_cr          <= stage0_cr;         
               stage1_cg          <= stage0_cg;         
               stage1_cb          <= stage0_cb; 
               stage1_filter      <= stage0_filter;
               stage1_uAcc        <= stage0_uAcc;
               stage1_vAcc        <= stage0_vAcc;
               stage1_oldPixel    <= stage0_oldPixel; 
               stage1_oldPixel2   <= stage0_oldPixel2; 
               for i in 0 to 3 loop
                  stage1_u(i)          <= stage0_u_array(i);
                  tag_addr_1(i)        <= tag_addr(i);
                  tag_data_1(i)        <= tag_data(i);
                  stage0_textaddr_1(i) <= stage0_textaddr(i);
               end loop;
            
               -- stage 2 - texture palette reading
               stage2_valid       <= stage1_valid;      
               stage2_texture     <= stage1_texture;    
               stage2_transparent <= stage1_transparent;
               stage2_rawTexture  <= stage1_rawTexture; 
               stage2_dithering   <= stage1_dithering; 
               stage2_x           <= stage1_x;          
               stage2_y           <= stage1_y;          
               stage2_cr          <= stage1_cr;         
               stage2_cg          <= stage1_cg;         
               stage2_cb          <= stage1_cb; 
               stage2_filter      <= stage1_filter;
               stage2_oldPixel    <= stage1_oldPixel;
               stage2_oldPixel2   <= stage1_oldPixel2;
               for i in 0 to 3 loop
                  stage2_texdata(i) <= texdata_raw(i);
               end loop;
               
               filtermults(0)     <= (to_unsigned(16#FF#, 9) - resize(stage1_uAcc,9)) + (to_unsigned(16#FF#, 9) - resize(stage1_vAcc,9));
               filtermults(1)     <= (to_unsigned(16#FF#, 9) - resize(stage1_uAcc,9)) +                           resize(stage1_vAcc,9) ;
               filtermults(2)     <=                           resize(stage1_uAcc,9)  + (to_unsigned(16#FF#, 9) - resize(stage1_vAcc,9));
               filtermults(3)     <=                           resize(stage1_uAcc,9)  +                           resize(stage1_vAcc,9) ;
               
               -- stage 3 - calculate texture data from normal path or bilinear filtering
               stage3_valid       <= stage2_valid;      
               stage3_texture     <= stage2_texture;    
               stage3_transparent <= stage2_transparent;
               stage3_rawTexture  <= stage2_rawTexture; 
               stage3_dithering   <= stage2_dithering; 
               stage3_x           <= stage2_x;          
               stage3_y           <= stage2_y;          
               stage3_cr          <= stage2_cr;         
               stage3_cg          <= stage2_cg;         
               stage3_cb          <= stage2_cb; 
               stage3_oldPixel    <= stage2_oldPixel;
               stage3_oldPixel2   <= stage2_oldPixel2;
               stage3_useFilter   <= useFilter;
               stage3_tex_r       <= unsigned(texdata_palette(0)( 4 downto  0));
               stage3_tex_g       <= unsigned(texdata_palette(0)( 9 downto  5));
               stage3_tex_b       <= unsigned(texdata_palette(0)(14 downto 10));
               if (useFilter = '1') then
                  stage3_tex_alpha   <= filtercolor_alpha;
               else
                  stage3_tex_alpha   <= texdata_palette(0)(15);
               end if;
               for i in 0 to 3 loop
                  colormults(i,0) <= filtermults(i) * texcolor(i,0);
                  colormults(i,1) <= filtermults(i) * texcolor(i,1);
                  colormults(i,2) <= filtermults(i) * texcolor(i,2);
               end loop;
               
               -- stage 4 - one additional clock for filtering timing closure
               stage4_valid       <= stage3_valid;     
               stage4_texture     <= stage3_texture;    
               stage4_transparent <= stage3_transparent;
               stage4_rawTexture  <= stage3_rawTexture; 
               stage4_dithering   <= stage3_dithering;  
               stage4_x           <= stage3_x;          
               stage4_y           <= stage3_y;          
               stage4_cr          <= stage3_cr;         
               stage4_cg          <= stage3_cg;         
               stage4_cb          <= stage3_cb;         
               stage4_oldPixel    <= stage3_oldPixel;   
               stage4_oldPixel2   <= stage3_oldPixel2;   
               stage4_ditherAdd   <= DITHERMATRIX(to_integer(stage3_y(1 downto 0)), to_integer(stage3_x(1 downto 0)));  
               stage4_useFilter   <= stage3_useFilter;
               stage4_tex_alpha   <= stage3_tex_alpha;
               if (stage3_useFilter = '1') then
                  stage4_tex_r       <= filtercolors(0);
                  stage4_tex_g       <= filtercolors(1);
                  stage4_tex_b       <= filtercolors(2);
               else
                  stage4_tex_r       <= stage3_tex_r & "000";      
                  stage4_tex_g       <= stage3_tex_g & "000";      
                  stage4_tex_b       <= stage3_tex_b & "000";      
               end if;           
               
               -- stage 5 - apply blending or raw color
               stage5_valid       <= stage4_valid; 
               stage5_transparent <= stage4_transparent;
               stage5_x           <= stage4_x;          
               stage5_y           <= stage4_y;
               stage5_oldPixel    <= stage4_oldPixel;               
               stage5_oldPixel2   <= stage4_oldPixel2;               
               if (stage4_texture = '1') then
                  stage5_alphacheck <= stage4_tex_alpha;
                  stage5_alphabit   <= stage4_tex_alpha;
                  if (stage4_tex_r(7 downto 3) = 0 and stage4_tex_g(7 downto 3) = 0 and stage4_tex_b(7 downto 3) = 0 and stage4_tex_alpha = '0' and stage4_useFilter = '0') then
                     stage5_valid <= '0';
                  end if;
                  if (stage4_rawTexture = '1') then
                     stage5_cr         <= stage4_tex_r;
                     stage5_cg         <= stage4_tex_g;
                     stage5_cb         <= stage4_tex_b;
                  else
                     colorTr := stage4_tex_r * stage4_cr;
                     colorTg := stage4_tex_g * stage4_cg;
                     colorTb := stage4_tex_b * stage4_cb;
                     if (stage4_dithering = '1') then
                        colorDr := (to_integer(colorTr) / 128) + stage4_ditherAdd;
                        colorDg := (to_integer(colorTg) / 128) + stage4_ditherAdd;
                        colorDb := (to_integer(colorTb) / 128) + stage4_ditherAdd;
                        if (colorDr < 0) then stage5_cr <= (others => '0'); elsif (colorDr > 255) then stage5_cr <= (others => '1'); else stage5_cr <= to_unsigned(colorDr, 8); end if;
                        if (colorDg < 0) then stage5_cg <= (others => '0'); elsif (colorDg > 255) then stage5_cg <= (others => '1'); else stage5_cg <= to_unsigned(colorDg, 8); end if;
                        if (colorDb < 0) then stage5_cb <= (others => '0'); elsif (colorDb > 255) then stage5_cb <= (others => '1'); else stage5_cb <= to_unsigned(colorDb, 8); end if;
                     else
                        if (colorTr(15 downto 7) > 255) then stage5_cr <= (others => '1'); else stage5_cr <= colorTr(14 downto 7); end if;
                        if (colorTb(15 downto 7) > 255) then stage5_cb <= (others => '1'); else stage5_cb <= colorTb(14 downto 7); end if;
                        if (colorTg(15 downto 7) > 255) then stage5_cg <= (others => '1'); else stage5_cg <= colorTg(14 downto 7); end if;
                     end if;
                  end if;
                  if (stage4_useFilter = '0' and render24 = '0') then
                     stage5_cr(2 downto 0) <= "000";
                     stage5_cg(2 downto 0) <= "000";
                     stage5_cb(2 downto 0) <= "000";
                  end if;
               else
                  if (render24 = '1') then
                     stage5_cr         <= stage4_cr;
                     stage5_cg         <= stage4_cg;
                     stage5_cb         <= stage4_cb;
                  elsif (stage4_dithering = '1') then
                     colorDr := to_integer(stage4_cr) + stage4_ditherAdd;
                     colorDg := to_integer(stage4_cg) + stage4_ditherAdd;
                     colorDb := to_integer(stage4_cb) + stage4_ditherAdd;
                     if (colorDr < 0) then stage5_cr <= (others => '0'); elsif (colorDr > 255) then stage5_cr <= x"F8"; else stage5_cr <= to_unsigned(colorDr / 8, 5) & "000"; end if;
                     if (colorDg < 0) then stage5_cg <= (others => '0'); elsif (colorDg > 255) then stage5_cg <= x"F8"; else stage5_cg <= to_unsigned(colorDg / 8, 5) & "000"; end if;
                     if (colorDb < 0) then stage5_cb <= (others => '0'); elsif (colorDb > 255) then stage5_cb <= x"F8"; else stage5_cb <= to_unsigned(colorDb / 8, 5) & "000"; end if;
                  else
                     stage5_cr         <= stage4_cr(7 downto 3) & "000";
                     stage5_cg         <= stage4_cg(7 downto 3) & "000";
                     stage5_cb         <= stage4_cb(7 downto 3) & "000";
                  end if;
                  stage5_alphacheck <= '1';
                  stage5_alphabit   <= '0';
               end if;
               
               -- stage 6 - apply alpha
               stage6_valid    <= stage5_valid;   
               stage6_alphabit <= stage5_alphabit or SetMask;
               stage6_x        <= stage5_x;       
               stage6_y        <= stage5_y;       

               if (stage5_transparent = '1' and stage5_alphacheck = '1') then
                  -- also check for mask bit
                  
                  colorBGr  := unsigned(stage5_oldPixel( 4 downto  0)) & "000";
                  colorBGg  := unsigned(stage5_oldPixel( 9 downto  5)) & "000";
                  colorBGb  := unsigned(stage5_oldPixel(14 downto 10)) & "000";
                  if (render24 = '1') then
                     colorBGr(2 downto 0) := unsigned(stage5_oldPixel2( 2 downto  0));
                     colorBGg(2 downto 0) := unsigned(stage5_oldPixel2( 5 downto  3));
                     colorBGb(2 downto 0) := unsigned(stage5_oldPixel2( 8 downto  6));
                  end if;
                  
                  case (drawMode(6 downto 5)) is
                     when "00" => --  (B+F)/2
                        colorMixr := (to_integer(colorBGr) + to_integer(stage5_cr)) / 2;
                        colorMixg := (to_integer(colorBGg) + to_integer(stage5_cg)) / 2;
                        colorMixb := (to_integer(colorBGb) + to_integer(stage5_cb)) / 2;
                        
                     when "01" => --  B+F
                        colorMixr := to_integer(colorBGr) + to_integer(stage5_cr);
                        colorMixg := to_integer(colorBGg) + to_integer(stage5_cg);
                        colorMixb := to_integer(colorBGb) + to_integer(stage5_cb);
                        
                     when "10" => -- B-F
                        colorMixr := to_integer(colorBGr) - to_integer(stage5_cr);
                        colorMixg := to_integer(colorBGg) - to_integer(stage5_cg);
                        colorMixb := to_integer(colorBGb) - to_integer(stage5_cb);
                        
                     when "11" => -- B+F/4
                        colorMixr := to_integer(colorBGr) + to_integer(stage5_cr(7 downto 2));
                        colorMixg := to_integer(colorBGg) + to_integer(stage5_cg(7 downto 2));
                        colorMixb := to_integer(colorBGb) + to_integer(stage5_cb(7 downto 2));
                  
                     when others => null;
                  end case;
                  
                  if (colorMixr > 255) then colorMixr := 255; elsif (colorMixr < 0) then colorMixr := 0; end if;
                  if (colorMixg > 255) then colorMixg := 255; elsif (colorMixg < 0) then colorMixg := 0; end if;
                  if (colorMixb > 255) then colorMixb := 255; elsif (colorMixb < 0) then colorMixb := 0; end if;
                  
                  stage6_cr       <= std_logic_vector(to_unsigned(colorMixr,8));
                  stage6_cg       <= std_logic_vector(to_unsigned(colorMixg,8));
                  stage6_cb       <= std_logic_vector(to_unsigned(colorMixb,8));
               else
                  stage6_cr       <= std_logic_vector(stage5_cr);      
                  stage6_cg       <= std_logic_vector(stage5_cg);      
                  stage6_cb       <= std_logic_vector(stage5_cb);     
               end if;
            
            end if; 
         
         end if;
         
      end if;
   end process; 
   
   pixelColor  <= stage6_alphabit & stage6_cb(7 downto 3) & stage6_cg(7 downto 3) & stage6_cr(7 downto 3);
   pixelColor2 <= "0000000" & stage6_cb(2 downto 0) & stage6_cg(2 downto 0) & stage6_cr(2 downto 0);
   pixelAddr   <= stage6_y & stage6_x & '0';
   pixelWrite  <= stage6_valid;


end architecture;





