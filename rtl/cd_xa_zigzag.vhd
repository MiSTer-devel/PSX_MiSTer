library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity cd_xa_zigzag is
   port 
   (
      clk1x  : in  std_logic;
      addr   : in  unsigned(7 downto 0);
      data   : out signed(15 downto 0)
   );
end entity;

architecture arch of cd_xa_zigzag is

   type tzigzagTable is array(0 to 255) of signed(15 downto 0); -- only 7 * 29 used
   constant zigzagTable : tzigzagTable := 
	(
		x"0000",x"0000",x"0000",x"0000",x"0000",x"fffe",x"000a",x"ffde",x"0041",x"ffac",x"0034",x"0009",x"fef6",x"0400",x"f588",x"234c",x"6794",x"e880",x"0bcd",x"f9dd",x"0350",x"fe93",x"006b",x"000a",x"fff0",x"0011",x"fff8",x"0003",x"ffff",x"0000",x"0000",x"0000",
		x"0000",x"0000",x"0000",x"fffe",x"0000",x"0003",x"ffed",x"003c",x"ffb5",x"00a2",x"ff1d",x"0132",x"ffbd",x"fd99",x"0c9d",x"74bb",x"ee4c",x"09b8",x"fa41",x"0372",x"fe58",x"00a6",x"ffe5",x"0005",x"0006",x"fff8",x"0003",x"ffff",x"0000",x"0000",x"0000",x"0000",
		x"0000",x"0000",x"ffff",x"0003",x"fffe",x"fffb",x"001f",x"ffb6",x"00b3",x"fe6e",x"02b1",x"fc62",x"04f8",x"fa5a",x"7939",x"fa5a",x"04f8",x"fc62",x"02b1",x"fe6e",x"00b3",x"ffb6",x"001f",x"fffb",x"fffe",x"0003",x"ffff",x"0000",x"0000",x"0000",x"0000",x"0000",
		x"0000",x"ffff",x"0003",x"fff8",x"0006",x"0005",x"ffe5",x"00a6",x"fe58",x"0372",x"fa41",x"09b8",x"ee4c",x"74bb",x"0c9d",x"fd99",x"ffbd",x"0132",x"ff1d",x"00a2",x"ffb5",x"003c",x"ffed",x"0003",x"0000",x"fffe",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
		x"ffff",x"0003",x"fff8",x"0011",x"fff0",x"000a",x"006b",x"fe93",x"0350",x"f9dd",x"0bcd",x"e880",x"6794",x"234c",x"f588",x"0400",x"fef6",x"0009",x"0034",x"ffac",x"0041",x"ffde",x"000a",x"ffff",x"0000",x"0001",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
		x"0002",x"fff8",x"0010",x"ffdd",x"002b",x"001a",x"ff15",x"027b",x"fab8",x"0afa",x"e906",x"53e0",x"3c07",x"edb7",x"080e",x"fcb9",x"015b",x"ffbc",x"ffe9",x"0046",x"ffdd",x"0011",x"fffb",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
		x"fffb",x"0011",x"ffdd",x"0046",x"ffe9",x"ffbc",x"015b",x"fcb9",x"080e",x"edb7",x"3c07",x"53e0",x"e906",x"0afa",x"fab8",x"027b",x"ff15",x"001a",x"002b",x"ffdd",x"0010",x"fff8",x"0002",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
      x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000"
   );
  
begin 

   process(clk1x) 
   begin
      if (rising_edge(clk1x)) then
         
         data <= zigzagTable(to_integer(addr));
         
      end if;
   end process;

end architecture;





