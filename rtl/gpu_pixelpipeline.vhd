library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all; 

entity gpu_pixelpipeline is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      drawMode             : in  unsigned(13 downto 0) := (others => '0');
      
      pipeline_stall       : out std_logic;
      pipeline_new         : in  std_logic;
      pipeline_texture     : in  std_logic;
      pipeline_transparent : in  std_logic;
      pipeline_rawTexture  : in  std_logic;
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
      
      pixelStall           : in  std_logic;
      pixelColor           : out std_logic_vector(15 downto 0);
      pixelAddr            : out unsigned(19 downto 0);
      pixelWrite           : out std_logic
   );
end entity;

architecture arch of gpu_pixelpipeline is
  
   signal tag_addr                     : unsigned(7 downto 0) := (others => '0');
   signal tag_data                     : unsigned(9 downto 0) := (others => '0');
   
   signal tag_address_a                : unsigned(7 downto 0) := (others => '0');
   signal tag_data_a                   : std_logic_vector(9 downto 0) := (others => '0');
   signal tag_wren_a                   : std_logic := '0';
   signal tag_address_b                : unsigned(7 downto 0) := (others => '0');
   signal tag_q_b                      : std_logic_vector(9 downto 0) := (others => '0');
   
   signal tagValid                     : std_logic_vector(0 to 255) := (others => '0');
   
   signal cache_address_a              : unsigned(7 downto 0) := (others => '0');
   signal cache_data_a                 : std_logic_vector(63 downto 0) := (others => '0');
   signal cache_wren_a                 : std_logic := '0';
   signal cache_address_b              : unsigned(7 downto 0);
   signal cache_q_b                    : std_logic_vector(63 downto 0);
  
   signal cachehit                     : std_logic;
  
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
   
   signal reqVRAMXPos         : unsigned(9 downto 0);
   signal reqVRAMYPos         : unsigned(8 downto 0);
   signal reqVRAMSize         : unsigned(10 downto 0);
  
   signal stageS_valid        : std_logic := '0';
   signal stageS_texture      : std_logic;
   signal stageS_transparent  : std_logic;
   signal stageS_rawTexture   : std_logic;
   signal stageS_x            : unsigned(9 downto 0);
   signal stageS_y            : unsigned(8 downto 0);
   signal stageS_cr           : unsigned(7 downto 0);
   signal stageS_cg           : unsigned(7 downto 0);
   signal stageS_cb           : unsigned(7 downto 0);
   signal stageS_u            : unsigned(7 downto 0);
   signal stageS_v            : unsigned(7 downto 0);
   signal stageS_oldPixel     : std_logic_vector(15 downto 0);

   signal stage0_valid        : std_logic := '0';
   signal stage0_texture      : std_logic;
   signal stage0_transparent  : std_logic;
   signal stage0_rawTexture   : std_logic;
   signal stage0_x            : unsigned(9 downto 0);
   signal stage0_y            : unsigned(8 downto 0);
   signal stage0_cr           : unsigned(7 downto 0);
   signal stage0_cg           : unsigned(7 downto 0);
   signal stage0_cb           : unsigned(7 downto 0);
   signal stage0_u            : unsigned(7 downto 0) := (others => '0');
   signal stage0_v            : unsigned(7 downto 0) := (others => '0');
   signal stage0_oldPixel     : std_logic_vector(15 downto 0);
   
   signal stage0_textaddr     : unsigned(19 downto 0) := (others => '0');
   
   signal stage1_valid        : std_logic := '0';
   signal stage1_texture      : std_logic;
   signal stage1_transparent  : std_logic;
   signal stage1_rawTexture   : std_logic;
   signal stage1_x            : unsigned(9 downto 0);
   signal stage1_y            : unsigned(8 downto 0);
   signal stage1_cr           : unsigned(7 downto 0);
   signal stage1_cg           : unsigned(7 downto 0);
   signal stage1_cb           : unsigned(7 downto 0);
   signal stage1_u            : unsigned(7 downto 0);
   signal stage1_v            : unsigned(7 downto 0);
   signal stage1_oldPixel     : std_logic_vector(15 downto 0);
   signal stage1_texdata      : std_logic_vector(15 downto 0);
   signal stage1_cachehit     : std_logic;
  
   signal stage2_valid        : std_logic := '0';
   signal stage2_transparent  : std_logic;
   signal stage2_alphacheck   : std_logic;
   signal stage2_alphabit     : std_logic;
   signal stage2_x            : unsigned(9 downto 0);
   signal stage2_y            : unsigned(8 downto 0);
   signal stage2_cr           : unsigned(4 downto 0);
   signal stage2_cg           : unsigned(4 downto 0);
   signal stage2_cb           : unsigned(4 downto 0);
   signal stage2_oldPixel     : std_logic_vector(15 downto 0);
   
   signal stage3_valid        : std_logic := '0';
   signal stage3_alphabit     : std_logic;
   signal stage3_x            : unsigned(9 downto 0);
   signal stage3_y            : unsigned(8 downto 0);
   signal stage3_cr           : std_logic_vector(4 downto 0);
   signal stage3_cg           : std_logic_vector(4 downto 0);
   signal stage3_cb           : std_logic_vector(4 downto 0);
  
begin 

   pipeline_stall <= '1' when (pixelStall = '1' or state /= IDLE) else '0';

   requestVRAMEnable <= '1'         when (state = REQUESTTEXTURE) else '0';
   requestVRAMXPos   <= reqVRAMXPos when (state = REQUESTTEXTURE) else (others => '0');
   requestVRAMYPos   <= reqVRAMYPos when (state = REQUESTTEXTURE) else (others => '0');
   requestVRAMSize   <= reqVRAMSize when (state = REQUESTTEXTURE) else (others => '0');
   
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
   
   process (clk2x)
      variable texdata   : std_logic_vector(15 downto 0);
      variable colorTr   : unsigned(12 downto 0);
      variable colorTg   : unsigned(12 downto 0);
      variable colorTb   : unsigned(12 downto 0);
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
         
            state        <= IDLE;
            stage0_valid <= '0';
            stage1_valid <= '0';
            stage2_valid <= '0';
            stage3_valid <= '0';
            tagValid     <= (others => '0');
         
         elsif (ce = '1') then
         
            pixelColor <= (others => '0');
            pixelAddr  <= (others => '0');
            pixelWrite <= '0';
            
            tag_wren_a    <= '0';
            cache_wren_a  <= '0';
            
            pipeline_stall_1 <= pipeline_stall;
            
            case (state) is
               when IDLE =>
                  if (stage0_valid = '1' and stage0_texture = '1' and cachehit = '0') then
                     state           <= REQUESTTEXTURE;
                     tag_data_a      <= std_logic_vector(tag_data);
                     tag_address_a   <= tag_addr;
                     cache_address_a <= tag_addr;
                     
                     case (drawMode(8 downto 7)) is
                        when "00" => -- Palette4Bit
                           reqVRAMXPos <= (others => '0');
                           reqVRAMYPos <= (others => '0');
                           reqVRAMSize <= (others => '0');
                        
                        when "01" => -- Palette8Bit
                           reqVRAMXPos <= (others => '0');
                           reqVRAMYPos <= (others => '0');
                           reqVRAMSize <= (others => '0');
                           
                        when others => -- 15bit
                           reqVRAMXPos <= (drawMode(3 downto 0) & "000000") + stage0_u;
                           reqVRAMYPos <= drawMode(4) & stage0_v;
                           reqVRAMSize <= to_unsigned(1, 11);
                     end case;
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
                     
                     
                     case (stage1_u(1 downto 0)) is
                        when "00" => stage1_texdata <= vram_DOUT(15 downto  0);
                        when "01" => stage1_texdata <= vram_DOUT(31 downto 16);
                        when "10" => stage1_texdata <= vram_DOUT(47 downto 32);
                        when "11" => stage1_texdata <= vram_DOUT(63 downto 48);
                        when others => null;
                     end case;
                  end if;
               
               when REQUESTPALETTE =>
               when WAITPALETTE =>
               
            end case;
            
            if (pipeline_stall = '1' and pipeline_stall_1 = '0') then
               stageS_valid         <= pipeline_new;
               stageS_texture       <= pipeline_texture;
               stageS_transparent   <= pipeline_transparent;
               stageS_rawTexture    <= pipeline_rawTexture; 
               stageS_x             <= pipeline_x; 
               stageS_y             <= pipeline_y; 
               stageS_cr            <= pipeline_cr;
               stageS_cg            <= pipeline_cg;
               stageS_cb            <= pipeline_cb;
               stageS_u             <= pipeline_u; 
               stageS_v             <= pipeline_v;
               stageS_oldPixel      <= vramLineData;
            end if;
            
            if (pipeline_stall = '0') then
            
               -- stage 0 - receive
               if (pipeline_stall_1 = '1') then
                  stage0_valid         <= stageS_valid;      
                  stage0_texture       <= stageS_texture;    
                  stage0_transparent   <= stageS_transparent;
                  stage0_rawTexture    <= stageS_rawTexture; 
                  stage0_x             <= stageS_x;          
                  stage0_y             <= stageS_y;          
                  stage0_cr            <= stageS_cr;         
                  stage0_cg            <= stageS_cg;         
                  stage0_cb            <= stageS_cb;         
                  stage0_u             <= stageS_u;          
                  stage0_v             <= stageS_v;          
                  stage0_oldPixel      <= stageS_oldPixel;  
               else
                  stage0_valid         <= pipeline_new;
                  stage0_texture       <= pipeline_texture;
                  stage0_transparent   <= pipeline_transparent;
                  stage0_rawTexture    <= pipeline_rawTexture; 
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
               stage1_x           <= stage0_x;          
               stage1_y           <= stage0_y;          
               stage1_cr          <= stage0_cr;         
               stage1_cg          <= stage0_cg;         
               stage1_cb          <= stage0_cb; 
               stage1_u           <= stage0_u;
               stage1_v           <= stage0_v;
               stage1_oldPixel    <= stage0_oldPixel;
               stage1_cachehit    <= cachehit;          
            
               -- stage2 - apply blending or raw color
               stage2_valid       <= stage1_valid; 
               stage2_transparent <= stage1_transparent;
               stage2_x           <= stage1_x;          
               stage2_y           <= stage1_y;
               stage2_oldPixel    <= stage1_oldPixel;               
               if (stage1_texture = '1') then
                  texdata := stage1_texdata;
                  if (stage1_cachehit = '1') then
                     case (stage1_u(1 downto 0)) is
                        when "00" => texdata := cache_q_b(15 downto  0);
                        when "01" => texdata := cache_q_b(31 downto 16);
                        when "10" => texdata := cache_q_b(47 downto 32);
                        when "11" => texdata := cache_q_b(63 downto 48);
                        when others => null;
                     end case;
                  end if;
                  stage2_alphacheck <= texdata(15);
                  stage2_alphabit   <= texdata(15);
                  if (texdata = x"0000") then
                     stage2_valid <= '0';
                  end if;
                  if (stage1_rawTexture = '1') then
                     stage2_cr         <= unsigned(texdata( 4 downto  0));
                     stage2_cg         <= unsigned(texdata( 9 downto  5));
                     stage2_cb         <= unsigned(texdata(14 downto 10));
                  else
                     colorTr := unsigned(texdata( 4 downto  0)) * stage1_cr;
                     colorTg := unsigned(texdata( 9 downto  5)) * stage1_cg;
                     colorTb := unsigned(texdata(14 downto 10)) * stage1_cb;
                     if (colorTr(12 downto 7) > 31) then stage2_cr <= (others => '1'); else stage2_cr <= colorTr(11 downto 7); end if;
                     if (colorTg(12 downto 7) > 31) then stage2_cg <= (others => '1'); else stage2_cg <= colorTg(11 downto 7); end if;
                     if (colorTb(12 downto 7) > 31) then stage2_cb <= (others => '1'); else stage2_cb <= colorTb(11 downto 7); end if;
                  end if;
               else
                  stage2_cr         <= stage1_cr(7 downto 3);
                  stage2_cg         <= stage1_cg(7 downto 3);
                  stage2_cb         <= stage1_cb(7 downto 3);
                  stage2_alphacheck <= '1';
                  stage2_alphabit   <= '0';
               end if;
               
               -- stage3 - apply alpha
               stage3_valid    <= stage2_valid;   
               stage3_alphabit <= stage2_alphabit;
               stage3_x        <= stage2_x;       
               stage3_y        <= stage2_y;       

               if (stage2_transparent = '1' and stage2_alphacheck = '1') then
                  -- also check for mask bit
                  
                  colorBGr  := unsigned(stage2_oldPixel( 4 downto  0));
                  colorBGg  := unsigned(stage2_oldPixel( 9 downto  5));
                  colorBGb  := unsigned(stage2_oldPixel(14 downto 10));
                  
                  case (drawMode(6 downto 5)) is
                     when "00" => --  B/2+F/2
                        colorMixr := to_integer(stage2_cr(4 downto 1)) + to_integer(colorBGr(4 downto 1));
                        colorMixg := to_integer(stage2_cg(4 downto 1)) + to_integer(colorBGg(4 downto 1));
                        colorMixb := to_integer(stage2_cb(4 downto 1)) + to_integer(colorBGb(4 downto 1));
                        
                     when "01" => --  B+F
                        colorMixr := to_integer(stage2_cr) + to_integer(colorBGr);
                        colorMixg := to_integer(stage2_cg) + to_integer(colorBGg);
                        colorMixb := to_integer(stage2_cb) + to_integer(colorBGb);
                        
                     when "10" => -- B-F
                        colorMixr := to_integer(stage2_cr) - to_integer(colorBGr);
                        colorMixg := to_integer(stage2_cg) - to_integer(colorBGg);
                        colorMixb := to_integer(stage2_cb) - to_integer(colorBGb);
                        
                     when "11" => -- B+F/4
                        colorMixr := to_integer(stage2_cr(4 downto 2)) + to_integer(colorBGr(4 downto 1));
                        colorMixg := to_integer(stage2_cg(4 downto 2)) + to_integer(colorBGg(4 downto 1));
                        colorMixb := to_integer(stage2_cb(4 downto 2)) + to_integer(colorBGb(4 downto 1));
                  
                     when others => null;
                  end case;
                  
                  if (colorMixr > 31) then colorMixr := 31; elsif (colorMixr < 0) then colorMixr := 0; end if;
                  if (colorMixg > 31) then colorMixg := 31; elsif (colorMixg < 0) then colorMixg := 0; end if;
                  if (colorMixb > 31) then colorMixb := 31; elsif (colorMixb < 0) then colorMixb := 0; end if;
                  
                  stage3_cr       <= std_logic_vector(to_unsigned(colorMixr,5));
                  stage3_cg       <= std_logic_vector(to_unsigned(colorMixg,5));
                  stage3_cb       <= std_logic_vector(to_unsigned(colorMixb,5));
               else
                  stage3_cr       <= std_logic_vector(stage2_cr);      
                  stage3_cg       <= std_logic_vector(stage2_cg);      
                  stage3_cb       <= std_logic_vector(stage2_cb);       
               end if;
               
               -- stage 4 - write
               if (stage3_valid = '1') then
                  pixelColor <= stage3_alphabit & stage3_cb & stage3_cg & stage3_cr;
                  pixelAddr  <= stage3_y & stage3_x & '0';
                  pixelWrite <= '1';
               end if;
            
            end if; 
         
         end if;
         
      end if;
   end process; 
   
   -- synthesis translate_off
   
   goutput : if 1 = 1 generate
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
      begin
   
         file_open(f_status, outfile, "R:\\debug_pixel_sim.txt", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "R:\\debug_pixel_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk2x);
            
            if (pixelWrite = '1') then
            
               write(line_out, to_integer(pixelAddr(10 downto 1)));
               write(line_out, string'(" ")); 
               write(line_out, to_integer(pixelAddr(19 downto 11)));
               write(line_out, string'(" ")); 
               write(line_out, to_integer(unsigned(pixelColor)));
               writeline(outfile, line_out);
   
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on


end architecture;





