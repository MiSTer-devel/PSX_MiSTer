library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package pJoypad is

type joypad_t is record
   PadPortEnable : std_logic;
   PadPortDigital: std_logic;
   PadPortAnalog : std_logic;
   PadPortMouse  : std_logic;
   PadPortGunCon : std_logic;
   PadPortNeGcon : std_logic;
   PadPortJustif : std_logic;
   PadPortDS     : std_logic;
   PadPortStick  : std_logic;

   WheelMap    : std_logic;
   ToggleDS    : std_logic;

   KeyTriangle : std_logic;
   KeyCircle   : std_logic;
   KeyCross    : std_logic;
   KeySquare   : std_logic;
   KeySelect   : std_logic;
   KeyStart    : std_logic;
   KeyRight    : std_logic;
   KeyLeft     : std_logic;
   KeyUp       : std_logic;
   KeyDown     : std_logic;
   KeyR1       : std_logic;
   KeyR2       : std_logic;
   KeyR3       : std_logic;
   KeyL1       : std_logic;
   KeyL2       : std_logic;
   KeyL3       : std_logic;
   Analog1X    : signed(7 downto 0);
   Analog1Y    : signed(7 downto 0);
   Analog2X    : signed(7 downto 0);
   Analog2Y    : signed(7 downto 0);
end record joypad_t;

end package pJoypad;
