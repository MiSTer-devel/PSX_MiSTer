library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- todo: This implementation of the Justifier sensor is just using the same
-- pattern as the crosshair overlay. This will likely need to be adjusted
-- to get more accurate behavior, once any inaccuracy in the dotclock timers
-- is worked out.
-- This implementation also does not yet handle a dedicated "shoot offscreen"
-- button properly in the same way that other cores do.

entity justifier_sensor is
   port
   (
      clk                  : in  std_logic;
      clkvid               : in  std_logic;
      ce                   : in  std_logic;
      vsync                : in  std_logic;
      hblank               : in  std_logic;

      xpos_gun             : in integer range 0 to 1023;
      ypos_gun             : in integer range 0 to 1023;
      xpos_screen          : in integer range 0 to 1023;
      ypos_screen          : in integer range 0 to 1023;

      out_irq10            : out std_logic := '0'
   );
end entity;

architecture arch of justifier_sensor is

   -- receive
   type tState is
   (
      CHECKLINE,
      CHECKPOS,
      DRAW,
      WAITHSYNC
   );
   signal state : tState := CHECKLINE;

   signal diff       : integer range -1024 to 1023;
   signal draw_count : integer range 0 to 3;
   
   signal irq10      : std_logic := '0';
   signal irq10_1    : std_logic := '0';
   signal irq10_2    : std_logic := '0';

begin

   irq10  <= '1' when (state = DRAW) else '0';


   diff <= ypos_screen - ypos_gun when state = CHECKLINE else
           xpos_screen - xpos_gun;

   process (clk)
   begin
      if rising_edge(clk) then
         
         irq10_1   <= irq10;
         irq10_2   <= irq10_1;
         out_irq10 <= irq10_2;

      end if;
   end process;

   process (clkvid)
   begin
      if rising_edge(clkvid) then

         case (state) is

            when CHECKLINE =>
               if (hblank = '0' and diff >= -3 and diff <= 3) then
                  state <= CHECKPOS;
                  if (diff = 0) then
                     state <= CHECKPOS;
                  end if;
               end if;

            when CHECKPOS =>
               draw_count <= 3;
               if (diff = 0) then
                  state      <= DRAW;
               end if;

            when DRAW =>
               if (ce = '1') then
                  if (draw_count > 0) then
                     draw_count <= draw_count - 1;
                  else
                     state <= WAITHSYNC;
                  end if;
               end if;

            when WAITHSYNC =>
               if (hblank = '1') then
                  state <= CHECKLINE;
               end if;

         end case;

         if (vsync = '1') then
            state <= CHECKLINE;
         end if;

      end if;
   end process;
   
end architecture;
