library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity timer is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      dotclock             : in  std_logic;
      hblank               : in  std_logic;
      vblank               : in  std_logic;
      
      irqRequest0          : out std_logic := '0';  
      irqRequest1          : out std_logic := '0';  
      irqRequest2          : out std_logic := '0';  
      
      bus_addr             : in  unsigned(5 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of timer is

   type timerRecord is record
      T_CURRENT   : unsigned(15 downto 0);
      T_MODE      : unsigned(15 downto 0);
      T_TARGET    : unsigned(15 downto 0);
      irqDone     : std_logic;
   end record;
  
   type ttimerArray is array (0 to 2) of timerRecord;
   signal timerArray : ttimerArray;
  
   signal timer2_subcount : unsigned(2 downto 0);
   signal hblank_1        : std_logic;
   signal vblank_1        : std_logic;
  
begin 

   irqRequest0 <= not timerArray(0).T_MODE(10);
   irqRequest1 <= not timerArray(1).T_MODE(10);
   irqRequest2 <= not timerArray(2).T_MODE(10);

   process (clk1x)
      variable channel  : integer range 0 to 3;
      variable newTick  : std_logic_vector(2 downto 0);
      variable newValue : unsigned(15 downto 0);
      variable newIRQ   : std_logic;
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
         
            for i in 0 to 2 loop
               timerArray(i).T_CURRENT <= (others => '0');
               timerArray(i).T_MODE    <= x"0400";
               timerArray(i).T_TARGET  <= (others => '0');
               timerArray(i).irqDone   <= '0';
            end loop;
            
            timer2_subcount <= (others => '0');

         elsif (ce = '1') then
         
            timer2_subcount <= timer2_subcount + 1;
            hblank_1        <= hblank;
            vblank_1        <= vblank;
            
            for i in 0 to 2 loop
               if (timerArray(i).T_MODE(7) = '0') then -- not toggle mode -> reset irq
                  timerArray(i).T_MODE(10) <= '1';
               end if;
            end loop;
         
            -- check for new ticks
            newTick := "000";
            if (timerArray(0).T_MODE(8) = '1') then
               newTick(0) := dotclock;
            else
               newTick(0) := '1';
            end if;
            
            if (timerArray(1).T_MODE(8) = '1') then
               if (hblank_1 = '0' and hblank = '1') then
                  newTick(1) := '1';
               end if;
            else
               newTick(1) := '1';
            end if;
            
            if (timerArray(2).T_MODE(9) = '1') then
               if (timer2_subcount = "111") then
                  newTick(2) := '1';
               end if;
            else
               newTick(2) := '1';
            end if;
            
            
            -- filter ticks with sync mode
            if (timerArray(0).T_MODE(0) = '1') then
               case (timerArray(0).T_MODE(2 downto 1)) is
                  when "00" => if (hblank = '1') then newTick(0) := '0'; end if;
                  when "10" => if (hblank = '0') then newTick(0) := '0'; end if;
                  when "11" => newTick(0) := '0';
                  when others => null;
               end case;
            end if;
            
            if (timerArray(1).T_MODE(0) = '1') then
               case (timerArray(1).T_MODE(2 downto 1)) is
                  when "00" => if (vblank = '1') then newTick(1) := '0'; end if;
                  when "10" => if (vblank = '0') then newTick(1) := '0'; end if;
                  when "11" => newTick(1) := '0';
                  when others => null;
               end case;
            end if;
            
            if (timerArray(2).T_MODE(0) = '1') then
               case (timerArray(2).T_MODE(2 downto 1)) is
                  when "00" => newTick(2) := '0';
                  when "11" => newTick(2) := '0';
                  when others => null;
               end case;
            end if;
            
            -- apply ticks
            for i in 0 to 2 loop
               if (newTick(i) = '1') then
                  newValue := timerArray(i).T_CURRENT + 1;
                  newIRQ   := '0';
                  
                  if ((newValue = timerArray(i).T_TARGET) or (newValue > timerArray(i).T_TARGET and timerArray(i).T_TARGET = 0)) then
                     timerArray(i).T_MODE(11) <= '1';
                     if (timerArray(i).T_MODE(4) = '1') then
                        newIRQ := '1';
                     end if;
                     if (timerArray(i).T_MODE(3) = '1') then
                        newValue := (others => '0');
                     end if;
                  end if;  

                  if (timerArray(i).T_CURRENT = x"FFFF") then
                     timerArray(i).T_MODE(12) <= '1';
                     if (timerArray(i).T_MODE(5) = '1') then
                        newIRQ := '1';
                     end if;
                  end if;
                  
                  if (newIRQ = '1') then
                     if (timerArray(i).T_MODE(7) = '1') then -- toggle mode
                        timerArray(i).T_MODE(10) <= not timerArray(i).T_MODE(10);
                     else
                        timerArray(i).T_MODE(10) <= '0';
                     end if;
                  end if;
                  
                  timerArray(i).T_CURRENT <= newValue;
               end if;
            end loop;
            
            -- apply resets
            if (timerArray(0).T_MODE(0) = '1') then
               if (timerArray(0).T_MODE(2 downto 1) = "01" or timerArray(0).T_MODE(2 downto 1) = "10") then
                  if (hblank_1 = '0' and hblank = '1') then 
                     timerArray(0).T_CURRENT <= (others => '0'); 
                  end if;
               end if;
            end if;
            
            if (timerArray(1).T_MODE(0) = '1') then
               if (timerArray(1).T_MODE(2 downto 1) = "01" or timerArray(1).T_MODE(2 downto 1) = "10") then
                  if (vblank_1 = '0' and vblank = '1') then 
                     timerArray(1).T_CURRENT <= (others => '0'); 
                  end if;
               end if;
            end if;
                  

            -- bus interface
            bus_dataRead <= (others => '0');
            
            channel := to_integer(unsigned(bus_addr(5 downto 4)));
           
            -- bus read
            if (bus_read = '1') then
               bus_dataRead <= (others => '1');
               if (channel < 3) then
                  case (bus_addr(3 downto 0)) is
                     when x"0" => bus_dataRead <= x"0000" & std_logic_vector(timerArray(channel).T_CURRENT);
                     when x"4" => 
                        bus_dataRead <= x"0000" & std_logic_vector(timerArray(channel).T_MODE);
                        timerArray(channel).T_MODE(12 downto 11) <= "00";
                     when x"8" => bus_dataRead <= x"0000" & std_logic_vector(timerArray(channel).T_TARGET);
                     when others => null;
                  end case;
               end if;
            end if;

            -- bus write
            if (bus_write = '1') then
               if (channel < 3) then
                  case (bus_addr(3 downto 0)) is
                     when x"0" => timerArray(channel).T_CURRENT <= unsigned(bus_dataWrite(15 downto 0));
                     when x"4" => 
                        timerArray(channel).T_MODE( 9 downto  0) <= unsigned(bus_dataWrite( 9 downto  0));
                        timerArray(channel).T_MODE(15 downto 13) <= unsigned(bus_dataWrite(15 downto 13));
                        timerArray(channel).T_CURRENT            <= (others => '0');
                        timerArray(channel).irqDone              <= '0';
                     when x"8" => timerArray(channel).T_TARGET <= unsigned(bus_dataWrite(15 downto 0));
                     when others => null;
                  end case;
               end if;
            end if;
            
         end if;
      end if;
   end process;

end architecture;





