library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

entity gpu_pixelpipeline is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      transparencyMode     : in  unsigned(1 downto 0);
      
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
      
      vramLineData         : in  std_logic_vector(15 downto 0);
      
      pixelStall           : in  std_logic;
      pixelColor           : out std_logic_vector(15 downto 0);
      pixelAddr            : out unsigned(19 downto 0);
      pixelWrite           : out std_logic
   );
end entity;

architecture arch of gpu_pixelpipeline is
  
   signal stage0_valid        : std_logic := '0';
   signal stage0_texture      : std_logic;
   signal stage0_transparent  : std_logic;
   signal stage0_rawTexture   : std_logic;
   signal stage0_x            : unsigned(9 downto 0);
   signal stage0_y            : unsigned(8 downto 0);
   signal stage0_cr           : unsigned(7 downto 0);
   signal stage0_cg           : unsigned(7 downto 0);
   signal stage0_cb           : unsigned(7 downto 0);
   signal stage0_u            : unsigned(7 downto 0);
   signal stage0_v            : unsigned(7 downto 0);
   signal stage0_oldPixel     : std_logic_vector(15 downto 0);
   
   signal stage1_valid        : std_logic := '0';
   signal stage1_texture      : std_logic;
   signal stage1_transparent  : std_logic;
   signal stage1_rawTexture   : std_logic;
   signal stage1_x            : unsigned(9 downto 0);
   signal stage1_y            : unsigned(8 downto 0);
   signal stage1_cr           : unsigned(7 downto 0);
   signal stage1_cg           : unsigned(7 downto 0);
   signal stage1_cb           : unsigned(7 downto 0);
   signal stage1_oldPixel     : std_logic_vector(15 downto 0);
  
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

   pipeline_stall <= pixelStall;

   requestVRAMEnable <= '0';
   requestVRAMXPos   <= (others => '0');
   requestVRAMYPos   <= (others => '0');
   requestVRAMSize   <= (others => '0');
   
   process (clk2x)
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
         
            stage0_valid <= '0';
            stage1_valid <= '0';
            stage2_valid <= '0';
            stage3_valid <= '0';
         
         elsif (ce = '1') then
         
            pixelColor <= (others => '0');
            pixelAddr  <= (others => '0');
            pixelWrite <= '0';
         
            if (pixelStall = '0') then
            
               -- stage 0 - receive
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
               if (pipeline_rawTexture = '1') then
                  -- check if texture is cached
                  -- check if palette is available
               end if;
               if (pipeline_transparent = '1') then
                  -- check if line is fetched
               end if;
            
               -- stage1 - apply color from texture
               stage1_valid       <= stage0_valid;      
               stage1_texture     <= stage0_texture;    
               stage1_transparent <= stage0_transparent;
               stage1_rawTexture  <= stage0_rawTexture; 
               stage1_x           <= stage0_x;          
               stage1_y           <= stage0_y;          
               stage1_cr          <= stage0_cr;         
               stage1_cg          <= stage0_cg;         
               stage1_cb          <= stage0_cb; 
               stage1_oldPixel    <= stage0_oldPixel; 
            
               -- stage2 - apply blending or raw color
               stage2_valid       <= stage1_valid; 
               stage2_transparent <= stage1_transparent;
               stage2_x           <= stage1_x;          
               stage2_y           <= stage1_y;
               stage2_oldPixel    <= stage1_oldPixel;               
               if (stage1_texture = '1') then
               
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
                  
                  case (transparencyMode) is
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





