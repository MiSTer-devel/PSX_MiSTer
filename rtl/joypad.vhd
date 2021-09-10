library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity joypad is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      irqRequest           : out std_logic := '0';
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_writeMask        : in  std_logic_vector(3 downto 0);
      bus_dataRead         : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of joypad is

   signal receiveFilled    : std_logic;
   signal receiveBuffer    : std_logic_vector(7 downto 0);
   
   signal JOY_STAT         : std_logic_vector(31 downto 0);
   signal JOY_STAT_ACK     : std_logic;
   signal transmitFilled   : std_logic;
   signal transmitBuffer   : std_logic_vector(7 downto 0);
   signal transmitValue    : std_logic_vector(7 downto 0);
   
   signal transmitting     : std_logic;
   signal waitAck          : std_logic;
   
   signal baudCnt          : unsigned(20 downto 0);
   
   signal JOY_MODE         : std_logic_vector(15 downto 0);
   signal JOY_CTRL         : std_logic_vector(15 downto 0);
   signal JOY_BAUD         : std_logic_vector(15 downto 0);
   
   signal activeDevice     : integer range 0 to 2;
   
   signal beginTransfer    : std_logic := '0';
   signal actionNext       : std_logic := '0';
   
   type tcontrollerState is
   (
      IDLE,
      READY,
      ID,
      BUTTONLSB,
      BUTTONMSB
   );
   signal controllerState : tcontrollerState := IDLE;
   
  
begin 

   JOY_STAT( 0) <= not transmitFilled;
   JOY_STAT( 1) <= receiveFilled;
   JOY_STAT( 2) <= (not transmitFilled) and (not transmitting);
   JOY_STAT( 3) <= '0'; -- RX parity error
   JOY_STAT( 4) <= '0'; -- unknown
   JOY_STAT( 5) <= '0'; -- unknown
   JOY_STAT( 6) <= '0'; -- unknown
   JOY_STAT( 7) <= JOY_STAT_ACK;
   JOY_STAT( 8) <= '0'; -- unknown
   JOY_STAT( 9) <= irqRequest;
   JOY_STAT(10) <= '0'; -- unknown
   JOY_STAT(31 downto 11) <= (others => '0'); --std_logic_vector(baudCnt); ??


   process (clk1x)
      variable ack : std_logic;
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
         
            irqRequest      <= '0';
            receiveFilled   <= '0';
            JOY_STAT_ACK    <= '0';
            transmitFilled  <= '0';
            transmitting    <= '0';
            waitAck         <= '0';
            baudCnt         <= (others => '0');
            JOY_MODE        <= (others => '0');
            JOY_CTRL        <= (others => '0');
            JOY_BAUD        <= (others => '0');
            
            activeDevice    <= 0;
            controllerState <= IDLE;
            
            beginTransfer   <= '0';
            actionNext      <= '0';

         elsif (ce = '1') then
         
            bus_dataRead <= (others => '0');

            beginTransfer <= '0';

            -- bus read
            if (bus_read = '1') then
               case (bus_addr(3 downto 0)) is
                  when x"0" =>
                     if (receiveFilled = '1') then
                        receiveFilled <= '0';
                        bus_dataRead  <= receiveBuffer & receiveBuffer & receiveBuffer & receiveBuffer;
                     else
                        bus_dataRead  <= (others => '1');
                     end if;
                     
                  when x"4" =>
                     bus_dataRead <= JOY_STAT;
                     JOY_STAT_ACK <= '0';
                     
                  when x"8" =>
                     bus_dataRead <= x"0000" & JOY_MODE;
                     
                  when x"A" =>
                     bus_dataRead <= x"0000" & JOY_CTRL;                  
                     
                  when x"E" =>
                     bus_dataRead <= x"0000" & JOY_BAUD;
                     
                  when others => 
                     bus_dataRead <= x"0000CBAD";
               end case;
            end if;

            -- bus write
            if (bus_write = '1') then
               case (bus_addr(3 downto 0)) is
                  when x"0" =>
                     transmitFilled <= '1';
                     transmitBuffer <= bus_dataWrite(7 downto 0);
                     if (transmitting = '0' and waitAck = '0' and JOY_CTRL(1 downto 0) = "11") then
                        beginTransfer <= '1';
                     end if;
                     
                  when x"8" =>
                     if (bus_writeMask(1 downto 0) /= "00") then
                        JOY_MODE <= bus_dataWrite(15 downto 0);
                     elsif (bus_writeMask(3 downto 2) /= "00") then
                        JOY_CTRL <= bus_dataWrite(31 downto 16);
                        
                        if (bus_dataWrite(22) = '1') then -- reset
                           transmitFilled  <= '0';
                           transmitting    <= '0';
                           receiveFilled   <= '0';
                           irqRequest      <= '0';
                           JOY_STAT_ACK    <= '0';
                           JOY_CTRL        <= (others => '0');
                           JOY_MODE        <= (others => '0');
                        else
                           if (bus_dataWrite(20) = '1') then -- ack
                              irqRequest <= '0';                           
                           end if;
                           
                           if (bus_dataWrite(17) = '0') then -- not selected
                              activeDevice <= 0;                          
                           end if;
                           
                           if (bus_dataWrite(17 downto 16) = "11") then -- select and tx en
                              if (transmitting = '0' and waitAck = '0' and transmitFilled = '1') then
                                 beginTransfer <= '1';
                              end if;
                           else
                              controllerState <= IDLE;
                              baudCnt         <= (others => '0');
                              transmitting    <= '0';
                              waitAck         <= '0';
                           end if;
                        end if; 
                     end if;
                     
                  when x"C" =>
                     if (bus_writeMask(3 downto 2) /= "00") then
                        JOY_BAUD <= bus_dataWrite(31 downto 16);
                     end if;
                  
                  when others => null;
               end case;
            end if;
            
            actionNext <= '0';
            if (baudCnt > 0) then
               baudCnt <= baudCnt - 1;
               if (baudCnt = 2) then
                  actionNext <= '1';
               end if;
            end if;

            if (beginTransfer = '1') then
               JOY_CTRL(2)    <= '1';
               transmitValue  <= transmitBuffer;
               transmitFilled <= '0';
               transmitting   <= '1';
               baudCnt        <= to_unsigned(to_integer(unsigned(JOY_BAUD)) * 8, 21);
               if (unsigned(JOY_BAUD) = 0) then
                  baudCnt     <= to_unsigned(2, 21);
               end if;
            elsif (actionNext = '1') then
               if (transmitting = '1') then
                  JOY_CTRL(2)    <= '1';
                  receiveBuffer  <= x"FF";
                  receiveFilled  <= '1';
                  transmitting   <= '0';
                  ack := '0';
                  if (JOY_CTRL(13) = '0') then -- controllerIndex 0
                     if (activeDevice = 0) then
                        if (controllerState = IDLE and transmitValue = x"01") then
                           controllerState <= READY;
                           activeDevice    <= 1;
                           ack := '1';
                        end if;
                     elsif (activeDevice = 1) then
                        case (controllerState) is
                           when IDLE => 
                              if (transmitValue = x"01") then
                                 controllerState <= READY;
                                 activeDevice    <= 1;
                                 ack := '1';
                              end if;
                              
                           when READY => 
                              if (transmitValue = x"42") then
                                 receiveBuffer   <= x"41";
                                 controllerState <= ID;
                                 ack := '1';
                              end if;
                              
                           when ID => 
                              receiveBuffer   <= x"5A";
                              controllerState <= BUTTONLSB;
                              ack := '1';
                              
                           when BUTTONLSB => 
                              receiveBuffer   <= x"FF"; -- todo : keys
                              controllerState <= BUTTONMSB;
                              ack := '1';
                              
                           when BUTTONMSB => 
                              receiveBuffer   <= x"FF"; -- todo : keys
                              controllerState <= IDLE;
                        end case;
                     end if;
                  end if;
                  if (ack = '1') then
                     waitAck <= '1';
                     baudCnt <= to_unsigned(452, 21); -- 170 for memory card
                  else
                     activeDevice <= 0;
                  end if;
               elsif (waitAck = '1') then
                  JOY_STAT_ACK <= '1';
                  if (JOY_CTRL(12) = '1') then -- irq ena
                     irqRequest <= '1';
                  end if;
                  waitAck <= '0';
                  if (transmitFilled = '1' and JOY_CTRL(1 downto 0) = "11") then
                     beginTransfer <= '1';
                  end if;
               end if;
            end if;
            
         end if;
      end if;
   end process;

end architecture;





