library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity joypad_pad is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      analogPad            : in  std_logic;
      mouse                : in  std_logic := '0';
      
      selected             : in  std_logic;
      actionNext           : in  std_logic := '0';
      transmitting         : in  std_logic := '0';
      transmitValue        : in  std_logic_vector(7 downto 0);
      
      isActive             : out std_logic := '0';
      slotIdle             : in  std_logic;
      
      receiveValid         : out std_logic;
      receiveBuffer        : out std_logic_vector(7 downto 0);
      ack                  : out std_logic;

      rumbleOn             : out std_logic := '0';

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
      MouseEvent           : in  std_logic;
      MouseLeft            : in  std_logic;
      MouseRight           : in  std_logic;
      MouseX               : in  signed(8 downto 0);
      MouseY               : in  signed(8 downto 0)
   );
end entity;

architecture arch of joypad_pad is
   
   type tcontrollerState is
   (
      IDLE,
      READY,
      ID,
      BUTTONLSB,
      BUTTONMSB,
      MOUSEBUTTONSLSB,
      MOUSEBUTTONSMSB,
      MOUSEAXISX,
      MOUSEAXISY,
      ANALOGRIGHTX,
      ANALOGRIGHTY,
      ANALOGLEFTX,
      ANALOGLEFTY
   );
   signal controllerState : tcontrollerState := IDLE;
   
   signal analogPadSave   : std_logic := '0';
   signal rumbleOnFirst   : std_logic := '0';
   signal mouseSave       : std_logic := '0';

   signal prevMouseEvent  : std_logic := '0';

   signal mouseAccX       : signed(9 downto 0) := (others => '0');
   signal mouseAccY       : signed(9 downto 0) := (others => '0');

   signal mouseOutX          : signed(7 downto 0) := (others => '0');
   signal mouseOutY          : signed(7 downto 0) := (others => '0');
  
begin 

  
   process (clk1x)

   variable mouseIncX     : signed(9 downto 0) := (others => '0');
   variable mouseIncY     : signed(9 downto 0) := (others => '0');
   variable newMouseAccX  : signed(9 downto 0) := (others => '0');
   variable newMouseAccY  : signed(9 downto 0) := (others => '0');
   variable newMouseAccClippedX  : signed(9 downto 0) := (others => '0');
   variable newMouseAccClippedY  : signed(9 downto 0) := (others => '0');

   begin
      if rising_edge(clk1x) then
      
         receiveValid   <= '0';
         receiveBuffer  <= x"00";
      
         ack <= '0';
      
         if (reset = '1') then
         
            controllerState <= IDLE;
            isActive        <= '0';
            rumbleOn        <= '0';
            mouseAccX       <= (others => '0');
            mouseAccY       <= (others => '0');

         elsif (ce = '1') then
         
            if (selected = '0') then
               isActive        <= '0';
               controllerState <= IDLE;
            end if;

            prevMouseEvent  <= MouseEvent;
            if (prevMouseEvent /= MouseEvent) then
                mouseIncX := resize(MouseX, mouseIncX'length);
                mouseIncX := resize(MouseY, mouseIncX'length);
            else
                mouseIncX := to_signed(0, mouseIncX'length);
                mouseIncY := to_signed(0, mouseIncY'length);
            end if;

            newMouseAccX := mouseAccX + mouseIncX;
            newMouseAccY := mouseAccY + mouseIncY;

            if (newMouseAccX >= 255) then
                newMouseAccClippedX := to_signed(255, newMouseAccClippedX'length);
            elsif (newMouseAccX <= -256) then
                newMouseAccClippedX := to_signed(-256, newMouseAccClippedX'length);
            else
                newMouseAccClippedX := newMouseAccX;
            end if;

            if (newMouseAccY >= 255) then
                newMouseAccClippedY := to_signed(255, newMouseAccClippedY'length);
            elsif (newMouseAccY <= -256) then
                newMouseAccClippedY := to_signed(-256, newMouseAccClippedY'length);
            else
                newMouseAccClippedY := newMouseAccY;
            end if;

            mouseAccX <= newMouseAccClippedX;
            mouseAccY <= newMouseAccClippedY;
         
            if (actionNext = '1' and transmitting = '1') then
               if (selected = '1') then
                  if (isActive = '0' and slotIdle = '1') then
                     if (controllerState = IDLE and transmitValue = x"01") then
                        controllerState <= READY;
                        isActive        <= '1';
                        ack             <= '1'; 
                        analogPadSave   <= analogPad;
                        receiveValid    <= '1';
                        receiveBuffer   <= x"FF";

                     end if;
                  elsif (isActive = '1') then
                     case (controllerState) is
                        when IDLE => 
                           if (transmitValue = x"01") then
                              controllerState <= READY;
                              isActive        <= '1';
                              ack             <= '1';
                              analogPadSave   <= analogPad;
                              mouseSave       <= mouse;
                              receiveValid    <= '1';
                              receiveBuffer   <= x"FF";

                              if (mouseAccX >= 255) then
                                  mouseOutX <= to_signed(255, mouseOutX'length);
                              elsif (mouseAccX <= -256) then
                                  mouseOutX <= to_signed(-256, mouseOutX'length);
                              else
                                  mouseOutX <= resize(mouseAccX, mouseOutX'length);
                              end if;

                              if (mouseAccY >= 255) then
                                  mouseOutY <= to_signed(255, mouseOutY'length);
                              elsif (mouseAccY <= -256) then
                                  mouseOutY <= to_signed(-256, mouseOutY'length);
                              else
                                  mouseOutY <= resize(mouseAccY, mouseOutY'length);
                              end if;

                              mouseAccX       <= mouseIncX;
                              mouseAccY       <= mouseIncY;

                           end if;
                           
                        when READY => 
                           if (transmitValue = x"42") then
                              if (mouseSave = '1') then
                                 receiveBuffer   <= x"12";
                              elsif (analogPadSave = '1') then
                                 receiveBuffer   <= x"73";
                              else
                                 receiveBuffer   <= x"41";
                              end if;
                              controllerState <= ID;
                              ack             <= '1';
                              receiveValid    <= '1';
                           end if;
                           
                        when ID => 
                           receiveBuffer   <= x"5A";
                           if (mouseSave = '1') then
                               controllerState <= MOUSEBUTTONSLSB;
                           else
                               controllerState <= BUTTONLSB;
                           end if;
                           ack             <= '1';
                           receiveValid    <= '1';
                           
                        when MOUSEBUTTONSLSB =>
                           controllerState  <= MOUSEBUTTONSMSB;
                           receiveBuffer   <= x"FF";
                           ack              <= '1';
                           receiveValid    <= '1';

                        when MOUSEBUTTONSMSB =>
                           receiveBuffer(0) <= '0';
                           receiveBuffer(1) <= '0';
                           receiveBuffer(2) <= not MouseRight;
                           receiveBuffer(3) <= not MouseLeft;
                           receiveBuffer(4) <= '1';
                           receiveBuffer(5) <= '1';
                           receiveBuffer(6) <= '1';
                           receiveBuffer(7) <= '1';
                           controllerState <= MOUSEAXISX;
                           ack              <= '1';
                           receiveValid    <= '1';

                        when MOUSEAXISX =>
                           receiveBuffer   <= std_logic_vector(mouseOutX);
                           receiveValid    <= '1';
                           controllerState <= MOUSEAXISY;
                           ack             <= '1';

                        when MOUSEAXISY =>
                           receiveBuffer   <= std_logic_vector(mouseOutY);
                           receiveValid    <= '1';
                           controllerState <= IDLE;
                           ack             <= '1';

                        when BUTTONLSB => 
                           receiveBuffer(0) <= not KeySelect;
                           receiveBuffer(1) <= not KeyL3;
                           receiveBuffer(2) <= not KeyR3;
                           receiveBuffer(3) <= not KeyStart;
                           receiveBuffer(4) <= not KeyUp;
                           receiveBuffer(5) <= not KeyRight;
                           receiveBuffer(6) <= not KeyDown;
                           receiveBuffer(7) <= not KeyLeft;
                           controllerState  <= BUTTONMSB;
                           ack              <= '1';
                           receiveValid     <= '1';
                           rumbleOnFirst    <= '0';
                           if (analogPadSave = '1' and transmitValue(7 downto 6) = "01") then
                              rumbleOnFirst <= '1';
                           end if;
                           
                           
                        when BUTTONMSB => 
                           receiveBuffer(0) <= not KeyL2;
                           receiveBuffer(1) <= not KeyR2;
                           receiveBuffer(2) <= not KeyL1;
                           receiveBuffer(3) <= not KeyR1;
                           receiveBuffer(4) <= not KeyTriangle;
                           receiveBuffer(5) <= not KeyCircle;
                           receiveBuffer(6) <= not KeyCross;
                           receiveBuffer(7) <= not KeySquare;
                           receiveValid     <= '1';
                           if (analogPadSave = '1') then
                              controllerState <= ANALOGRIGHTX;
                              ack <= '1';
                           else
                              controllerState <= IDLE;
                           end if;
                           rumbleOn <= '0';
                           if (analogPadSave = '1' and transmitValue(0) = '1' and rumbleOnFirst = '1') then
                              rumbleOn <= '1';
                           end if;
                           
                        when ANALOGRIGHTX => 
                           receiveBuffer   <= std_logic_vector(to_unsigned(to_integer(Analog2X) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= ANALOGRIGHTY;
                           ack             <= '1';
                        
                        when ANALOGRIGHTY => 
                           receiveBuffer   <= std_logic_vector(to_unsigned(to_integer(Analog2Y) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= ANALOGLEFTX;
                           ack             <= '1';
                        
                        when ANALOGLEFTX =>
                           receiveBuffer   <=std_logic_vector(to_unsigned(to_integer(Analog1X) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= ANALOGLEFTY;
                           ack             <= '1';
                        
                        when ANALOGLEFTY =>
                           receiveBuffer   <= std_logic_vector(to_unsigned(to_integer(Analog1Y) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= IDLE;
                           
                     end case;
                  end if;
               end if; -- joy select
               
            end if; -- transmit
            
         end if; -- ce
      end if; -- clock
   end process;
   
   
end architecture;





