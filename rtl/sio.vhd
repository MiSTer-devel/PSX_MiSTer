library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity sio is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic; 
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_writeMask        : in  std_logic_vector(3 downto 0);
      bus_dataRead         : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of sio is

   signal SIO_STAT : std_logic_vector(31 downto 0);
   signal SIO_MODE : std_logic_vector(15 downto 0);
   signal SIO_CTRL : std_logic_vector(15 downto 0);
   signal SIO_BAUD : std_logic_vector(15 downto 0);
  
begin 

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
         
            SIO_STAT <= (others => '0');
            SIO_MODE <= x"0005";
            SIO_CTRL <= x"0000";
            SIO_BAUD <= x"00DC";
            
         elsif (ce = '1') then
         
            bus_dataRead <= (others => '0');

            -- bus read
            if (bus_read = '1') then
               case (bus_addr(3 downto 0)) is
                  when x"4" => bus_dataRead <= SIO_STAT;    
                  when x"8" => bus_dataRead <= x"0000" & SIO_MODE;
                  when x"A" => bus_dataRead <= x"0000" & SIO_CTRL;                    
                  when x"E" => bus_dataRead <= x"0000" & SIO_BAUD;  
                  when others => bus_dataRead <= (others => '1');
               end case;
            end if;

            -- bus write
            if (bus_write = '1') then
               case (bus_addr(3 downto 0)) is
                  when x"8" =>
                     if (bus_writeMask(1 downto 0) /= "00") then
                        SIO_MODE <= bus_dataWrite(15 downto 0);
                     elsif (bus_writeMask(3 downto 2) /= "00") then
                        SIO_CTRL <= bus_dataWrite(31 downto 16);
                        if (bus_dataWrite(22) = '1') then -- reset
                           SIO_STAT <= (others => '0');
                           SIO_MODE <= x"0005";
                           SIO_CTRL <= x"0000";
                           SIO_BAUD <= x"00DC";
                        end if; 
                     end if;
                     
                  when x"C" =>
                     if (bus_writeMask(3 downto 2) /= "00") then
                        SIO_BAUD <= bus_dataWrite(31 downto 16);
                     end if;
                  
                  when others => null;
               end case;
            end if;

         end if;
      end if;
   end process;

end architecture;





