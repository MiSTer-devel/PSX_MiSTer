library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all; 

entity gpu_pixelpipeline is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      drawMode_in          : in  unsigned(13 downto 0) := (others => '0');
      DrawPixelsMask_in    : in  std_logic;
      SetMask_in           : in  std_logic;
      
      clearCache           : in  std_logic;
      
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
      
      requestVRAMEnable    : out std_logic;
      requestVRAMXPos      : out unsigned(9 downto 0);
      requestVRAMYPos      : out unsigned(8 downto 0);
      requestVRAMSize      : out unsigned(10 downto 0);
      requestVRAMIdle      : in  std_logic;
      requestVRAMDone      : in  std_logic;
      vram_DOUT            : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY      : in  std_logic;
      
      vramLineData         : in  std_logic_vector(15 downto 0);
      
      textPalInNew         : in  std_logic;
      textPalInX           : in  unsigned(9 downto 0);   
      textPalInY           : in  unsigned(8 downto 0); 
      
      pixelStall           : in  std_logic;
      pixelColor           : out std_logic_vector(15 downto 0);
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
   
   signal drawMode            : unsigned(13 downto 0) := (others => '0');
   signal DrawPixelsMask      : std_logic := '0';
   signal SetMask             : std_logic := '0';
  
   signal tag_addr            : unsigned(7 downto 0) := (others => '0');
   signal tag_data            : unsigned(9 downto 0) := (others => '0');
      
   signal tag_address_a       : unsigned(7 downto 0) := (others => '0');
   signal tag_data_a          : std_logic_vector(9 downto 0) := (others => '0');
   signal tag_wren_a          : std_logic := '0';
   signal tag_address_b       : unsigned(7 downto 0) := (others => '0');
   signal tag_q_b             : std_logic_vector(9 downto 0) := (others => '0');
      
   signal tagValid            : std_logic_vector(0 to 255) := (others => '0');
      
   signal cache_address_a     : unsigned(7 downto 0) := (others => '0');
   signal cache_data_a        : std_logic_vector(63 downto 0) := (others => '0');
   signal cache_wren_a        : std_logic := '0';
   signal cache_address_b     : unsigned(7 downto 0);
   signal cache_q_b           : std_logic_vector(63 downto 0);
   
   signal cachehit            : std_logic;
      
   signal CLUTaddrA           : unsigned(5 downto 0) := (others => '0');
   signal CLUTwrenA           : std_logic;
   signal CLUTaddrB           : std_logic_vector(7 downto 0);
   signal CLUTDataB           : std_logic_vector(15 downto 0);
   
   signal CLUTDataB_S         : std_logic_vector(15 downto 0) := (others => '0');
  
   signal clearCacheBuffer    : std_logic;
   
   signal textPalReq          : std_logic;
   signal textPalReqX         : unsigned(9 downto 0);   
   signal textPalReqY         : unsigned(8 downto 0);
  
   signal textPalFetched      : std_logic := '0';
   signal textPalX            : unsigned(9 downto 0) := (others => '0');   
   signal textPalY            : unsigned(8 downto 0) := (others => '0'); 
  
   type tState is
   (
      IDLE,
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
   signal stageS_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');

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
   signal stage0_oldPixel     : std_logic_vector(15 downto 0);
   
   signal stage0_textaddr     : unsigned(19 downto 0) := (others => '0');
   
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
   signal stage1_u            : unsigned(7 downto 0) := (others => '0');
   signal stage1_oldPixel     : std_logic_vector(15 downto 0);
   signal stage1_texdata      : std_logic_vector(15 downto 0) := (others => '0');
   signal stage1_cachehit     : std_logic;
   
   signal stage1_u_mux        : unsigned(1 downto 0) := (others => '0');
   signal texdata_raw         : std_logic_vector(15 downto 0) := (others => '0');
   
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
   signal stage2_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage2_texdata      : std_logic_vector(15 downto 0) := (others => '0');
   signal stage2_ditherAdd    : integer range -4 to 4;
   
   signal texdata_palette     : std_logic_vector(15 downto 0) := (others => '0');
   
   signal stage3_valid        : std_logic := '0';
   signal stage3_transparent  : std_logic := '0';
   signal stage3_alphacheck   : std_logic := '0';
   signal stage3_alphabit     : std_logic := '0';
   signal stage3_x            : unsigned(9 downto 0) := (others => '0');
   signal stage3_y            : unsigned(8 downto 0) := (others => '0');
   signal stage3_cr           : unsigned(4 downto 0) := (others => '0');
   signal stage3_cg           : unsigned(4 downto 0) := (others => '0');
   signal stage3_cb           : unsigned(4 downto 0) := (others => '0');
   signal stage3_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   
   signal stage4_valid        : std_logic := '0';
   signal stage4_alphabit     : std_logic := '0';
   signal stage4_x            : unsigned(9 downto 0) := (others => '0');
   signal stage4_y            : unsigned(8 downto 0) := (others => '0');
   signal stage4_cr           : std_logic_vector(4 downto 0) := (others => '0');
   signal stage4_cg           : std_logic_vector(4 downto 0) := (others => '0');
   signal stage4_cb           : std_logic_vector(4 downto 0) := (others => '0');
  
begin 

   pipeline_stall <= '1' when (pixelStall = '1' or state /= IDLE) else '0';

   requestVRAMEnable <= '1'         when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or state = REQUESTPALETTE)) else '0';
   requestVRAMXPos   <= reqVRAMXPos when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or state = REQUESTPALETTE)) else (others => '0');
   requestVRAMYPos   <= reqVRAMYPos when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or state = REQUESTPALETTE)) else (others => '0');
   requestVRAMSize   <= reqVRAMSize when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or state = REQUESTPALETTE)) else (others => '0');
   
   itagram : altdpram
	GENERIC MAP 
   (
   	indata_aclr                         => "OFF",
      indata_reg                          => "INCLOCK",
      intended_device_family              => "Cyclone V",
      lpm_type                            => "altdpram",
      outdata_aclr                        => "OFF",
      outdata_reg                         => "UNREGISTERED",
      ram_block_type                      => "MLAB",
      rdaddress_aclr                      => "OFF",
      rdaddress_reg                       => "UNREGISTERED",
      rdcontrol_aclr                      => "OFF",
      rdcontrol_reg                       => "UNREGISTERED",
      read_during_write_mode_mixed_ports  => "CONSTRAINED_DONT_CARE",
      width                               => 10,
      widthad                             => 8,
      width_byteena                       => 1,
      wraddress_aclr                      => "OFF",
      wraddress_reg                       => "INCLOCK",
      wrcontrol_aclr                      => "OFF",
      wrcontrol_reg                       => "INCLOCK"
	)
	PORT MAP (
      inclock    => clk2x,
      wren       => tag_wren_a,
      data       => tag_data_a,
      wraddress  => std_logic_vector(tag_address_a),
      rdaddress  => std_logic_vector(tag_address_b),
      q          => tag_q_b
	);
   
   -- 64x64 pixel for 4bit mode, 32*64 for 8bit mode, 32*32 for 15 bit mode
   tag_addr <= stage0_textaddr(16 downto 11) & stage0_textaddr(4 downto 3) when drawMode(8) = '0' else 
               stage0_textaddr(15 downto 11) & stage0_textaddr(5 downto 3);
   
   
   tag_data <= drawMode(8) & stage0_textaddr(19 downto 17) & stage0_textaddr(10 downto 5) when drawMode(8) = '0' else
               drawMode(8) & stage0_textaddr(19 downto 16) & stage0_textaddr(10 downto 6);
   
   tag_address_b <= tag_addr;
   
   
   stage0_textaddr(19 downto 11) <= drawMode(4) & stage0_v;
   stage0_textaddr(0)            <= '0';
   stage0_textaddr(10 downto 1)  <= (drawMode(3 downto 0) & "000000") + stage0_u(7 downto 2) when drawMode(8 downto 7) = "00" else
                                    (drawMode(3 downto 0) & "000000") + stage0_u(7 downto 1) when drawMode(8 downto 7) = "01" else
                                    (drawMode(3 downto 0) & "000000") + stage0_u;
   
   
   cache_address_b <= tag_addr;
   
   icache: entity work.dpram
   generic map ( addr_width => 8, data_width => 64)
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(cache_address_a),
      data_a      => cache_data_a,
      wren_a      => cache_wren_a,
      
      clock_b     => clk2x,
      address_b   => std_logic_vector(cache_address_b),
      data_b      => x"0000000000000000",
      wren_b      => '0',
      q_b         => cache_q_b
   );
   
   cachehit <= '1' when (unsigned(tag_q_b) = tag_data and tagValid(to_integer(tag_addr)) = '1') else '0';
   
   stage1_u_mux <= stage1_u(3 downto 2) when drawMode(8 downto 7) = "00" else
                   stage1_u(2 downto 1) when drawMode(8 downto 7) = "01" else
                   stage1_u(1 downto 0);
   
   texdata_raw  <= stage1_texdata          when (stage1_cachehit = '0') else
                   cache_q_b(15 downto  0) when (stage1_u_mux = "00")   else
                   cache_q_b(31 downto 16) when (stage1_u_mux = "01")   else
                   cache_q_b(47 downto 32) when (stage1_u_mux = "10")   else
                   cache_q_b(63 downto 48);
   
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
      clock       => clk2x,
      
      address_a   => std_logic_vector(CLUTaddrA),
      data_a      => vram_DOUT,
      wren_a      => CLUTwrenA,
      
      address_b   => CLUTaddrB,
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => CLUTDataB
   );
   
   CLUTwrenA <= '1' when (vram_DOUT_READY = '1' and state = WAITPALETTE) else '0';
   
   CLUTaddrB <= x"0" & texdata_raw( 3 downto  0) when (drawMode(7) = '0' and stage1_u(1 downto 0) = "00") else
                x"0" & texdata_raw( 7 downto  4) when (drawMode(7) = '0' and stage1_u(1 downto 0) = "01") else
                x"0" & texdata_raw(11 downto  8) when (drawMode(7) = '0' and stage1_u(1 downto 0) = "10") else
                x"0" & texdata_raw(15 downto 12) when (drawMode(7) = '0' and stage1_u(1 downto 0) = "11") else
                texdata_raw( 7 downto 0) when (drawMode(7) = '1' and stage1_u(0) = '0') else
                texdata_raw(15 downto 8);
   
   
   texdata_palette <= stage2_texdata when (drawMode(8) = '1')      else
                      CLUTDataB_S    when (pipeline_stall_1 = '1') else 
                      CLUTDataB;
   
   pipeline_busy <= pipeline_stall or stage0_valid or stage1_valid or stage2_valid or stage3_valid or stage4_valid;
   
   process (clk2x)
      variable colorTr   : unsigned(12 downto 0);
      variable colorTg   : unsigned(12 downto 0);
      variable colorTb   : unsigned(12 downto 0);      
      variable colorDr   : integer range -4 to 511;
      variable colorDg   : integer range -4 to 511;
      variable colorDb   : integer range -4 to 511;
      variable colorBGr  : unsigned(4 downto 0);
      variable colorBGg  : unsigned(4 downto 0);
      variable colorBGb  : unsigned(4 downto 0);
      variable colorFGr  : unsigned(4 downto 0);
      variable colorFGg  : unsigned(4 downto 0);
      variable colorFGb  : unsigned(4 downto 0);
      variable colorMixr : integer range -31 to 62;
      variable colorMixg : integer range -31 to 62;
      variable colorMixb : integer range -31 to 62;
   begin
      if rising_edge(clk2x) then
         
         if (reset = '1') then
         
            state          <= IDLE;
            stage0_valid   <= '0';
            stage1_valid   <= '0';
            stage3_valid   <= '0';
            stage4_valid   <= '0';
            textPalFetched <= '0';
         
         elsif (ce = '1') then
         
            pixelColor <= (others => '0');
            pixelAddr  <= (others => '0');
            pixelWrite <= '0';
            
            tag_wren_a    <= '0';
            cache_wren_a  <= '0';
            
            pipeline_stall_1 <= pipeline_stall;
            
            if (pipeline_busy = '0') then
               drawMode       <= drawMode_in;      
               DrawPixelsMask <= DrawPixelsMask_in;
               SetMask        <= SetMask_in;       
            end if;
            
            if (clearCache = '1') then
               clearCacheBuffer <= '1';
               textPalFetched   <= '0';
            end if;
            
            if (textPalInNew = '1' and drawMode_in(8) = '0' and (textPalFetched = '0' or textPalInX /= textPalX or textPalInY /= textPalY)) then
               textPalReq  <= '1';
               textPalReqX <= textPalInX;
               textPalReqY <= textPalInY;
            end if;
            
            case (state) is
               when IDLE =>
                  if (clearCacheBuffer = '1' and pipeline_busy = '0') then
                     clearCacheBuffer <= '0';
                     tagValid         <= (others => '0');
                  end if;
                  if (textPalReq = '1' and pipeline_busy = '0') then
                     textPalReq     <= '0';
                     state          <= REQUESTPALETTE;
                     textPalFetched <= '1';
                     textPalX       <= textPalReqX;
                     textPalY       <= textPalReqY;
                     reqVRAMXPos    <= textPalReqX;
                     reqVRAMYPos    <= textPalReqY;
                     if (drawMode_in(7) = '1') then
                        reqVRAMSize <= to_unsigned(256, 11); 
                     else
                        reqVRAMSize <= to_unsigned(16, 11);
                     end if;
                  elsif (stage0_valid = '1' and stage0_texture = '1' and cachehit = '0') then
                     state           <= REQUESTTEXTURE;
                     tag_data_a      <= std_logic_vector(tag_data);
                     tag_address_a   <= tag_addr;
                     cache_address_a <= tag_addr;
                     
                     reqVRAMXPos <= stage0_textaddr(10 downto 1);
                     reqVRAMYPos <= stage0_textaddr(19 downto 11);
                     reqVRAMSize <= to_unsigned(1, 11);
                  end if;
               
               when REQUESTTEXTURE =>
                  if (requestVRAMIdle = '1') then
                     state       <= WAITTEXTURE;
                  end if;
               
               when WAITTEXTURE =>
                  if (requestVRAMDone = '1') then
                     state <= IDLE;
                  end if;
                  if (vram_DOUT_READY = '1') then
                     tag_wren_a    <= '1';
                     cache_wren_a  <= '1';
                     cache_data_a  <= vram_DOUT;
                     tagValid(to_integer(tag_address_a)) <= '1';
                     case (stage1_u_mux) is
                        when "00" => stage1_texdata <= vram_DOUT(15 downto  0);
                        when "01" => stage1_texdata <= vram_DOUT(31 downto 16);
                        when "10" => stage1_texdata <= vram_DOUT(47 downto 32);
                        when "11" => stage1_texdata <= vram_DOUT(63 downto 48);
                        when others => null;
                     end case;
                  end if;
               
               when REQUESTPALETTE =>
                  if (requestVRAMIdle = '1') then
                     state       <= WAITPALETTE;
                  end if;
                  CLUTaddrA <= (others => '0');
 
               when WAITPALETTE =>
                  if (requestVRAMDone = '1') then
                     state <= IDLE;
                  end if;
                  if (vram_DOUT_READY = '1') then
                     CLUTaddrA <= CLUTaddrA + 1;
                  end if;
               
            end case;
            
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
               stageS_oldPixel      <= vramLineData;
               
               CLUTDataB_S          <= CLUTDataB;
            end if;
            
            if (pipeline_stall = '0') then
            
               -- stage 0 - receive
               if (pipeline_stall_1 = '1') then
                  stage0_valid         <= stageS_valid;      
                  stage0_texture       <= stageS_texture;    
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
                  stage0_oldPixel      <= stageS_oldPixel;  
               else
                  stage0_valid         <= pipeline_new and ((not DrawPixelsMask) or (not vramLineData(15)));
                  stage0_texture       <= pipeline_texture;
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
                  stage0_oldPixel      <= vramLineData;
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
               stage1_u           <= stage0_u;
               stage1_oldPixel    <= stage0_oldPixel;
               stage1_cachehit    <= cachehit;          
            
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
               stage2_texdata     <= texdata_raw;
               stage2_oldPixel    <= stage1_oldPixel;
               stage2_ditherAdd   <= DITHERMATRIX(to_integer(stage1_y(1 downto 0)), to_integer(stage1_x(1 downto 0)));
               
               -- stage 3 - apply blending or raw color
               stage3_valid       <= stage2_valid; 
               stage3_transparent <= stage2_transparent;
               stage3_x           <= stage2_x;          
               stage3_y           <= stage2_y;
               stage3_oldPixel    <= stage2_oldPixel;               
               if (stage2_texture = '1') then
                  stage3_alphacheck <= texdata_palette(15);
                  stage3_alphabit   <= texdata_palette(15);
                  if (texdata_palette = x"0000") then
                     stage3_valid <= '0';
                  end if;
                  if (stage2_rawTexture = '1') then
                     stage3_cr         <= unsigned(texdata_palette( 4 downto  0));
                     stage3_cg         <= unsigned(texdata_palette( 9 downto  5));
                     stage3_cb         <= unsigned(texdata_palette(14 downto 10));
                  else
                     colorTr := unsigned(texdata_palette( 4 downto  0)) * stage2_cr;
                     colorTg := unsigned(texdata_palette( 9 downto  5)) * stage2_cg;
                     colorTb := unsigned(texdata_palette(14 downto 10)) * stage2_cb;
                     if (stage2_dithering = '1') then
                        colorDr := (to_integer(colorTr) / 16) + stage2_ditherAdd;
                        colorDg := (to_integer(colorTg) / 16) + stage2_ditherAdd;
                        colorDb := (to_integer(colorTb) / 16) + stage2_ditherAdd;
                        if (colorDr < 0) then stage3_cr <= (others => '0'); elsif (colorDr > 255) then stage3_cr <= (others => '1'); else stage3_cr <= to_unsigned(colorDr / 8, 5); end if;
                        if (colorDg < 0) then stage3_cg <= (others => '0'); elsif (colorDg > 255) then stage3_cg <= (others => '1'); else stage3_cg <= to_unsigned(colorDg / 8, 5); end if;
                        if (colorDb < 0) then stage3_cb <= (others => '0'); elsif (colorDb > 255) then stage3_cb <= (others => '1'); else stage3_cb <= to_unsigned(colorDb / 8, 5); end if;
                     else
                        if (colorTr(12 downto 7) > 31) then stage3_cr <= (others => '1'); else stage3_cr <= colorTr(11 downto 7); end if;
                        if (colorTg(12 downto 7) > 31) then stage3_cg <= (others => '1'); else stage3_cg <= colorTg(11 downto 7); end if;
                        if (colorTb(12 downto 7) > 31) then stage3_cb <= (others => '1'); else stage3_cb <= colorTb(11 downto 7); end if;
                     end if;
                  end if;
               else
                  if (stage2_dithering = '1') then
                     colorDr := to_integer(stage2_cr) + stage2_ditherAdd;
                     colorDg := to_integer(stage2_cg) + stage2_ditherAdd;
                     colorDb := to_integer(stage2_cb) + stage2_ditherAdd;
                     if (colorDr < 0) then stage3_cr <= (others => '0'); elsif (colorDr > 255) then stage3_cr <= (others => '1'); else stage3_cr <= to_unsigned(colorDr / 8, 5); end if;
                     if (colorDg < 0) then stage3_cg <= (others => '0'); elsif (colorDg > 255) then stage3_cg <= (others => '1'); else stage3_cg <= to_unsigned(colorDg / 8, 5); end if;
                     if (colorDb < 0) then stage3_cb <= (others => '0'); elsif (colorDb > 255) then stage3_cb <= (others => '1'); else stage3_cb <= to_unsigned(colorDb / 8, 5); end if;
                  else
                     stage3_cr         <= stage2_cr(7 downto 3);
                     stage3_cg         <= stage2_cg(7 downto 3);
                     stage3_cb         <= stage2_cb(7 downto 3);
                  end if;
                  stage3_alphacheck <= '1';
                  stage3_alphabit   <= '0';
               end if;
               
               -- stage 4 - apply alpha
               stage4_valid    <= stage3_valid;   
               stage4_alphabit <= stage3_alphabit or SetMask;
               stage4_x        <= stage3_x;       
               stage4_y        <= stage3_y;       

               if (stage3_transparent = '1' and stage3_alphacheck = '1') then
                  -- also check for mask bit
                  
                  colorBGr  := unsigned(stage3_oldPixel( 4 downto  0));
                  colorBGg  := unsigned(stage3_oldPixel( 9 downto  5));
                  colorBGb  := unsigned(stage3_oldPixel(14 downto 10));
                  
                  case (drawMode(6 downto 5)) is
                     when "00" => --  B/2+F/2
                        colorMixr := to_integer(colorBGr(4 downto 1)) + to_integer(stage3_cr(4 downto 1));
                        colorMixg := to_integer(colorBGg(4 downto 1)) + to_integer(stage3_cg(4 downto 1));
                        colorMixb := to_integer(colorBGb(4 downto 1)) + to_integer(stage3_cb(4 downto 1));
                        
                     when "01" => --  B+F
                        colorMixr := to_integer(colorBGr) + to_integer(stage3_cr);
                        colorMixg := to_integer(colorBGg) + to_integer(stage3_cg);
                        colorMixb := to_integer(colorBGb) + to_integer(stage3_cb);
                        
                     when "10" => -- B-F
                        colorMixr := to_integer(colorBGr) - to_integer(stage3_cr);
                        colorMixg := to_integer(colorBGg) - to_integer(stage3_cg);
                        colorMixb := to_integer(colorBGb) - to_integer(stage3_cb);
                        
                     when "11" => -- B+F/4
                        colorMixr := to_integer(colorBGr) + to_integer(stage3_cr(4 downto 2));
                        colorMixg := to_integer(colorBGg) + to_integer(stage3_cg(4 downto 2));
                        colorMixb := to_integer(colorBGb) + to_integer(stage3_cb(4 downto 2));
                  
                     when others => null;
                  end case;
                  
                  if (colorMixr > 31) then colorMixr := 31; elsif (colorMixr < 0) then colorMixr := 0; end if;
                  if (colorMixg > 31) then colorMixg := 31; elsif (colorMixg < 0) then colorMixg := 0; end if;
                  if (colorMixb > 31) then colorMixb := 31; elsif (colorMixb < 0) then colorMixb := 0; end if;
                  
                  stage4_cr       <= std_logic_vector(to_unsigned(colorMixr,5));
                  stage4_cg       <= std_logic_vector(to_unsigned(colorMixg,5));
                  stage4_cb       <= std_logic_vector(to_unsigned(colorMixb,5));
               else
                  stage4_cr       <= std_logic_vector(stage3_cr);      
                  stage4_cg       <= std_logic_vector(stage3_cg);      
                  stage4_cb       <= std_logic_vector(stage3_cb);       
               end if;
               
               -- stage 5 - write
               if (stage4_valid = '1') then
                  pixelColor <= stage4_alphabit & stage4_cb & stage4_cg & stage4_cr;
                  pixelAddr  <= stage4_y & stage4_x & '0';
                  pixelWrite <= '1';
               end if;
            
            end if; 
         
         end if;
         
      end if;
   end process; 


end architecture;





