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
      
      irqRequest           : out std_logic := '0';
      
      KeyTriangle          : in  std_logic; 
      KeyCircle            : in  std_logic; 
      KeyCross             : in  std_logic; 
      KeySquare            : in  std_logic;
      KeySelect            : in  std_logic;
      KeyStart             : in  std_logic;
      KeyRight             : in  std_logic;
      KeyLeft              : in  std_logic;
      KeyUp                : in  std_logic;
      KeyDown              : in  std_logic;
      KeyR1                : in  std_logic;
      KeyR2                : in  std_logic;
      KeyR3                : in  std_logic;
      KeyL1                : in  std_logic;
      KeyL2                : in  std_logic;
      KeyL3                : in  std_logic;
      Analog1X             : in  signed(7 downto 0);
      Analog1Y             : in  signed(7 downto 0);
      Analog2X             : in  signed(7 downto 0);
      Analog2Y             : in  signed(7 downto 0);      
      
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
      SS_DataRead          : out std_logic_vector(31 downto 0)
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
  
   -- savestates
   type t_ssarray is array(0 to 7) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
  
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
         
            irqRequest      <= ss_in(1)(9);
            receiveFilled   <= ss_in(4)(19);
            JOY_STAT_ACK    <= ss_in(1)(7);
            transmitFilled  <= ss_in(4)(16);
            transmitting    <= ss_in(4)(17);
            waitAck         <= ss_in(4)(18);
            baudCnt         <= unsigned(ss_in(0)(20 downto 0));
            JOY_MODE        <= ss_in(1)(31 downto 16);
            JOY_CTRL        <= ss_in(2)(15 downto  0);
            JOY_BAUD        <= ss_in(2)(31 downto 16);
            
            activeDevice    <= to_integer(unsigned(ss_in(3)(31 downto 24)));
            controllerState <= tcontrollerState'VAL(to_integer(unsigned(ss_in(4)(15 downto 8))));
            
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
                              receiveBuffer(0) <= not KeySelect;
                              receiveBuffer(1) <= not KeyL3;
                              receiveBuffer(2) <= not KeyR3;
                              receiveBuffer(3) <= not KeyStart;
                              receiveBuffer(4) <= not KeyUp;
                              receiveBuffer(5) <= not KeyRight;
                              receiveBuffer(6) <= not KeyDown;
                              receiveBuffer(7) <= not KeyLeft;
                              controllerState <= BUTTONMSB;
                              ack := '1';
                              
                           when BUTTONMSB => 
                              receiveBuffer(0) <= not KeyL2;
                              receiveBuffer(1) <= not KeyR2;
                              receiveBuffer(2) <= not KeyL1;
                              receiveBuffer(3) <= not KeyR1;
                              receiveBuffer(4) <= not KeyTriangle;
                              receiveBuffer(5) <= not KeyCircle;
                              receiveBuffer(6) <= not KeyCross;
                              receiveBuffer(7) <= not KeySquare;
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





