library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity joypad_mem is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      memcard_available    : in  std_logic;
      mem_request          : out std_logic := '0';
      mem_BURSTCNT         : out std_logic_vector(7 downto 0) := (others => '0'); 
      mem_ADDR             : out std_logic_vector(19 downto 0) := (others => '0');                       
      mem_DIN              : out std_logic_vector(63 downto 0) := (others => '0');
      mem_BE               : out std_logic_vector(7 downto 0) := (others => '0'); 
      mem_WE               : out std_logic := '0';
      mem_RD               : out std_logic := '0';
      mem_ack              : in  std_logic;
      mem_DOUT             : in  std_logic_vector(63 downto 0);
      mem_DOUT_READY       : in  std_logic;
      
      selected             : in  std_logic;
      actionNext           : in  std_logic := '0';
      transmitting         : in  std_logic := '0';
      transmitValue        : in  std_logic_vector(7 downto 0);
      
      isActive             : out std_logic := '0';
      slotIdle             : in  std_logic;
      
      receiveValid         : out std_logic;
      receiveBuffer        : out std_logic_vector(7 downto 0);
      ack                  : out std_logic
   );
end entity;

architecture arch of joypad_mem is
   
   type tState is
   (
      IDLE,
      COMMAND,
      
		READID1,
		READID2,
		READADDR1,
		READADDR2,
		READACK1,
		READACK2,
		READCONFADDR1,
		READCONFADDR2,
		READDATA,
		READCHECKSUM,
		READEND,

		WRITEID1,
		WRITEID2,
		WRITEADDR1,
		WRITEADDR2,
		WRITEDATA,
		WRITECHECKSUM,
		WRITEACK1,
		WRITEACK2,
		WRITEEND
   );
   signal state         : tState := IDLE;
         
   signal flags         : std_logic_vector(7 downto 0);
  
   signal lastData      : std_logic_vector(7 downto 0);
   signal cardAddr      : std_logic_vector(9 downto 0);
   signal addrCounter   : unsigned(6 downto 0);
   
   signal checksum      : std_logic_vector(7 downto 0);
  
   -- memory
   signal mem_addrA     : std_logic_vector(6 downto 0) := (others => '0');
   signal mem_DataInA   : std_logic_vector(7 downto 0);
   signal mem_wrenA     : std_logic := '0';
   signal mem_DataOutA  : std_logic_vector(7 downto 0);
  
   signal mem_addrB     : std_logic_vector(3 downto 0) := (others => '0');
   signal mem_DataInB   : std_logic_vector(63 downto 0);
   signal mem_wrenB     : std_logic := '0';
   signal mem_DataOutB  : std_logic_vector(63 downto 0);

   type tMemState is
   (
      MEMIDLE,
      MEMCPUWRITE_READDATA,
      MEMCPUWRITE_REQWRITE,
      MEMCPUWRITE_WAITACK,
      MEMCPUREAD_REQDATA,
      MEMCPUREAD_WAITACK,
      MEMCPUREAD_READDATA
   );
   signal memstate      : tMemState := MEMIDLE;

   signal triggerRead   : std_logic := '0';
   signal triggerWrite  : std_logic := '0';
   
   signal cardAddr2X    : std_logic_vector(9 downto 0);
   signal readCnt2X     : std_logic_vector(3 downto 0);

begin 

  
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         receiveValid   <= '0';
         receiveBuffer  <= x"00";
         
         ack            <= '0';
         
         mem_wrenA      <= '0';
         
         triggerRead    <= '0';
         triggerWrite   <= '0';
         
         if (receiveValid = '1') then
            lastData <= receiveBuffer;
         end if; 

         if (reset = '1' or memcard_available = '0') then
         
            state      <= IDLE;
            isActive   <= '0';
            flags      <= x"08";

         elsif (ce = '1') then
         
            if (selected = '0') then
               isActive <= '0';
               state    <= IDLE;
            end if;
         
            if (actionNext = '1' and transmitting = '1') then
               if (selected = '1' and memcard_available = '1') then
                  if (isActive = '0' and slotIdle = '1') then
                     if (state = IDLE and transmitValue = x"81") then
                        state           <= COMMAND;
                        isActive        <= '1';
                        ack             <= '1'; 
                        receiveValid    <= '1';
                        receiveBuffer   <= x"FF";
                     end if;
                  elsif (isActive = '1') then
                     case (state) is
                        when IDLE => 
                           if (transmitValue = x"81") then
                              state           <= COMMAND;
                              isActive        <= '1';
                              ack             <= '1';
                              receiveValid    <= '1';
                              receiveBuffer   <= x"FF";
                           end if;
                           
                        when COMMAND => 
                           if (transmitValue = x"52") then
                              receiveBuffer <= flags;
                              receiveValid  <= '1';
                              state         <= READID1;
                              ack           <= '1';
                           elsif (transmitValue = x"57") then
                              receiveBuffer <= flags;
                              receiveValid  <= '1';
                              state         <= WRITEID1;
                              ack           <= '1';
                           else
                              receiveBuffer <= flags;
                              receiveValid  <= '1';
                              state         <= IDLE;
                           end if;
                        
                        -- reading
                        when READID1       => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"5A";                           state <= READID2;                     
                        when READID2       => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"5D";                           state <= READADDR1;                     
                        when READADDR1     => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"00";                           state <= READADDR2;      cardAddr(9 downto 8) <= transmitValue(1 downto 0);
                        when READADDR2     => ack <= '1'; receiveValid <= '1'; receiveBuffer <= lastData;                        state <= READACK1;       cardAddr(7 downto 0) <= transmitValue; 
                        when READACK1      => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"5C";                           state <= READACK2;       triggerRead <= '1';
                        when READACK2      => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"5D";                           state <= READCONFADDR1;
                        when READCONFADDR1 => ack <= '1'; receiveValid <= '1'; receiveBuffer <= "000000" & cardAddr(9 downto 8); state <= READCONFADDR2;  
                        when READCONFADDR2 => ack <= '1'; receiveValid <= '1'; receiveBuffer <= cardAddr(7 downto 0);            state <= READDATA;       
                           addrCounter <= (others => '0');
                           checksum    <= ("000000" & cardAddr(9 downto 8)) xor cardAddr(7 downto 0);
                           mem_addrA   <= "0000000";
                        
                        when READDATA      =>
                           ack           <= '1'; 
                           receiveBuffer <= mem_DataOutA;
                           receiveValid  <= '1';
                           checksum      <= checksum xor mem_DataOutA;
                           mem_addrA     <= std_logic_vector(unsigned(mem_addrA) + 1);
                           if (addrCounter = 127) then
                              state      <= READCHECKSUM;
                           else
                              addrCounter <= addrCounter + 1;
                           end if;
                        
                        when READCHECKSUM  => ack <= '1'; receiveValid <= '1'; receiveBuffer <= checksum; state <= READEND;
                        when READEND       => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"47";    state <= IDLE;
                        
                        -- writing
                        when WRITEID1      => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"5A";    state <= WRITEID2;
                        when WRITEID2      => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"5D";    state <= WRITEADDR1;
                        when WRITEADDR1    => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"00";    state <= WRITEADDR2; cardAddr(9 downto 8) <= transmitValue(1 downto 0);
                        when WRITEADDR2    => ack <= '1'; receiveValid <= '1'; receiveBuffer <= lastData; state <= WRITEDATA;  cardAddr(7 downto 0) <= transmitValue;
                           addrCounter <= (others => '0');
                           checksum    <= ("000000" & cardAddr(9 downto 8)) xor transmitValue;
                        
                        when WRITEDATA     =>
                           flags(3)      <= '0';
                           ack           <= '1'; 
                           receiveBuffer <= lastData;
                           receiveValid  <= '1';
                           mem_wrenA     <= '1';
                           mem_DataInA   <= transmitValue;
                           mem_addrA     <= std_logic_vector(addrCounter);
                           checksum      <= checksum xor transmitValue;
                           if (addrCounter = 127) then
                              state        <= WRITECHECKSUM;
                              triggerWrite <= '1';
                           else
                              addrCounter <= addrCounter + 1;
                           end if;
                        
                        when WRITECHECKSUM => ack <= '1'; receiveValid <= '1'; receiveBuffer <= checksum; state <= WRITEACK1; 
                        when WRITEACK1     => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"5C";    state <= WRITEACK2; 
                        when WRITEACK2     => ack <= '1'; receiveValid <= '1'; receiveBuffer <= x"5D";    state <= WRITEEND;                  
                        when WRITEEND      => ack <= '0'; receiveValid <= '1'; receiveBuffer <= x"47";    state <= IDLE;                       
                              
                     end case;
                  end if;
               end if; -- joy select
               
            end if; -- transmit
            
         end if; -- ce
      end if; -- clock
   end process;
   
   iramSectorBuffer: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 7,
      data_width_a  => 8,
      addr_width_b  => 4,
      data_width_b  => 64
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => mem_addrA,
      data_a      => mem_DataInA,
      wren_a      => mem_wrenA,
      q_a         => mem_DataOutA,
      
      clock_b     => clk2x,
      address_b   => mem_addrB,
      data_b      => mem_DataInB,
      wren_b      => mem_wrenB,
      q_b         => mem_DataOutB
   );
   
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         mem_wrenB <= '0';
      
         if (reset = '1') then

            memstate    <= MEMIDLE;
            mem_request <= '0';

         else
            
            case (memstate) is
            
               when MEMIDLE =>
                  if (triggerWrite = '1') then
                     memstate   <= MEMCPUWRITE_READDATA;
                     mem_addrB  <= (others => '0');
                     cardAddr2X <= cardAddr;
                  elsif (triggerRead = '1') then
                     memstate   <= MEMCPUREAD_REQDATA;
                     readCnt2X  <= (others => '0');
                     cardAddr2X <= cardAddr;
                  end if;
            
               -- write from CPU to DDR3
               when MEMCPUWRITE_READDATA =>
                  memstate <= MEMCPUWRITE_REQWRITE;
            
               when MEMCPUWRITE_REQWRITE =>
                  memstate     <= MEMCPUWRITE_WAITACK;
                  mem_request  <= '1';
                  mem_BURSTCNT <= x"01";
                  mem_ADDR     <= "000" & cardAddr2X & mem_addrB & "000";
                  mem_DIN      <= mem_DataOutB;
                  mem_BE       <= x"FF";
                  mem_WE       <= '1';
                  mem_RD       <= '0';
                  
               when MEMCPUWRITE_WAITACK =>
                  if (mem_ack = '1') then
                     mem_request <= '0';
                     if (unsigned(mem_addrB) = 15) then
                        memstate    <= MEMIDLE;
                        mem_WE      <= '0';
                        mem_RD      <= '0';
                     else
                        mem_addrB <= std_logic_vector(unsigned(mem_addrB) + 1);
                        memstate  <= MEMCPUWRITE_READDATA;
                     end if;
                  end if;
                  
               -- read from DDR3 to CPU
               when MEMCPUREAD_REQDATA =>
                  memstate     <= MEMCPUREAD_WAITACK;
                  mem_request  <= '1';
                  mem_BURSTCNT <= x"10";
                  mem_ADDR     <= "000" & cardAddr2X & "0000" & "000";
                  mem_BE       <= x"FF";
                  mem_WE       <= '0';
                  mem_RD       <= '1';
               
               when MEMCPUREAD_WAITACK =>
                  if (mem_ack = '1') then
                     memstate <= MEMCPUREAD_READDATA;
                  end if;
                  
               when MEMCPUREAD_READDATA =>
                  if (mem_DOUT_READY = '1') then
                  
                     mem_addrB   <= readCnt2X;
                     mem_DataInB <= mem_DOUT;
                     mem_wrenB   <= '1';
                  
                     if (unsigned(readCnt2X) = 15) then
                        memstate    <= MEMIDLE;
                        mem_request <= '0';
                        mem_WE      <= '0';
                        mem_RD      <= '0';
                     else 
                        readCnt2X <= std_logic_vector(unsigned(readCnt2X) + 1);
                     end if;
                  end if;
            
            end case;
         
         
         end if;
      
      end if;
   end process;
   
end architecture;





