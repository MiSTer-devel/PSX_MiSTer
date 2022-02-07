-- todo:
-- signal that cheat could not be saved, because memory full

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pProc_bus_gba.all;

entity gba_cheats is
   port 
   (
      clk100         : in     std_logic;  
      gb_on          : in     std_logic;
      
      cheat_clear    : in     std_logic;
      cheats_enabled : in     std_logic;
      cheat_on       : in     std_logic;
      cheat_in       : in     std_logic_vector(127 downto 0);
      cheats_active  : out    std_logic := '0';
      
      vsync          : in     std_logic;
      
      bus_ena_in     : in     std_logic;
      sleep_cheats   : out    std_logic := '0';
      
      BusAddr        : buffer std_logic_vector(27 downto 0);
      BusRnW         : out    std_logic;
      BusACC         : out    std_logic_vector(1 downto 0);
      BusWriteData   : out    std_logic_vector(31 downto 0);
      Bus_ena        : out    std_logic := '0';
      BusReadData    : in     std_logic_vector(31 downto 0);
      BusDone        : in     std_logic
   );
end entity;

architecture arch of gba_cheats is

   constant CHEATCOUNT  : integer := 32;
   constant SETTLECOUNT : integer := 100;
   
   constant OPTYPE_ALWAYS     : std_logic_vector(3 downto 0) := x"0";
   constant OPTYPE_EQUALS     : std_logic_vector(3 downto 0) := x"1";
   constant OPTYPE_GREATER    : std_logic_vector(3 downto 0) := x"2";
   constant OPTYPE_LESS       : std_logic_vector(3 downto 0) := x"3";
   constant OPTYPE_GREATER_EQ : std_logic_vector(3 downto 0) := x"4";
   constant OPTYPE_LESS_EQ    : std_logic_vector(3 downto 0) := x"5";
   constant OPTYPE_NOT_EQ     : std_logic_vector(3 downto 0) := x"6"; 
   constant OPTYPE_EMPTY      : std_logic_vector(3 downto 0) := x"F"; 
   
   constant BYTEMASK_BIT_0    : integer := 100;
   constant BYTEMASK_BIT_1    : integer := 101;
   constant BYTEMASK_BIT_2    : integer := 102;
   constant BYTEMASK_BIT_3    : integer := 103;
   
   type tstate is
   (
      IDLE,
      RESET_CLEAR,
      FIFO_WAIT,
      FIFO_LOADMEM,
      FIFO_CHECKMEM,
      WAIT_GBAIDLE,
      LOAD_CHEAT,
      NEXT_CHEAT,
      SKIPTEST,
      WAIT_READ,
      APPLY_CHEAT,
      CHEAT_TEST,
      WAIT_WRITE 
   );
   signal state : tstate := RESET_CLEAR;
   
   signal cheat_on_1  : std_logic := '0';
   signal cheat_valid : std_logic := '0';
   signal cheat_in_1  : std_logic_vector(127 downto 0);

   signal fifo_Dout   : std_logic_vector(127 downto 0);
   signal fifo_Rd     : std_logic := '0';
   signal fifo_Empty  : std_logic;
   
   type t_cheatmem is array(0 to CHEATCOUNT - 1) of std_logic_vector(127 downto 0);
   signal cheatmem : t_cheatmem := (others => (others => '1'));
   
   signal cheatindex : integer range 0 to CHEATCOUNT - 1 := 0;
   signal cheatdata  : std_logic_vector(127 downto 0);
   
   signal stop_defragment : integer range 0 to CHEATCOUNT - 1 := 0;
   
   signal first_free : integer range 0 to CHEATCOUNT := 0;
   
   signal skip_next  : std_logic := '0';
   signal oldvalue   : std_logic_vector(31 downto 0);
   
   signal settle     : integer range 0 to SETTLECOUNT := 0;
   
   
begin 

   iSyncFifo : entity MEM.SyncFifo
   generic map
   (
      SIZE             => CHEATCOUNT,
      DATAWIDTH        => 128,
      NEARFULLDISTANCE => 0
   )
   port map
   ( 
      clk      => clk100,
      reset    => '0',
               
      Din      => cheat_in_1,  
      Wr       => cheat_valid,   
      Full     => open, 
                  
      Dout     => fifo_Dout, 
      Rd       => fifo_Rd,   
      Empty    => fifo_Empty
   );

   BusACC <= ACCESS_32BIT;

   process (clk100)
   begin
      if rising_edge(clk100) then
   
         fifo_Rd <= '0';
         Bus_ena <= '0';
   
         cheat_on_1 <= cheat_on;
         cheat_in_1 <= cheat_in;
         
         cheat_valid <= '0';
         if (cheat_on = '1' and cheat_on_1 = '0') then
            cheat_valid <= '1';
         end if;
   
         if (gb_on = '0') then
            
            state      <= RESET_CLEAR;
            cheatindex <= 0;
         
         else
         
            case state is
            
               when IDLE =>
                  sleep_cheats <= '0';
                  if (cheat_clear = '1') then
                     state      <= RESET_CLEAR;
                     cheatindex <= 0;
                  elsif (cheats_enabled = '1' and vsync = '1') then
                     state        <= WAIT_GBAIDLE;
                     settle       <= 0;
                     cheatindex   <= 0;
                     skip_next    <= '0';
                     sleep_cheats <= '1';
                  elsif (fifo_Empty = '0') then
                     state       <= FIFO_WAIT;
                     fifo_Rd     <= '1';
                     cheatindex  <= 0;
                  end if;
                  
               -- //////////////
               -- // RESET
               -- //////////////
                  
               when RESET_CLEAR =>
                  cheats_active <= '0';
                  cheatmem(cheatindex) <= (others => '1');
                  if (cheatindex < CHEATCOUNT - 1) then
                     cheatindex <= cheatindex + 1;
                  else
                     state <= IDLE;
                  end if;
                  
               -- //////////////////////////////
               -- // Check if new cheat in memory
               -- ///////////////////////////////
                  
               when FIFO_WAIT =>
                  state <= FIFO_LOADMEM;
                  
               when FIFO_LOADMEM =>
                  cheatdata <= cheatmem(cheatindex);
                  state     <= FIFO_CHECKMEM;
                  
               when FIFO_CHECKMEM => 
                  if (cheatdata(99 downto 96) = OPTYPE_EMPTY) then
                     cheatmem(cheatindex) <= fifo_Dout;
                     state                <= IDLE;
                     cheats_active        <= '1';
                  elsif (cheatindex < CHEATCOUNT - 1) then
                     cheatindex <= cheatindex + 1;
                     state      <= FIFO_LOADMEM;
                  else
                     state <= IDLE;
                  end if;  
               
               -- //////////////////////////////
               -- // apply cheats
               -- ///////////////////////////////
               
               when WAIT_GBAIDLE =>
                  if (bus_ena_in = '1') then
                     settle <= 0;
                  elsif (settle < SETTLECOUNT) then
                     settle <= settle + 1;
                  else
                     state <= LOAD_CHEAT;
                  end if;
                     
               when LOAD_CHEAT =>
                  state      <= SKIPTEST;
                  cheatdata  <= cheatmem(cheatindex);
                     
               when NEXT_CHEAT =>
                  if (cheatindex < CHEATCOUNT - 1) then
                     cheatindex <= cheatindex + 1;
                     state      <= LOAD_CHEAT;
                  else
                     state      <= IDLE;
                  end if;
                     
               when SKIPTEST =>
                  if (cheatdata(99 downto 96) = OPTYPE_EMPTY) then
                     state <= IDLE;
                  elsif (skip_next = '1') then
                     skip_next <= '0';
                     state     <= NEXT_CHEAT;
                  else
                     state   <= WAIT_READ;
                     Bus_ena <= '1';
                     BusAddr <= cheatdata(91 downto 64);
                     BusRnW  <= '1';
                  end if;
                  
               when WAIT_READ =>
                  if (BusDone = '1') then
                     oldvalue <= BusReadData;
                     state    <= APPLY_CHEAT;
                 end if;
                     
               when APPLY_CHEAT =>
                  if (cheatdata(99 downto 96) = OPTYPE_ALWAYS) then
                     state <= WAIT_WRITE;
                     Bus_ena      <= '1';
                     BusRnW       <= '0';
                     BusWriteData <= oldvalue;
                     if (cheatdata(BYTEMASK_BIT_0) = '1') then BusWriteData( 7 downto  0) <= cheatdata( 7 downto  0); end if;
                     if (cheatdata(BYTEMASK_BIT_1) = '1') then BusWriteData(15 downto  8) <= cheatdata(15 downto  8); end if;
                     if (cheatdata(BYTEMASK_BIT_2) = '1') then BusWriteData(23 downto 16) <= cheatdata(23 downto 16); end if;
                     if (cheatdata(BYTEMASK_BIT_3) = '1') then BusWriteData(31 downto 24) <= cheatdata(31 downto 24); end if;
                  else
                     state <= CHEAT_TEST;
                     if (cheatdata(BYTEMASK_BIT_0) = '0') then oldvalue( 7 downto  0) <= x"00"; end if;
                     if (cheatdata(BYTEMASK_BIT_1) = '0') then oldvalue(15 downto  8) <= x"00"; end if;
                     if (cheatdata(BYTEMASK_BIT_2) = '0') then oldvalue(23 downto 16) <= x"00"; end if;
                     if (cheatdata(BYTEMASK_BIT_3) = '0') then oldvalue(31 downto 24) <= x"00"; end if;
                  end if;
                     
               when CHEAT_TEST =>
                  state <= NEXT_CHEAT;
                  case (cheatdata(99 downto 96)) is
                     when OPTYPE_EQUALS     => if (unsigned(oldvalue) /= unsigned(cheatdata(31 downto 0))) then skip_next <= '1'; end if; 
                     when OPTYPE_GREATER    => if (unsigned(oldvalue) <= unsigned(cheatdata(31 downto 0))) then skip_next <= '1'; end if;
                     when OPTYPE_LESS       => if (unsigned(oldvalue)  < unsigned(cheatdata(31 downto 0))) then skip_next <= '1'; end if;
                     when OPTYPE_GREATER_EQ => if (unsigned(oldvalue) >= unsigned(cheatdata(31 downto 0))) then skip_next <= '1'; end if;
                     when OPTYPE_LESS_EQ    => if (unsigned(oldvalue)  > unsigned(cheatdata(31 downto 0))) then skip_next <= '1'; end if;
                     when OPTYPE_NOT_EQ     => if (unsigned(oldvalue)  = unsigned(cheatdata(31 downto 0))) then skip_next <= '1'; end if;
                     when others => null;
                  end case;
               
               when WAIT_WRITE =>
                  if (BusDone = '1') then
                     state <= NEXT_CHEAT;
                  end if;  
            
            end case;
         
         end if;
         
      end if;
   end process;
 

end architecture;





