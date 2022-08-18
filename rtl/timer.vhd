library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity timer is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      error                : out std_logic;
      
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
      bus_dataRead         : out std_logic_vector(31 downto 0);
      
-- synthesis translate_off
      export_t_current0    : out unsigned(15 downto 0);
      export_t_current1    : out unsigned(15 downto 0);
      export_t_current2    : out unsigned(15 downto 0);
-- synthesis translate_on
      
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(3 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of timer is

   type timerRecord is record
      T_CURRENT   : unsigned(15 downto 0);
      T_MODE      : unsigned(15 downto 0);
      T_TARGET    : unsigned(15 downto 0);
      irqDone     : std_logic;
      setNext     : std_logic;
      blockNext   : std_logic;
   end record;
  
   type ttimerArray is array (0 to 2) of timerRecord;
   signal timerArray : ttimerArray := (others => ((others => '0'), (others => '0'), (others => '0'), '0', '0', '0'));
  
   signal timer2_subcount : unsigned(2 downto 0);
   signal hblank_1        : std_logic;
   signal vblank_1        : std_logic;
   signal dotclock_1      : std_logic;
   
   signal setValue        : unsigned(15 downto 0);
   
   -- savestates
   type t_ssarray is array(0 to 15) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0'));  
   
begin 

   irqRequest0 <= not timerArray(0).T_MODE(10);
   irqRequest1 <= not timerArray(1).T_MODE(10);
   irqRequest2 <= not timerArray(2).T_MODE(10);
   
-- synthesis translate_off
   export_t_current0 <= timerArray(0).T_CURRENT;
   export_t_current1 <= timerArray(1).T_CURRENT;
   export_t_current2 <= timerArray(2).T_CURRENT;
-- synthesis translate_on
   
   ss_out(0)(15 downto 0) <= std_logic_vector(timerArray(0).T_CURRENT);
   ss_out(3)(15 downto 0) <= std_logic_vector(timerArray(0).T_MODE);   
   ss_out(6)(15 downto 0) <= std_logic_vector(timerArray(0).T_TARGET); 
   ss_out(9)(11)          <= timerArray(0).irqDone; 
   ss_out(1)(15 downto 0) <= std_logic_vector(timerArray(1).T_CURRENT);
   ss_out(4)(15 downto 0) <= std_logic_vector(timerArray(1).T_MODE);   
   ss_out(7)(15 downto 0) <= std_logic_vector(timerArray(1).T_TARGET); 
   ss_out(9)(12)          <= timerArray(1).irqDone;  
   ss_out(2)(15 downto 0) <= std_logic_vector(timerArray(2).T_CURRENT);
   ss_out(5)(15 downto 0) <= std_logic_vector(timerArray(2).T_MODE);   
   ss_out(8)(15 downto 0) <= std_logic_vector(timerArray(2).T_TARGET); 
   ss_out(9)(13)          <= timerArray(2).irqDone;  
   ss_out(9)(2 downto 0)  <= std_logic_vector(timer2_subcount);        

   process (clk1x)
      variable channel  : integer range 0 to 3;
      variable newTick  : std_logic_vector(2 downto 0);
      variable newIRQ   : std_logic;
   begin
      if rising_edge(clk1x) then
      
         error <= '0';
      
         if (reset = '1') then
         
            timerArray(0).T_CURRENT <= unsigned(ss_in(0)(15 downto 0));
            timerArray(0).T_MODE    <= unsigned(ss_in(3)(15 downto 0)); -- x"0400";
            timerArray(0).T_TARGET  <= unsigned(ss_in(6)(15 downto 0));
            timerArray(0).irqDone   <= ss_in(9)(11);
            
            timerArray(1).T_CURRENT <= unsigned(ss_in(1)(15 downto 0));
            timerArray(1).T_MODE    <= unsigned(ss_in(4)(15 downto 0)); -- x"0400";
            timerArray(1).T_TARGET  <= unsigned(ss_in(7)(15 downto 0));
            timerArray(1).irqDone   <= ss_in(9)(12);
            
            timerArray(2).T_CURRENT <= unsigned(ss_in(2)(15 downto 0));
            timerArray(2).T_MODE    <= unsigned(ss_in(5)(15 downto 0)); -- x"0400";
            timerArray(2).T_TARGET  <= unsigned(ss_in(8)(15 downto 0));
            timerArray(2).irqDone   <= ss_in(9)(13);
         
            for i in 0 to 2 loop
               timerArray(i).setNext   <= '0';
               timerArray(i).blockNext <= '0';
            end loop;
         
            timer2_subcount <= unsigned(ss_in(9)(2 downto 0));
            hblank_1        <= hblank;
            vblank_1        <= vblank;

         elsif (ce = '1') then
         
            timer2_subcount <= timer2_subcount + 1;
            hblank_1        <= hblank;
            vblank_1        <= vblank;
            dotclock_1      <= dotclock;
            
            for i in 0 to 2 loop
               if (timerArray(i).T_MODE(7) = '0') then -- not toggle mode -> reset irq
                  timerArray(i).T_MODE(10) <= '1';
               end if;
            end loop;
         
            -- check for new ticks
            newTick := "000";
            if (timerArray(0).T_MODE(8) = '1') then
               newTick(0) := dotclock and (not dotclock_1);
            else
               newTick(0) := '1';
            end if;
            
            if (timerArray(1).T_MODE(8) = '1') then
               if (hblank_1 = '0' and hblank = '1') then  -- todo: correct hblank timer tick position to be found
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

               timerArray(i).setNext   <= '0';
               timerArray(i).blockNext <= '0';
               
               if (timerArray(i).setNext = '1') then -- reset from bus write
               
                  timerArray(i).T_CURRENT <= setValue;
                  timerArray(i).blockNext <= '1';
                  
               elsif (newTick(i) = '1' and timerArray(i).blockNext = '0') then
               
                  timerArray(i).T_CURRENT <= timerArray(i).T_CURRENT + 1;
                  newIRQ   := '0';
                  
                  if (timerArray(i).T_CURRENT = timerArray(i).T_TARGET) then
                     timerArray(i).T_MODE(11) <= '1';
                     if (timerArray(i).T_MODE(4) = '1') then
                        newIRQ := '1';
                     end if;
                     if (timerArray(i).T_MODE(3) = '1') then
                        timerArray(i).T_CURRENT <= (others => '0');
                        timerArray(i).blockNext <= '1';
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

               end if;
            end loop;
            
            -- apply resets
            if (timerArray(0).T_MODE(0) = '1') then
               if (timerArray(0).T_MODE(2 downto 1) = "01" or timerArray(0).T_MODE(2 downto 1) = "10") then
                  if (hblank_1 = '0' and hblank = '1') then 
                     timerArray(0).T_CURRENT <= (others => '0'); 
                  end if;
               end if;
               if (timerArray(0).T_MODE(2 downto 1) = "11") then
                  if (hblank_1 = '0' and hblank = '1') then 
                     timerArray(0).T_MODE(0) <= '0';
                  end if;
               end if;
            end if;
            
            if (timerArray(1).T_MODE(0) = '1') then
               if (timerArray(1).T_MODE(2 downto 1) = "01" or timerArray(1).T_MODE(2 downto 1) = "10") then
                  if (vblank_1 = '0' and vblank = '1') then 
                     timerArray(1).T_CURRENT <= (others => '0'); 
                  end if;
               end if;
               if (timerArray(1).T_MODE(2 downto 1) = "11") then
                  if (vblank_1 = '0' and vblank = '1') then 
                     timerArray(1).T_MODE(0) <= '0';
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
                     when x"0" => 
                        timerArray(channel).setNext <= '1';
                        setValue                    <= unsigned(bus_dataWrite(15 downto 0));
                     when x"4" => 
                        timerArray(channel).T_MODE( 9 downto  0) <= unsigned(bus_dataWrite( 9 downto  0));
                        timerArray(channel).T_MODE(15 downto 13) <= unsigned(bus_dataWrite(15 downto 13));
                        timerArray(channel).irqDone              <= '0';
                        timerArray(channel).setNext              <= '1';
                        setValue                                 <= (others => '0');
                     when x"8" => timerArray(channel).T_TARGET <= unsigned(bus_dataWrite(15 downto 0));
                     when others => null;
                  end case;
               end if;
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
            
            ss_in(3)(15 downto 0) <= x"0400"; -- T_MODE0
            ss_in(4)(15 downto 0) <= x"0400"; -- T_MODE1
            ss_in(5)(15 downto 0) <= x"0400"; -- T_MODE2
            
         elsif (SS_wren = '1') then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         if (SS_rden = '1') then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;

end architecture;





