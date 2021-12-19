library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  
use STD.textio.all;

entity framebuffer is
   port 
   (
      clk                  : in  std_logic;                
      hblank               : in  std_logic;
      vblank               : in  std_logic;
      video_ce             : in  std_logic;
      video_interlace      : in  std_logic;
      video_r              : in  std_logic_vector(7 downto 0);
      video_g              : in  std_logic_vector(7 downto 0);
      video_b              : in  std_logic_vector(7 downto 0)  
   );
end entity;

architecture arch of framebuffer is

   signal linecounter  : integer := 0;
   signal pixelcounter : integer := 0;

begin 

-- synthesis translate_off
   
   goutput : if 1 = 1 generate
   begin
   
      process
      
         file outfile: text;
         variable f_status: FILE_OPEN_STATUS;
         variable line_out : line;
         variable color : unsigned(31 downto 0);
         variable il_1         : std_logic := '0';
         variable il_on        : std_logic := '0';
         
      begin
   
         file_open(f_status, outfile, "gra_fb_out_vga.gra", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "gra_fb_out_vga.gra", append_mode);
         write(line_out, string'("640#480#1")); 
         writeline(outfile, line_out);
         
         while (true) loop
            wait until rising_edge(clk);
            if (video_ce = '1') then
               if (hblank = '0' and vblank = '0') then
                  color := x"00" & unsigned(video_r) & unsigned(video_g) & unsigned(video_b);
                  write(line_out, to_integer(color));
                  write(line_out, string'("#"));
                  write(line_out, pixelcounter);
                  write(line_out, string'("#")); 
                  if (il_on = '1') then
                     if (video_interlace = '1') then
                        write(line_out, linecounter * 2 + 1);
                     else
                        write(line_out, linecounter * 2);
                     end if;
                  else
                     write(line_out, linecounter);
                  end if;
                  writeline(outfile, line_out);
                  pixelcounter <= pixelcounter + 1;
               end if;
               if (hblank = '1') then
                  if (pixelcounter > 0) then
                     linecounter <= linecounter + 1;
                     file_close(outfile);
                     file_open(f_status, outfile, "gra_fb_out_vga.gra", append_mode);
                     if (il_1 /= video_interlace) then
                        il_on := '1';
                     end if;
                     il_1 := video_interlace;
                  end if;
                  pixelcounter <= 0;
               end if;
               if (vblank = '1') then
                  linecounter <= 0;
               end if;
            end if;
         end loop;
         
      end process;
   
   end generate goutput;
   
-- synthesis translate_on

end architecture;





