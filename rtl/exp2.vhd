library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

entity exp2 is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      bus_addr             : in  unsigned(12 downto 0); 
      bus_dataWrite        : in  std_logic_vector(7 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(7 downto 0)
      
      --serial_newchar       : out std_logic := '0';
      --serial_newline       : out std_logic := '0';
      --serial_char          : out std_logic_vector(7 downto 0)
   );
end entity;

architecture arch of exp2 is

begin 

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         --serial_newchar <= '0';
         --serial_newline <= '0';
      
         if (reset = '1') then
         
         elsif (ce = '1') then
         
            bus_dataRead <= (others => '0');

            if (bus_read = '1') then
               bus_dataRead <= (others => '1');
               if (bus_addr = 16#21#) then
                  bus_dataRead <= x"0C";
               end if;
            end if;
            
            --if (bus_write = '1') then
            --   if (bus_addr = 16#23# or bus_addr = 16#80#) then
            --      
            --      serial_char <= bus_dataWrite;
            --      
            --      if (bus_dataWrite = x"0D") then -- '\r'
            --         -- do nothing
            --      elsif (bus_dataWrite = x"0A") then -- '\n'
            --         serial_newline <= '1';
            --      else
            --         serial_newchar <= '1';
            --      end if;
            --      
            --   
            --   end if;
            --end if;
            
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
   
         file_open(f_status, outfile, "R:\\debug_tty_sim.txt", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "R:\\debug_tty_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (bus_write = '1') then
               if (bus_addr = 16#23# or bus_addr = 16#80#) then

                  if (bus_dataWrite = x"0D") then -- '\r'
                     -- do nothing
                  elsif (bus_dataWrite = x"0A") then -- '\n'
                     writeline(outfile, line_out);
                     file_close(outfile);
                     file_open(f_status, outfile, "R:\\debug_tty_sim.txt", append_mode);
                  else
                     write(line_out, character'val(to_integer(unsigned(bus_dataWrite)))); 
                  end if;
                  
               end if;
               
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on

end architecture;





