library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity spu_gauss is
   port 
   (
      clk1x                : in  std_logic;
      
      interpolIndex        : in  unsigned(7 downto 0);
      
      gauss1               : out signed(15 downto 0);
      gauss2               : out signed(15 downto 0);
      gauss3               : out signed(15 downto 0);
      gauss4               : out signed(15 downto 0)
   );
end entity;

architecture arch of spu_gauss is

   type tGauss is array(0 to 511) of signed(15 downto 0);
   constant gauss : tGauss :=
	(
	  -x"0001",-x"0001",-x"0001",-x"0001",-x"0001",-x"0001",-x"0001",-x"0001",
	  -x"0001",-x"0001",-x"0001",-x"0001",-x"0001",-x"0001",-x"0001",-x"0001",
		x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0001",
		x"0001", x"0001", x"0001", x"0002", x"0002", x"0002", x"0003", x"0003",
		x"0003", x"0004", x"0004", x"0005", x"0005", x"0006", x"0007", x"0007",
		x"0008", x"0009", x"0009", x"000A", x"000B", x"000C", x"000D", x"000E",
		x"000F", x"0010", x"0011", x"0012", x"0013", x"0015", x"0016", x"0018",
		x"0019", x"001B", x"001C", x"001E", x"0020", x"0021", x"0023", x"0025",
		x"0027", x"0029", x"002C", x"002E", x"0030", x"0033", x"0035", x"0038",
		x"003A", x"003D", x"0040", x"0043", x"0046", x"0049", x"004D", x"0050",
		x"0054", x"0057", x"005B", x"005F", x"0063", x"0067", x"006B", x"006F",
		x"0074", x"0078", x"007D", x"0082", x"0087", x"008C", x"0091", x"0096",
		x"009C", x"00A1", x"00A7", x"00AD", x"00B3", x"00BA", x"00C0", x"00C7",
		x"00CD", x"00D4", x"00DB", x"00E3", x"00EA", x"00F2", x"00FA", x"0101",
		x"010A", x"0112", x"011B", x"0123", x"012C", x"0135", x"013F", x"0148",
		x"0152", x"015C", x"0166", x"0171", x"017B", x"0186", x"0191", x"019C",
		x"01A8", x"01B4", x"01C0", x"01CC", x"01D9", x"01E5", x"01F2", x"0200",
		x"020D", x"021B", x"0229", x"0237", x"0246", x"0255", x"0264", x"0273",
		x"0283", x"0293", x"02A3", x"02B4", x"02C4", x"02D6", x"02E7", x"02F9",
		x"030B", x"031D", x"0330", x"0343", x"0356", x"036A", x"037E", x"0392",
		x"03A7", x"03BC", x"03D1", x"03E7", x"03FC", x"0413", x"042A", x"0441",
		x"0458", x"0470", x"0488", x"04A0", x"04B9", x"04D2", x"04EC", x"0506",
		x"0520", x"053B", x"0556", x"0572", x"058E", x"05AA", x"05C7", x"05E4",
		x"0601", x"061F", x"063E", x"065C", x"067C", x"069B", x"06BB", x"06DC",
		x"06FD", x"071E", x"0740", x"0762", x"0784", x"07A7", x"07CB", x"07EF",
		x"0813", x"0838", x"085D", x"0883", x"08A9", x"08D0", x"08F7", x"091E",
		x"0946", x"096F", x"0998", x"09C1", x"09EB", x"0A16", x"0A40", x"0A6C",
		x"0A98", x"0AC4", x"0AF1", x"0B1E", x"0B4C", x"0B7A", x"0BA9", x"0BD8",
		x"0C07", x"0C38", x"0C68", x"0C99", x"0CCB", x"0CFD", x"0D30", x"0D63",
		x"0D97", x"0DCB", x"0E00", x"0E35", x"0E6B", x"0EA1", x"0ED7", x"0F0F",
		x"0F46", x"0F7F", x"0FB7", x"0FF1", x"102A", x"1065", x"109F", x"10DB",
		x"1116", x"1153", x"118F", x"11CD", x"120B", x"1249", x"1288", x"12C7",
		x"1307", x"1347", x"1388", x"13C9", x"140B", x"144D", x"1490", x"14D4",
		x"1517", x"155C", x"15A0", x"15E6", x"162C", x"1672", x"16B9", x"1700",
		x"1747", x"1790", x"17D8", x"1821", x"186B", x"18B5", x"1900", x"194B",
		x"1996", x"19E2", x"1A2E", x"1A7B", x"1AC8", x"1B16", x"1B64", x"1BB3",
		x"1C02", x"1C51", x"1CA1", x"1CF1", x"1D42", x"1D93", x"1DE5", x"1E37",
		x"1E89", x"1EDC", x"1F2F", x"1F82", x"1FD6", x"202A", x"207F", x"20D4",
		x"2129", x"217F", x"21D5", x"222C", x"2282", x"22DA", x"2331", x"2389",
		x"23E1", x"2439", x"2492", x"24EB", x"2545", x"259E", x"25F8", x"2653",
		x"26AD", x"2708", x"2763", x"27BE", x"281A", x"2876", x"28D2", x"292E",
		x"298B", x"29E7", x"2A44", x"2AA1", x"2AFF", x"2B5C", x"2BBA", x"2C18",
		x"2C76", x"2CD4", x"2D33", x"2D91", x"2DF0", x"2E4F", x"2EAE", x"2F0D",
		x"2F6C", x"2FCC", x"302B", x"308B", x"30EA", x"314A", x"31AA", x"3209",
		x"3269", x"32C9", x"3329", x"3389", x"33E9", x"3449", x"34A9", x"3509",
		x"3569", x"35C9", x"3629", x"3689", x"36E8", x"3748", x"37A8", x"3807",
		x"3867", x"38C6", x"3926", x"3985", x"39E4", x"3A43", x"3AA2", x"3B00",
		x"3B5F", x"3BBD", x"3C1B", x"3C79", x"3CD7", x"3D35", x"3D92", x"3DEF",
		x"3E4C", x"3EA9", x"3F05", x"3F62", x"3FBD", x"4019", x"4074", x"40D0",
		x"412A", x"4185", x"41DF", x"4239", x"4292", x"42EB", x"4344", x"439C",
		x"43F4", x"444C", x"44A3", x"44FA", x"4550", x"45A6", x"45FC", x"4651",
		x"46A6", x"46FA", x"474E", x"47A1", x"47F4", x"4846", x"4898", x"48E9",
		x"493A", x"498A", x"49D9", x"4A29", x"4A77", x"4AC5", x"4B13", x"4B5F",
		x"4BAC", x"4BF7", x"4C42", x"4C8D", x"4CD7", x"4D20", x"4D68", x"4DB0",
		x"4DF7", x"4E3E", x"4E84", x"4EC9", x"4F0E", x"4F52", x"4F95", x"4FD7",
		x"5019", x"505A", x"509A", x"50DA", x"5118", x"5156", x"5194", x"51D0",
		x"520C", x"5247", x"5281", x"52BA", x"52F3", x"532A", x"5361", x"5397",
		x"53CC", x"5401", x"5434", x"5467", x"5499", x"54CA", x"54FA", x"5529",
		x"5558", x"5585", x"55B2", x"55DE", x"5609", x"5632", x"565B", x"5684",
		x"56AB", x"56D1", x"56F6", x"571B", x"573E", x"5761", x"5782", x"57A3",
		x"57C3", x"57E2", x"57FF", x"581C", x"5838", x"5853", x"586D", x"5886",
		x"589E", x"58B5", x"58CB", x"58E0", x"58F4", x"5907", x"5919", x"592A",
		x"593A", x"5949", x"5958", x"5965", x"5971", x"597C", x"5986", x"598F",
		x"5997", x"599E", x"59A4", x"59A9", x"59AD", x"59B0", x"59B2", x"59B3" 
	);
   
   signal readindex : unsigned(1 downto 0) := (others => '0');
  
   signal readval  : signed(15 downto 0);

  
begin 

   process(clk1x) 
      variable readaddr : integer range 0 to 511;
   begin
      if (rising_edge(clk1x)) then
        
         readindex <= readindex + 1;
         
         readaddr := 0 + to_integer(interpolIndex); -- default for "11"
         
         case (readindex) is
            when "00" => readaddr := 255 - to_integer(interpolIndex); gauss4 <= readval;
            when "01" => readaddr := 511 - to_integer(interpolIndex); gauss1 <= readval;
            when "10" => readaddr := 256 + to_integer(interpolIndex); gauss2 <= readval;
            when "11" => readaddr :=   0 + to_integer(interpolIndex); gauss3 <= readval;
            when others => null;
         end case;
         
         readval <= gauss(readaddr);
         
      end if;
   end process;

end architecture;





