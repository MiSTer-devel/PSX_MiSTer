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
      bus_dataRead         : out std_logic_vector(31 downto 0);
      
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(2 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of sio is

   signal SIO_STAT : std_logic_vector(31 downto 0);
   signal SIO_MODE : std_logic_vector( 7 downto 0);
   signal SIO_CTRL : std_logic_vector(15 downto 0);
   signal SIO_BAUD : std_logic_vector(15 downto 0);
   
   -- savestates
   type t_ssarray is array(0 to 7) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0')); 
  
begin 

   ss_out(0)              <= SIO_STAT;
   ss_out(1)( 7 downto 0) <= SIO_MODE;
   ss_out(2)(15 downto 0) <= SIO_CTRL;
   ss_out(3)(15 downto 0) <= SIO_BAUD;

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
         
            SIO_STAT <= ss_in(0);              -- x"00000005";
            SIO_MODE <= ss_in(1)( 7 downto 0); -- x"00";
            SIO_CTRL <= ss_in(2)(15 downto 0); -- x"0000";
            SIO_BAUD <= ss_in(3)(15 downto 0); -- x"00DC";
            
         elsif (ce = '1') then
         
            bus_dataRead <= (others => '0');

            -- bus read
            if (bus_read = '1') then
               case (bus_addr(3 downto 0)) is
                  when x"4" => bus_dataRead <= SIO_STAT;    
                  when x"8" => bus_dataRead <= SIO_CTRL & x"00" & SIO_MODE;
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
                        SIO_MODE <= bus_dataWrite(7 downto 0);
                     elsif (bus_writeMask(3 downto 2) /= "00") then
                        SIO_CTRL <= bus_dataWrite(31 downto 16);
                        if (bus_dataWrite(22) = '1') then -- reset
                           SIO_STAT <= x"00000005";
                           SIO_MODE <= x"00";
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

--##############################################################
--############################### savestates
--##############################################################
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 1 loop
               ss_in(i) <= (others => '0');
            end loop;
            
            ss_in(0) <= x"00000005"; -- SIO_STAT  
            ss_in(3) <= x"000000DC"; -- SIO_BAUD  
            
         elsif (SS_wren = '1') then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         if (SS_rden = '1') then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;

end architecture;





