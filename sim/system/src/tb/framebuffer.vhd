library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  
use STD.textio.all;

entity framebuffer is
   generic
   (
      FRAMESIZE_X : integer;
      FRAMESIZE_Y : integer
   );
   port 
   (
      clk100               : in  std_logic; 
                                 
      pixel_in_addr        : in  std_logic_vector(25 downto 0);
      pixel_in_data        : in  std_logic_vector(63 downto 0);  
      pixel_in_we          : in  std_logic;   
      pixel_in_done        : out std_logic := '0'       
   );
end entity;

architecture arch of framebuffer is
   
   -- data write
   signal pixel_in_addr_1 : integer range 0 to (FRAMESIZE_X * FRAMESIZE_Y);
   signal pixel_in_data_1 : std_logic_vector(63 downto 0);
   signal pixel_in_we_1   : std_logic;

   type tPixelArray is array(0 to (FRAMESIZE_X * FRAMESIZE_Y)) of std_logic_vector(31 downto 0);
   signal PixelArray : tPixelArray := (others => (others => '0'));
   
begin 

   -- fill framebuffer
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         pixel_in_done <= pixel_in_we;
         
         pixel_in_addr_1 <= ((to_integer(unsigned(pixel_in_addr(19 downto 0))) / 512) * 480) + to_integer(unsigned(pixel_in_addr(19 downto 0))) mod 512;
         pixel_in_data_1 <= pixel_in_data;
         pixel_in_we_1   <= pixel_in_we; 
         
         if (pixel_in_we_1 = '1') then
            PixelArray(pixel_in_addr_1)     <= pixel_in_data_1(31 downto 0);
            PixelArray(pixel_in_addr_1 + 1) <= pixel_in_data_1(63 downto 32);
         end if;
      
      end if;
   end process;

-- synthesis translate_off
   
   goutput : if 1 = 1 generate
   begin
   
      process
      
         file outfile: text;
         variable f_status: FILE_OPEN_STATUS;
         variable line_out : line;
         variable color : unsigned(31 downto 0);
         variable linecounter_int : integer;
         
      begin
   
         file_open(f_status, outfile, "gra_fb_out_large.gra", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "gra_fb_out_large.gra", append_mode);
         write(line_out, string'("480#320")); 
         writeline(outfile, line_out);
         
         while (true) loop
            wait until ((pixel_in_addr_1 mod FRAMESIZE_X) = (FRAMESIZE_X - 2)) and pixel_in_we = '1';
            linecounter_int := pixel_in_addr_1 / FRAMESIZE_X;
   
            wait for 100 ns;
   
            for x in 0 to (FRAMESIZE_X - 1) loop
               color := unsigned(PixelArray(x + linecounter_int * FRAMESIZE_X));
               color := color(31 downto 24) & color(7 downto 0) & color(15 downto 8) & color(23 downto 16);
            
               write(line_out, to_integer(color));
               write(line_out, string'("#"));
               write(line_out, x);
               write(line_out, string'("#")); 
               write(line_out, linecounter_int);
               writeline(outfile, line_out);
   
            end loop;
            
            file_close(outfile);
            file_open(f_status, outfile, "gra_fb_out_large.gra", append_mode);
            
         end loop;
         
      end process;
   
   end generate goutput;
   
-- synthesis translate_on

end architecture;





