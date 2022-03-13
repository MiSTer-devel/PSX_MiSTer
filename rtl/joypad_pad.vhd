library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pJoypad.all;

entity joypad_pad is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      joypad               : in  joypad_t;
	    rumble               : out std_logic_vector(15 downto 0);

      isPal                : in  std_logic;
      
      selected             : in  std_logic;
      actionNext           : in  std_logic := '0';
      transmitting         : in  std_logic := '0';
      transmitValue        : in  std_logic_vector(7 downto 0);
      
      isActive             : out std_logic := '0';
      slotIdle             : in  std_logic;
      
      receiveValid         : out std_logic;
      receiveBuffer        : out std_logic_vector(7 downto 0);
      ack                  : out std_logic;

      MouseEvent           : in  std_logic;
      MouseLeft            : in  std_logic;
      MouseRight           : in  std_logic;
      MouseX               : in  signed(8 downto 0);
      MouseY               : in  signed(8 downto 0);
      GunX                 : in  unsigned(7 downto 0);
      GunY_scanlines       : in  unsigned(8 downto 0);
      GunAimOffscreen      : in  std_logic
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
      GUNCONBUTTONSLSB,
      GUNCONBUTTONSMSB,
      GUNCONXLSB,
      GUNCONXMSB,
      GUNCONYLSB,
      GUNCONYMSB,
      ANALOGRIGHTX,
      ANALOGRIGHTY,
      ANALOGLEFTX,
      ANALOGLEFTY,
      NEGCONBUTTONMSB,
      NEGCONSTEERING,
      NEGCONANALOGI,
      NEGCONANALOGII,
      NEGCONANALOGL
   );
   signal controllerState : tcontrollerState := IDLE;
   
   signal analogPadSave   : std_logic := '0';
   signal rumbleOnFirst   : std_logic := '0';
   signal mouseSave       : std_logic := '0';
   signal gunConSave      : std_logic := '0';
   signal neGconSave      : std_logic := '0';

   signal prevMouseEvent  : std_logic := '0';

   signal mouseAccX       : signed(9 downto 0) := (others => '0');
   signal mouseAccY       : signed(9 downto 0) := (others => '0');

   signal mouseOutX       : signed(7 downto 0) := (others => '0');
   signal mouseOutY       : signed(7 downto 0) := (others => '0');

   signal gunOffScreen    : std_logic := '0';
   signal gunConX_8MHz    : std_logic_vector(8 downto 0) := (others => '0');
   signal gunConY         : std_logic_vector(8 downto 0) := (others => '0');
  
begin 

  
   process (clk1x)

   variable mouseIncX            : signed(9 downto 0) := (others => '0');
   variable mouseIncY            : signed(9 downto 0) := (others => '0');
   variable newMouseAccX         : signed(9 downto 0) := (others => '0');
   variable newMouseAccY         : signed(9 downto 0) := (others => '0');
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
            rumble          <= (others => '0');
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
                mouseIncY := resize(-MouseY, mouseIncX'length);
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
               if (selected = '1' and joypad.PadPortEnable = '1') then
                  if (isActive = '0' and slotIdle = '1') then
                     if (controllerState = IDLE and transmitValue = x"01") then
                        controllerState <= READY;
                        isActive        <= '1';
                        ack             <= '1'; 
                        analogPadSave   <= joypad.PadPortAnalog;
                        mouseSave       <= joypad.PadPortMouse;
                        gunConSave      <= joypad.PadPortGunCon;
                        neGconSave      <= joypad.PadPortNeGcon;
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
                              analogPadSave   <= joypad.PadPortAnalog;
                              mouseSave       <= joypad.PadPortMouse;
                              gunConSave      <= joypad.PadPortGunCon;
                              neGconSave      <= joypad.PadPortNeGcon;
                              receiveValid    <= '1';
                              receiveBuffer   <= x"FF";
                           end if;
                           
                        when READY => 
                           if (transmitValue = x"42") then
                              if (mouseSave = '1') then
                                 receiveBuffer   <= x"12";
                              elsif (gunConSave = '1') then
                                 receiveBuffer   <= x"63";
                              elsif (neGconSave = '1') then
                                 receiveBuffer   <= x"23";
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
                           elsif (gunConSave = '1') then
                               controllerState <= GUNCONBUTTONSLSB;
                           else
                               controllerState <= BUTTONLSB;
                           end if;
                           ack             <= '1';
                           receiveValid    <= '1';
                           
                        when MOUSEBUTTONSLSB =>
                           controllerState <= MOUSEBUTTONSMSB;
                           receiveBuffer   <= x"FF";
                           ack             <= '1';
                           receiveValid    <= '1';
                           
                           if (mouseAccX >= 127) then
                               mouseOutX <= to_signed(127, mouseOutX'length);
                           elsif (mouseAccX <= -128) then
                               mouseOutX <= to_signed(-128, mouseOutX'length);
                           else
                               mouseOutX <= resize(mouseAccX, mouseOutX'length);
                           end if;

                           if (mouseAccY >= 127) then
                               mouseOutY <= to_signed(127, mouseOutY'length);
                           elsif (mouseAccY <= -128) then
                               mouseOutY <= to_signed(-128, mouseOutY'length);
                           else
                               mouseOutY <= resize(mouseAccY, mouseOutY'length);
                           end if;

                           mouseAccX <= mouseIncX;
                           mouseAccY <= mouseIncY;
                           

                        when MOUSEBUTTONSMSB =>
                           receiveBuffer(0) <= '0';
                           receiveBuffer(1) <= '0';
                           receiveBuffer(2) <= not MouseRight;
                           receiveBuffer(3) <= not MouseLeft;
                           receiveBuffer(4) <= '1';
                           receiveBuffer(5) <= '1';
                           receiveBuffer(6) <= '1';
                           receiveBuffer(7) <= '1';
                           controllerState  <= MOUSEAXISX;
                           ack              <= '1';
                           receiveValid     <= '1';

                        when MOUSEAXISX =>
                           receiveBuffer   <= std_logic_vector(mouseOutX);
                           receiveValid    <= '1';
                           controllerState <= MOUSEAXISY;
                           ack             <= '1';

                        when MOUSEAXISY =>
                           receiveBuffer   <= std_logic_vector(mouseOutY);
                           receiveValid    <= '1';
                           controllerState <= IDLE;

                        when GUNCONBUTTONSLSB =>
                           controllerState <= GUNCONBUTTONSMSB;
                           ack             <= '1';
                           receiveValid    <= '1';

                           if joypad.KeyTriangle = '1' or GunAimOffscreen = '1' then
                              gunOffscreen <= '1';
                           else
                              gunOffscreen <= '0';
                           end if;

                           receiveBuffer(0) <= '1';
                           receiveBuffer(1) <= '1';
                           receiveBuffer(2) <= '1';
                           receiveBuffer(3) <= not joypad.KeyStart; -- A (left-side button)
                           receiveBuffer(4) <= '1';
                           receiveBuffer(5) <= '1';
                           receiveBuffer(6) <= '1';
                           receiveBuffer(7) <= '1';

                        when GUNCONBUTTONSMSB =>
                           controllerState  <= GUNCONXLSB;
                           ack              <= '1';
                           receiveValid     <= '1';

                           -- GunCon reports X as # of 8MHz clks since HSYNC (01h=Error, or 04Dh..1CDh).
                           -- Map from joystick's +/-128 to GunCon range (8MHz clocks): (GunX * 384/256) + 67
                           if gunOffscreen = '0' then
                              gunConX_8MHz  <= std_logic_vector(to_unsigned(67, 9) + resize(GunX, 9) + resize(GunX(7 downto 1), 9) );
                           else
                              gunConX_8MHz  <= "000000001"; -- X: 0x0001, Y: 0x000A indicates no light / offscreen shot
                           end if;

                           receiveBuffer(0) <= '1';
                           receiveBuffer(1) <= '1';
                           receiveBuffer(2) <= '1';
                           receiveBuffer(3) <= '1';
                           receiveBuffer(4) <= '1';
                           receiveBuffer(5) <= not (joypad.KeyCircle or joypad.KeyTriangle); -- Trigger
                           receiveBuffer(6) <= not joypad.KeyCross; -- B (right-side button)
                           receiveBuffer(7) <= '1';

                        when GUNCONXLSB =>
                           controllerState <= GUNCONXMSB;
                           receiveValid    <= '1';
                           ack             <= '1';

                           receiveBuffer   <= gunConX_8MHz(7 downto 0);

                        when GUNCONXMSB =>
                           controllerState <= GUNCONYLSB;
                           receiveValid    <= '1';
                           ack             <= '1';

                           -- GunCon reports Y as # of scanlines since VSYNC (05h/0Ah=Error, PAL=20h..127h, NTSC=19h..F8h)
                           if gunOffscreen = '0' then
                              if isPal = '1' then
                                 gunConY      <= std_logic_vector(to_unsigned(40, 9) + GunY_scanlines);
                              else
                                 gunConY      <= std_logic_vector(to_unsigned(16, 9) + GunY_scanlines);
                              end if;
                           else
                              gunConY      <= "000001010"; -- X: 0x0001, Y: 0x000A indicates no light / offscreen shot
                           end if;

                           receiveBuffer   <= "0000000" & gunConX_8MHz(8);

                        when GUNCONYLSB =>
                           controllerState <= GUNCONYMSB;
                           receiveValid    <= '1';
                           ack             <= '1';

                           receiveBuffer   <= gunConY(7 downto 0);

                        when GUNCONYMSB =>
                           controllerState <= IDLE;
                           receiveValid    <= '1';

                           receiveBuffer   <= "0000000" & gunConY(8);

                        when BUTTONLSB => 
                           receiveBuffer(0) <= not joypad.KeySelect;
                           receiveBuffer(1) <= not joypad.KeyL3;
                           receiveBuffer(2) <= not joypad.KeyR3;
                           receiveBuffer(3) <= not joypad.KeyStart;
                           receiveBuffer(4) <= not joypad.KeyUp;
                           receiveBuffer(5) <= not joypad.KeyRight;
                           receiveBuffer(6) <= not joypad.KeyDown;
                           receiveBuffer(7) <= not joypad.KeyLeft;
                           if (neGconSave = '1') then
                              controllerState  <= NEGCONBUTTONMSB;
                           else
                              controllerState  <= BUTTONMSB;
                           end if;
                           ack              <= '1';
                           receiveValid     <= '1';
                           rumbleOnFirst    <= '0';
                           if (analogPadSave = '1' and (transmitValue(7) = '1' or  transmitValue(6) = '1')) then
                              rumbleOnFirst <= '1';
                           end if;
                           
                           
                        when BUTTONMSB => 
                           receiveBuffer(0) <= not joypad.KeyL2;
                           receiveBuffer(1) <= not joypad.KeyR2;
                           receiveBuffer(2) <= not joypad.KeyL1;
                           receiveBuffer(3) <= not joypad.KeyR1;
                           receiveBuffer(4) <= not joypad.KeyTriangle;
                           receiveBuffer(5) <= not joypad.KeyCircle;
                           receiveBuffer(6) <= not joypad.KeyCross;
                           receiveBuffer(7) <= not joypad.KeySquare;
                           receiveValid     <= '1';
                           if (analogPadSave = '1') then
                              controllerState <= ANALOGRIGHTX;
                              ack <= '1';
                           else
                              controllerState <= IDLE;
                           end if;
                           rumble <= X"0000";
                           if (analogPadSave = '1' and (transmitValue(0) = '1' or rumbleOnFirst = '1')) then
                              rumble <= X"FFFF";
                           end if;
                           
                        when ANALOGRIGHTX => 
                           receiveBuffer   <= std_logic_vector(to_unsigned(to_integer(joypad.Analog2X) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= ANALOGRIGHTY;
                           ack             <= '1';
                        
                        when ANALOGRIGHTY => 
                           receiveBuffer   <= std_logic_vector(to_unsigned(to_integer(joypad.Analog2Y) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= ANALOGLEFTX;
                           ack             <= '1';
                        
                        when ANALOGLEFTX =>
                           receiveBuffer   <=std_logic_vector(to_unsigned(to_integer(joypad.Analog1X) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= ANALOGLEFTY;
                           ack             <= '1';
                        
                        when ANALOGLEFTY =>
                           receiveBuffer   <= std_logic_vector(to_unsigned(to_integer(joypad.Analog1Y) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= IDLE;

                        when NEGCONBUTTONMSB =>
                           -- 0 0 0 R1 B A 0 0
                           receiveBuffer(0) <= '1'; -- NeGcon does not report
                           receiveBuffer(1) <= '1'; -- NeGcon does not report
                           receiveBuffer(2) <= '1'; -- NeGcon does not report
                           receiveBuffer(3) <= not joypad.KeyR1;
                           receiveBuffer(4) <= not joypad.KeyTriangle;
                           receiveBuffer(5) <= not joypad.KeyCircle;
                           receiveBuffer(6) <= '1'; -- NeGcon does not report
                           receiveBuffer(7) <= '1'; -- NeGcon does not report
                           receiveValid     <= '1';
                           controllerState <= NEGCONSTEERING;
                           ack <= '1';

                        when NEGCONSTEERING =>
                           -- Same as ANALOGLEFTX, use IF in there to go to NEGCONANALOGI?
                           receiveBuffer   <= std_logic_vector(to_unsigned(to_integer(joypad.Analog1X) + 128, 8));
                           receiveValid    <= '1';
                           controllerState <= NEGCONANALOGI;
                           ack             <= '1';

                        when NEGCONANALOGI =>
                           if ( to_integer(joypad.Analog2Y) < 0) then
                              -- Buttons are right stick up
                              -- Due to half resolution of the stick its range of -128 to 1 is mapped to 0x03 to 0xFF
                              receiveBuffer   <= std_logic_vector(1 + shift_left(not to_unsigned(to_integer(joypad.Analog2Y),8),1));
                           elsif (joypad.KeyCross = '1' or joypad.KeyR2 = '1') then
                              -- Buttons are Buttons and full throttle
                              receiveBuffer   <= "11111111";
                           else
                              receiveBuffer   <= "00000000";
                           end if;
                           receiveValid    <= '1';
                           controllerState <= NEGCONANALOGII;
                           ack             <= '1';

                        when NEGCONANALOGII =>
                           if ( to_integer(joypad.Analog2Y) > 0) then
                              -- Buttons are right stick down
                              -- Due to half resolution of the stick its range of 1 to 127 is mapped to 0x03 to 0xFF
                              receiveBuffer   <= std_logic_vector(1 + shift_left(to_unsigned(to_integer(joypad.Analog2Y),8),1));
                           elsif (joypad.KeySquare = '1' or joypad.KeyL2 = '1') then
                              -- Buttons are Buttons and full throttle
                              receiveBuffer   <= "11111111";
                           end if;
                           receiveValid    <= '1';
                           controllerState <= NEGCONANALOGL;
                           ack             <= '1';

                        when NEGCONANALOGL =>
                           -- Ran out of analog buttons, ideally analog triggers would be supported and a layout
                           -- R2->I, L2->II, AnalogR->L would be possible, enabling I/II being independent when analog and have analog L
                           if (joypad.KeyL1 = '1') then
                              receiveBuffer   <= "11111111";
                           else
                              receiveBuffer   <= "00000000";
                           end if;
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





