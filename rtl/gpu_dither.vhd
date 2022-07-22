library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  
 
entity gpu_dither is
   generic
   (
      img_width       : integer := 1024;
      color_width     : integer := 8;
      reduced_width   : integer := 6
   );
   port 
   (
      clk       : in  std_logic;
      ce        : in  std_logic;
 
      x         : in  integer range 0 to img_width-1;
      firstLine : in  std_logic;
 
      din_r     : in  std_logic_vector(color_width-1 downto 0);
      din_g     : in  std_logic_vector(color_width-1 downto 0);
      din_b     : in  std_logic_vector(color_width-1 downto 0);
 
      dout_r    : out std_logic_vector(color_width-1 downto 0) := (others => '0');
      dout_g    : out std_logic_vector(color_width-1 downto 0) := (others => '0');
      dout_b    : out std_logic_vector(color_width-1 downto 0) := (others => '0')
   );
end entity;
 
architecture arch of gpu_dither is
 
   constant dither_bits  : integer := color_width - reduced_width;
   constant dither_bits1 : integer := dither_bits + 1;
 
   type t_dither_rgb is array(1 to 3) of unsigned(dither_bits-1 downto 0);
   signal dither_buffer_next : t_dither_rgb := (others => (others =>'0'));
   signal dither_buffer_newline : t_dither_rgb := (others => (others =>'0'));
   
   type t_dither_rgb1 is array(1 to 3) of std_logic_vector(dither_bits1-1 downto 0);
   signal dither_buffer_toRam : t_dither_rgb1 := (others => (others =>'0'));
   signal dither_buffer_fromRam : t_dither_rgb1 := (others => (others =>'0'));
 
   signal index : integer range 0 to img_width-1 := 0;
   signal AddrA : integer range 0 to img_width-1 := 0;
   signal WEA   : std_logic := '0';
   signal dataB : std_logic_vector((dither_bits1*3) - 1 downto 0);
 
begin

   ilineram: entity work.dpram
   generic map ( addr_width => 10, data_width => dither_bits1 * 3)
   port map
   (
      clock_a     => clk,
      address_a   => std_logic_vector(to_unsigned(AddrA, 10)),
      data_a      => dither_buffer_toRam(1) & dither_buffer_toRam(2) & dither_buffer_toRam(3),
      wren_a      => WEA,
      
      clock_b     => clk,
      address_b   => std_logic_vector(to_unsigned(x, 10)),
      data_b      => ((dither_bits1 * 3) - 1 downto 0 => '0'),
      wren_b      => '0',
      q_b         => dataB
   );
   
   dither_buffer_fromRam(1) <= dataB((dither_bits1 * 3)-1 downto (dither_bits1 * 2));
   dither_buffer_fromRam(2) <= dataB((dither_bits1 * 2)-1 downto dither_bits1);
   dither_buffer_fromRam(3) <= dataB(dither_bits1-1 downto 0);
 
   process (clk)
      type t_intermediate is array(1 to 3) of unsigned(color_width downto 0);
      variable intermediate_color : t_intermediate;
   begin
      if rising_edge(clk) then
      
         WEA <= '0';
      
         if (ce = '1') then
 
            intermediate_color(1) := ("0" & unsigned(din_r));
            intermediate_color(2) := ("0" & unsigned(din_g));
            intermediate_color(3) := ("0" & unsigned(din_b));
            
            if (x > 0) then
               intermediate_color(1) := intermediate_color(1) + dither_buffer_next(1);
               intermediate_color(2) := intermediate_color(2) + dither_buffer_next(2);
               intermediate_color(3) := intermediate_color(3) + dither_buffer_next(3);
            end if;
            
            if (firstLine = '0') then
               intermediate_color(1) := intermediate_color(1) + unsigned(dither_buffer_fromRam(1));
               intermediate_color(2) := intermediate_color(2) + unsigned(dither_buffer_fromRam(2));
               intermediate_color(3) := intermediate_color(3) + unsigned(dither_buffer_fromRam(3));
            end if;
   
            for c in 1 to 3 loop
   
               if (intermediate_color(c)(8) = '1') then intermediate_color(c) := '0' & to_unsigned((2**color_width) - 1, color_width); end if;
   
               dither_buffer_next(c) <= "0" & intermediate_color(c)(dither_bits-2 downto 0); 
               dither_buffer_newline(c) <= intermediate_color(c)(dither_bits-1 downto 0);
               dither_buffer_toRam(c) <= std_logic_vector(('0' & intermediate_color(c)(dither_bits-1 downto 0)) + dither_buffer_newline(c));
            end loop; 

            index <= x;
            AddrA <= index;
            WEA <= '1';
   
            dout_r <= std_logic_vector(intermediate_color(1)(color_width-1 downto 0));
            dout_g <= std_logic_vector(intermediate_color(2)(color_width-1 downto 0));
            dout_b <= std_logic_vector(intermediate_color(3)(color_width-1 downto 0));
            
         end if;
 
      end if;
   end process;
 
 
end architecture;