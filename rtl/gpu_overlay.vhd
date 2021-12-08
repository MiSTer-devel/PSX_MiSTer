library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity gpu_overlay is
   generic 
   (
      COLS                   : natural;
      BACKGROUNDON           : std_logic;
      RGB_BACK               : std_logic_vector(23 DOWNTO 0);
      RGB_FRONT              : std_logic_vector(23 DOWNTO 0);
      OFFSETX                : integer range 0 to 2047; 
      OFFSETY                : integer range 0 to 1023 
   );
   port 
   (
      clk                    : in  std_logic;
      ce                     : in  std_logic;
      
      ena                    : in  std_logic; -- Overlay ON/OFF
  
      i_pixel_out_x          : in  integer range 0 to 2047;
      i_pixel_out_y          : in  integer range 0 to 1023;

      o_pixel_out_data       : out std_logic_vector(RGB_BACK'range) := (others => '0');  
      o_pixel_out_ena        : out std_logic := '0';

      textstring             : in  unsigned(0 to COLS*8-1)
   );
end entity;

--##############################################################################

architecture arch of gpu_overlay is

   type arr_slv8 is array (natural range <>) of unsigned(7 downto 0);
   constant chars : arr_slv8 :=(
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", -- space :32
      x"00", x"00", x"00", x"00", x"00", x"18", x"18", x"00", x"00", x"18", x"18", x"18", x"18", x"18", x"18", x"18", -- ! :33
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"36", x"36", x"36", x"36",
      x"00", x"00", x"00", x"00", x"00", x"00", x"66", x"66", x"ff", x"66", x"66", x"ff", x"66", x"66", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"18", x"7e", x"ff", x"1b", x"1f", x"7e", x"f8", x"d8", x"ff", x"7e", x"18",
      x"00", x"00", x"00", x"00", x"00", x"0e", x"1b", x"db", x"6e", x"30", x"18", x"0c", x"76", x"db", x"d8", x"70",
      x"00", x"00", x"00", x"00", x"00", x"7f", x"c6", x"cf", x"d8", x"70", x"70", x"d8", x"cc", x"cc", x"6c", x"38",
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"18", x"1c", x"0c", x"0e",
      x"00", x"00", x"00", x"00", x"00", x"0c", x"18", x"30", x"30", x"30", x"30", x"30", x"30", x"30", x"18", x"0c",
      x"00", x"00", x"00", x"00", x"00", x"30", x"18", x"0c", x"0c", x"0c", x"0c", x"0c", x"0c", x"0c", x"18", x"30",
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"99", x"5a", x"3c", x"ff", x"3c", x"5a", x"99", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"00", x"18", x"18", x"18", x"ff", x"ff", x"18", x"18", x"18", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"30", x"18", x"1c", x"1c", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"ff", x"ff", x"00", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"00", x"38", x"38", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"60", x"60", x"30", x"30", x"18", x"18", x"0c", x"0c", x"06", x"06", x"03", x"03",
      x"00", x"00", x"00", x"00", x"00", x"3c", x"66", x"c3", x"e3", x"f3", x"db", x"cf", x"c7", x"c3", x"66", x"3c",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"78", x"38", x"18",
      x"00", x"00", x"00", x"00", x"00", x"ff", x"c0", x"c0", x"60", x"30", x"18", x"0c", x"06", x"03", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"03", x"03", x"07", x"7e", x"07", x"03", x"03", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"0c", x"0c", x"0c", x"0c", x"0c", x"ff", x"cc", x"6c", x"3c", x"1c", x"0c",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"03", x"03", x"07", x"fe", x"c0", x"c0", x"c0", x"c0", x"ff",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"c3", x"c3", x"c7", x"fe", x"c0", x"c0", x"c0", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"30", x"30", x"30", x"30", x"18", x"0c", x"06", x"03", x"03", x"03", x"ff",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"c3", x"c3", x"e7", x"7e", x"e7", x"c3", x"c3", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"03", x"03", x"03", x"7f", x"e7", x"c3", x"c3", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"00", x"38", x"38", x"00", x"00", x"38", x"38", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"30", x"18", x"1c", x"1c", x"00", x"00", x"1c", x"1c", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"06", x"0c", x"18", x"30", x"60", x"c0", x"60", x"30", x"18", x"0c", x"06",
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"ff", x"ff", x"00", x"ff", x"ff", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"60", x"30", x"18", x"0c", x"06", x"03", x"06", x"0c", x"18", x"30", x"60",
      x"00", x"00", x"00", x"00", x"00", x"18", x"00", x"00", x"18", x"18", x"0c", x"06", x"03", x"c3", x"c3", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"3f", x"60", x"cf", x"db", x"d3", x"dd", x"c3", x"7e", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"c3", x"c3", x"c3", x"ff", x"c3", x"c3", x"c3", x"66", x"3c", x"18",
      x"00", x"00", x"00", x"00", x"00", x"fe", x"c7", x"c3", x"c3", x"c7", x"fe", x"c7", x"c3", x"c3", x"c7", x"fe",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"c0", x"c0", x"c0", x"c0", x"c0", x"c0", x"c0", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"fc", x"ce", x"c7", x"c3", x"c3", x"c3", x"c3", x"c3", x"c7", x"ce", x"fc",
      x"00", x"00", x"00", x"00", x"00", x"ff", x"c0", x"c0", x"c0", x"c0", x"fc", x"c0", x"c0", x"c0", x"c0", x"ff",
      x"00", x"00", x"00", x"00", x"00", x"c0", x"c0", x"c0", x"c0", x"c0", x"c0", x"fc", x"c0", x"c0", x"c0", x"ff",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"c3", x"c3", x"cf", x"c0", x"c0", x"c0", x"c0", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"c3", x"c3", x"c3", x"c3", x"ff", x"c3", x"c3", x"c3", x"c3", x"c3",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"7c", x"ee", x"c6", x"06", x"06", x"06", x"06", x"06", x"06", x"06", x"06",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"c6", x"cc", x"d8", x"f0", x"e0", x"f0", x"d8", x"cc", x"c6", x"c3",
      x"00", x"00", x"00", x"00", x"00", x"ff", x"c0", x"c0", x"c0", x"c0", x"c0", x"c0", x"c0", x"c0", x"c0", x"c0",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3", x"db", x"ff", x"ff", x"e7", x"c3",
      x"00", x"00", x"00", x"00", x"00", x"c7", x"c7", x"cf", x"cf", x"df", x"db", x"fb", x"f3", x"f3", x"e3", x"e3",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"c0", x"c0", x"c0", x"c0", x"c0", x"fe", x"c7", x"c3", x"c3", x"c7", x"fe",
      x"00", x"00", x"00", x"00", x"00", x"3f", x"6e", x"df", x"db", x"c3", x"c3", x"c3", x"c3", x"c3", x"66", x"3c",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"c6", x"cc", x"d8", x"f0", x"fe", x"c7", x"c3", x"c3", x"c7", x"fe",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"03", x"03", x"07", x"7e", x"e0", x"c0", x"c0", x"e7", x"7e",
      x"00", x"00", x"00", x"00", x"00", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"ff",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"e7", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3",
      x"00", x"00", x"00", x"00", x"00", x"18", x"3c", x"3c", x"66", x"66", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"e7", x"ff", x"ff", x"db", x"db", x"c3", x"c3", x"c3", x"c3", x"c3",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"66", x"66", x"3c", x"3c", x"18", x"3c", x"3c", x"66", x"66", x"c3",
      x"00", x"00", x"00", x"00", x"00", x"18", x"18", x"18", x"18", x"18", x"18", x"3c", x"3c", x"66", x"66", x"c3",
      x"00", x"00", x"00", x"00", x"00", x"ff", x"c0", x"c0", x"60", x"30", x"7e", x"0c", x"06", x"03", x"03", x"ff",
      x"00", x"00", x"00", x"00", x"00", x"3c", x"30", x"30", x"30", x"30", x"30", x"30", x"30", x"30", x"30", x"3c",
      x"00", x"00", x"00", x"00", x"03", x"03", x"06", x"06", x"0c", x"0c", x"18", x"18", x"30", x"30", x"60", x"60",
      x"00", x"00", x"00", x"00", x"00", x"3c", x"0c", x"0c", x"0c", x"0c", x"0c", x"0c", x"0c", x"0c", x"0c", x"3c",
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"c3", x"66", x"3c", x"18",
      x"00", x"00", x"00", x"ff", x"ff", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"18", x"38", x"30", x"70",
      x"00", x"00", x"00", x"00", x"00", x"7f", x"c3", x"c3", x"7f", x"03", x"c3", x"7e", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"fe", x"c3", x"c3", x"c3", x"c3", x"fe", x"c0", x"c0", x"c0", x"c0", x"c0",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"c3", x"c0", x"c0", x"c0", x"c3", x"7e", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"7f", x"c3", x"c3", x"c3", x"c3", x"7f", x"03", x"03", x"03", x"03", x"03",
      x"00", x"00", x"00", x"00", x"00", x"7f", x"c0", x"c0", x"fe", x"c3", x"c3", x"7e", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"30", x"30", x"30", x"30", x"30", x"fc", x"30", x"30", x"30", x"33", x"1e",
      x"00", x"00", x"00", x"7e", x"c3", x"03", x"03", x"7f", x"c3", x"c3", x"c3", x"7e", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"c3", x"c3", x"c3", x"c3", x"c3", x"fe", x"c0", x"c0", x"c0", x"c0",
      x"00", x"00", x"00", x"00", x"00", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"00", x"00", x"18", x"00",
      x"00", x"00", x"00", x"38", x"6c", x"0c", x"0c", x"0c", x"0c", x"0c", x"0c", x"0c", x"00", x"00", x"0c", x"00",
      x"00", x"00", x"00", x"00", x"00", x"c6", x"cc", x"f8", x"f0", x"d8", x"cc", x"c6", x"c0", x"c0", x"c0", x"c0",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"78",
      x"00", x"00", x"00", x"00", x"00", x"db", x"db", x"db", x"db", x"db", x"db", x"fe", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"c6", x"c6", x"c6", x"c6", x"c6", x"c6", x"fc", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"7c", x"c6", x"c6", x"c6", x"c6", x"c6", x"7c", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"c0", x"c0", x"c0", x"fe", x"c3", x"c3", x"c3", x"c3", x"fe", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"03", x"03", x"03", x"7f", x"c3", x"c3", x"c3", x"c3", x"7f", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"c0", x"c0", x"c0", x"c0", x"c0", x"e0", x"fe", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"fe", x"03", x"03", x"7e", x"c0", x"c0", x"7f", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"1c", x"36", x"30", x"30", x"30", x"30", x"fc", x"30", x"30", x"30", x"00",
      x"00", x"00", x"00", x"00", x"00", x"7e", x"c6", x"c6", x"c6", x"c6", x"c6", x"c6", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"18", x"3c", x"3c", x"66", x"66", x"c3", x"c3", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"e7", x"ff", x"db", x"c3", x"c3", x"c3", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"c3", x"66", x"3c", x"18", x"3c", x"66", x"c3", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"c0", x"60", x"60", x"30", x"18", x"3c", x"66", x"66", x"c3", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"ff", x"60", x"30", x"18", x"0c", x"06", x"ff", x"00", x"00", x"00", x"00",
      x"00", x"00", x"00", x"00", x"00", x"0f", x"18", x"18", x"18", x"38", x"f0", x"38", x"18", x"18", x"18", x"0f",
      x"00", x"00", x"00", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18",
      x"00", x"00", x"00", x"00", x"00", x"f0", x"18", x"18", x"18", x"1c", x"0f", x"1c", x"18", x"18", x"18", x"f0",
      x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"06", x"8f", x"f1", x"60", x"00", x"00", x"00" 
   );
  
   signal col      : unsigned(0 to 7);
   signal drawchar : std_logic := '0';
   signal drawbg   : std_logic := '0';

   signal xchar   : integer range 0 to COLS;
   signal xpos    : integer range 0 to 7;
   signal xpos_1  : integer range 0 to 7;
   signal xwait   : integer range 0 to 2;
   
BEGIN

   process (clk) is
      variable char_v : unsigned(0 to 7);
   begin
      if rising_edge(clk) then

         if (ce = '1') then

            xpos_1 <= xpos;
            
            ----------------------------------
            -- Pick characters
            drawchar <= '0';
            drawbg   <= '0';
            
            if (i_pixel_out_x <= OFFSETX) then
               xchar <= 0;
               xpos  <= 0;
               xwait <= 0;
            else   
               if (xpos < 7) then
                  xpos <= xpos + 1;
               elsif (xwait < 2) then
                  xwait <= xwait + 1;
               elsif (xchar < COLS) then
                  xchar <= xchar + 1;
                  xpos  <= 0;
                  xwait <= 0;
               end if;
            end if;
            
            if (xchar < COLS and xwait = 0 and i_pixel_out_x > OFFSETX and i_pixel_out_y >= OFFSETY and i_pixel_out_y < OFFSETY + 16) then
               char_v   := textstring(xchar * 8 to (xchar * 8) + 7) - 32;
               col      <= chars(to_integer(char_v) * 16 + 15 - ((i_pixel_out_y - (OFFSETY mod 16)) MOD 16));
               drawchar <= '1';
            end if;
            
            if (xchar < COLS and i_pixel_out_x >= OFFSETX and i_pixel_out_y >= OFFSETY - 1 and i_pixel_out_y < OFFSETY + 14) then
               drawbg <= '1';
            end if;
            
            ----------------------------------
            -- Insert Overlay
            o_pixel_out_data <= RGB_BACK;
            o_pixel_out_ena  <= '0';
            
            if (ena = '1') then
               if (drawchar = '1' and col(xpos_1)='1') then
                  o_pixel_out_data <= RGB_FRONT;
                  o_pixel_out_ena  <= '1';
               elsif (drawbg = '1' and BACKGROUNDON = '1') then
                  o_pixel_out_ena  <= '1';
               end if;
            end if;
            
         end if;
            
      end if;
   end process;
  
  
end architecture arch;