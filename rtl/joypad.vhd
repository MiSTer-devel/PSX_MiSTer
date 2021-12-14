library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use STD.textio.all;

entity joypad is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      analogPad            : in  std_logic;
      
      rumbleOn             : out std_logic := '0';
      
      irqRequest           : out std_logic := '0';
      
      KeyTriangle          : in  std_logic_vector(1 downto 0); 
      KeyCircle            : in  std_logic_vector(1 downto 0); 
      KeyCross             : in  std_logic_vector(1 downto 0); 
      KeySquare            : in  std_logic_vector(1 downto 0);
      KeySelect            : in  std_logic_vector(1 downto 0);
      KeyStart             : in  std_logic_vector(1 downto 0);
      KeyRight             : in  std_logic_vector(1 downto 0);
      KeyLeft              : in  std_logic_vector(1 downto 0);
      KeyUp                : in  std_logic_vector(1 downto 0);
      KeyDown              : in  std_logic_vector(1 downto 0);
      KeyR1                : in  std_logic_vector(1 downto 0);
      KeyR2                : in  std_logic_vector(1 downto 0);
      KeyR3                : in  std_logic_vector(1 downto 0);
      KeyL1                : in  std_logic_vector(1 downto 0);
      KeyL2                : in  std_logic_vector(1 downto 0);
      KeyL3                : in  std_logic_vector(1 downto 0);
      Analog1XP1           : in  signed(7 downto 0);
      Analog1YP1           : in  signed(7 downto 0);
      Analog2XP1           : in  signed(7 downto 0);
      Analog2YP1           : in  signed(7 downto 0);         
      Analog1XP2           : in  signed(7 downto 0);
      Analog1YP2           : in  signed(7 downto 0);
      Analog2XP2           : in  signed(7 downto 0);
      Analog2YP2           : in  signed(7 downto 0);      
      
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
      SS_DataRead          : out std_logic_vector(31 downto 0);
      SS_idle              : out std_logic
   );
end entity;

architecture arch of joypad is

   signal receiveFilled       : std_logic;
      
   signal JOY_STAT            : std_logic_vector(31 downto 0);
   signal JOY_STAT_ACK        : std_logic;
   signal transmitFilled      : std_logic;
   signal transmitBuffer      : std_logic_vector(7 downto 0);
   signal transmitValue       : std_logic_vector(7 downto 0);
      
   signal transmitting        : std_logic;
   signal waitAck             : std_logic;
      
   signal baudCnt             : unsigned(20 downto 0) := (others => '0');
      
   signal JOY_MODE            : std_logic_vector(15 downto 0);
   signal JOY_CTRL            : std_logic_vector(15 downto 0);
   signal JOY_BAUD            : std_logic_vector(15 downto 0);
      
   signal beginTransfer       : std_logic := '0';
   signal actionNext          : std_logic := '0';
   signal actionNextPad       : std_logic := '0';
      
   -- devices  
   signal isActivePad1        : std_logic;
   signal isActivePad2        : std_logic;
      
   signal selectedPad1        : std_logic;
   signal selectedPad2        : std_logic;
      
   signal ack                 : std_logic;
   signal ackPad1             : std_logic;
   signal ackPad2             : std_logic;
   
   signal receiveBuffer       : std_logic_vector(7 downto 0);
   signal receiveBufferPad1   : std_logic_vector(7 downto 0);
   signal receiveBufferPad2   : std_logic_vector(7 downto 0);
   
   signal receiveValid        : std_logic;
   signal receiveValidPad1    : std_logic;
   signal receiveValidPad2    : std_logic;

   -- savestates
   type t_ssarray is array(0 to 7) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0'));  
  
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

   ss_out(0)(20 downto 0)  <= std_logic_vector(baudCnt);  
   ss_out(1)(15 downto 0)  <= JOY_STAT(15 downto 0);    
   ss_out(1)(31 downto 16) <= JOY_MODE; 
   ss_out(2)(15 downto  0) <= JOY_CTRL;      
   ss_out(2)(31 downto 16) <= JOY_BAUD;   
   ss_out(3)( 7 downto  0) <= transmitBuffer;
   ss_out(3)(15 downto  8) <= transmitValue;
   ss_out(3)(23 downto 16) <= receiveBuffer;   
   --ss_out(3)(31 downto 24) <= std_logic_vector(to_unsigned(activeDevice, 8));    
   --ss_out(4)(15 downto 8)  <= std_logic_vector(to_unsigned(tcontrollerState'POS(controllerState), 8));       
   ss_out(4)(19)           <= receiveFilled; 
   ss_out(4)(16)           <= transmitFilled;
   ss_out(4)(17)           <= transmitting;  
   ss_out(4)(18)           <= waitAck;        

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1') then
         
            baudCnt         <= unsigned(ss_in(0)(20 downto 0));
            irqRequest      <= ss_in(1)(9);
            receiveFilled   <= ss_in(4)(19);
            JOY_STAT_ACK    <= ss_in(1)(7);
            transmitFilled  <= ss_in(4)(16);
            transmitting    <= ss_in(4)(17);
            waitAck         <= ss_in(4)(18);
            JOY_MODE        <= ss_in(1)(31 downto 16);
            JOY_CTRL        <= ss_in(2)(15 downto  0);
            JOY_BAUD        <= ss_in(2)(31 downto 16);
            
            transmitBuffer  <= ss_in(3)(7 downto 0);
            transmitValue   <= ss_in(3)(15 downto 8);
            receiveBuffer   <= ss_in(3)(23 downto 16);
            --activeDevice    <= to_integer(unsigned(ss_in(3)(31 downto 24)));
            --controllerState <= tcontrollerState'VAL(to_integer(unsigned(ss_in(4)(15 downto 8))));
            
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
                           
                           if (bus_dataWrite(17 downto 16) = "11") then -- select and tx en
                              if (transmitting = '0' and waitAck = '0' and transmitFilled = '1') then
                                 beginTransfer <= '1';
                              end if;
                           else
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
            
            actionNext    <= '0';
            actionNextPad <= '0';
            if (baudCnt > 0) then
               baudCnt <= baudCnt - 1;
               if (baudCnt = 3) then
                  actionNextPad <= '1';
               end if;
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
                  if (receiveValid = '1') then
                     receiveBuffer <= receiveBufferPad1 or receiveBufferPad2;
                  else
                     receiveBuffer  <= x"FF";
                  end if;
                  receiveFilled  <= '1';
                  transmitting   <= '0';
                  if (ack = '1') then
                     waitAck <= '1';
                     baudCnt <= to_unsigned(452, 21); -- 170 for memory card
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
   
   ack          <= ackPad1 or ackPad2;
   receiveValid <= receiveValidPad1 or receiveValidPad2;
   
   selectedPad1 <= '1' when (JOY_CTRL(13) = '0' and JOY_CTRL(1 downto 0) = "11") else '0';
   selectedPad2 <= '1' when (JOY_CTRL(13) = '1' and JOY_CTRL(1 downto 0) = "11") else '0';
   
   ijoypad_pad1 : entity work.joypad_pad
   port map
   (
      clk1x                => clk1x,    
      ce                   => ce,       
      reset                => reset,    
       
      analogPad            => analogPad,

      selected             => selectedPad1,
      actionNext           => actionNextPad,
      transmitting         => transmitting,
      transmitValue        => transmitValue,
 
      isActive             => isActivePad1,
      slotIdle             => '1',

      receiveValid         => receiveValidPad1,
      receiveBuffer        => receiveBufferPad1,
      ack                  => ackPad1,

      rumbleOn             => rumbleOn,

      KeyTriangle          => KeyTriangle(0),
      KeyCircle            => KeyCircle(0),  
      KeyCross             => KeyCross(0),   
      KeySquare            => KeySquare(0),  
      KeySelect            => KeySelect(0),  
      KeyStart             => KeyStart(0),   
      KeyRight             => KeyRight(0),   
      KeyLeft              => KeyLeft(0),    
      KeyUp                => KeyUp(0),      
      KeyDown              => KeyDown(0),    
      KeyR1                => KeyR1(0),      
      KeyR2                => KeyR2(0),      
      KeyR3                => KeyR3(0),      
      KeyL1                => KeyL1(0),      
      KeyL2                => KeyL2(0),      
      KeyL3                => KeyL3(0),      
      Analog1X             => Analog1XP1,   
      Analog1Y             => Analog1YP1,   
      Analog2X             => Analog2XP1,   
      Analog2Y             => Analog2YP1
   );
   
   ijoypad_pad2 : entity work.joypad_pad
   port map
   (
      clk1x                => clk1x,    
      ce                   => ce,       
      reset                => reset,    
       
      analogPad            => analogPad,

      selected             => selectedPad2,
      actionNext           => actionNextPad,
      transmitting         => transmitting,
      transmitValue        => transmitValue,
 
      isActive             => isActivePad2,
      slotIdle             => '1',

      receiveValid         => receiveValidPad2,
      receiveBuffer        => receiveBufferPad2,
      ack                  => ackPad2,

      rumbleOn             => rumbleOn,

      KeyTriangle          => KeyTriangle(1),
      KeyCircle            => KeyCircle(1),  
      KeyCross             => KeyCross(1),   
      KeySquare            => KeySquare(1),  
      KeySelect            => KeySelect(1),  
      KeyStart             => KeyStart(1),   
      KeyRight             => KeyRight(1),   
      KeyLeft              => KeyLeft(1),    
      KeyUp                => KeyUp(1),      
      KeyDown              => KeyDown(1),    
      KeyR1                => KeyR1(1),      
      KeyR2                => KeyR2(1),      
      KeyR3                => KeyR3(1),      
      KeyL1                => KeyL1(1),      
      KeyL2                => KeyL2(1),      
      KeyL3                => KeyL3(1),      
      Analog1X             => Analog1XP2,   
      Analog1Y             => Analog1YP2,   
      Analog2X             => Analog2XP2,   
      Analog2Y             => Analog2YP2
   );
   
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
            
         elsif (SS_wren = '1') then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         SS_idle <= '0';
         if (transmitting = '0' and waitAck = '0' and beginTransfer = '0' and actionNext = '0' and isActivePad1 = '0' and isActivePad2 = '0') then
            SS_idle <= '1';
         end if;
         
         if (SS_rden = '1') then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;
   
   -- synthesis translate_off

   goutput : if 1 = 1 generate
   signal outputCnt : unsigned(31 downto 0) := (others => '0'); 
   
   begin
      process
         constant WRITETIME            : std_logic := '1';
         
         file outfile                  : text;
         variable f_status             : FILE_OPEN_STATUS;
         variable line_out             : line;
            
         variable clkCounter           : unsigned(31 downto 0);
         variable newoutputCnt         : unsigned(31 downto 0);
            
         variable bus_adr              : unsigned(7 downto 0);
         variable bus_data             : unsigned(15 downto 0);
         variable transmit_1           : std_logic;
         variable irq_1                : std_logic;
         variable bus_read_1           : std_logic;
         variable bus_addr_1           : unsigned(3 downto 0); 
      begin
   
         file_open(f_status, outfile, "R:\\debug_pad_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\debug_pad_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (reset = '1') then
               clkCounter := (others => '0');
            end if;
            
            newoutputCnt := outputCnt;
            
            if (bus_write = '1') then
               write(line_out, string'("WRITE: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
                  write(line_out, string'(" ")); 
               end if;
               bus_adr  := x"0" & bus_addr;
               bus_data := unsigned(bus_dataWrite(15 downto 0));
               if (bus_addr = x"8" and bus_writeMask(3 downto 2) /= "00") then
                  bus_adr := x"0A";
                  bus_data := unsigned(bus_dataWrite(31 downto 16));
               end if;
               if (bus_addr = x"C" and bus_writeMask(3 downto 2) /= "00") then
                  bus_adr := x"0E";
                  bus_data := unsigned(bus_dataWrite(31 downto 16));
               end if;
               write(line_out, to_hstring(bus_adr));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(bus_data));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (bus_read_1 = '1') then
               write(line_out, string'("READ: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
               end if;
               write(line_out, string'(" 0")); 
               write(line_out, to_hstring(bus_addr_1));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(bus_dataRead(15 downto 0)));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            bus_read_1 := bus_read;
            bus_addr_1 := bus_addr;
            
            if (beginTransfer = '1') then
               write(line_out, string'("BEGINTRANSFER: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 1));
               end if;
               write(line_out, string'(" 00 00")); 
               write(line_out, to_hstring(transmitBuffer));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if;             
            
            if (transmit_1 = '1') then
               write(line_out, string'("TRANSMIT: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter + 1));
               end if;
               write(line_out, string'(" 00 00")); 
               write(line_out, to_hstring(receiveBuffer));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            transmit_1 := (not beginTransfer) and actionNext and transmitting;
            
            if (irq_1 = '1') then
               write(line_out, string'("IRQ: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
               end if;
               write(line_out, string'(" 00 ")); 
               write(line_out, to_hstring(JOY_STAT(15 downto 0)));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            irq_1 := (not beginTransfer) and actionNext and (not transmitting) and JOY_CTRL(12);
            
            outputCnt <= newoutputCnt;
            clkCounter := clkCounter + 1;
           
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on
end architecture;





