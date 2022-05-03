library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity tb_savestates is
   generic
   (
      SAVETYPESCOUNT    : integer := 17;
      LOADSTATE         : std_logic := '0';
      FILENAME          : string := "NONE"
   );
   port 
   (
      clk               : in  std_logic;
      reset_in          : in  std_logic;
      reset_out         : out std_logic := '0';
      loading_savestate : out std_logic := '0';
      SS_reset          : out std_logic := '0';
      SS_DataWrite      : out std_logic_vector(31 downto 0) := (others => '0');
      SS_Adr            : out unsigned(18 downto 0) := (others => '0');
      SS_wren           : out std_logic_vector(SAVETYPESCOUNT - 1 downto 0) := (others => '0')
   );
end entity;

architecture arch of tb_savestates is

   type t_data is array(0 to (2**22)-1) of integer;
   type bit_vector_file is file of bit_vector;
   signal initFromFile : std_logic := '1';
   
   signal savetype_counter : integer range 0 to SAVETYPESCOUNT;
   type tsavetype is record
      offset      : integer;
      size        : integer;
   end record;
   type t_savetypes is array(0 to SAVETYPESCOUNT - 1) of tsavetype;
   constant savetypes : t_savetypes := 
   (
      (  1024,   128),    -- CPU          0 
      (  2048,     8),    -- GPU          1 
      (  3072,     8),    -- GPUTiming    2 
      (  4096,    64),    -- DMA          3 
      (  5120,    64),    -- GTE          4 
      (  6144,     8),    -- Joypad       5 
      (  7168,   128),    -- MDEC         6 
      (  8192,    16),    -- Memory       7 
      (  9216,    16),    -- Timer        8 
      ( 10240,   512),    -- Sound        9 
      ( 11264,     2),    -- IRQ          10
      ( 12288,     8),    -- SIO          11
      ( 31744,   256),    -- Scratchpad   12   
      ( 32768, 16384),    -- CDROM        13
      (131072,131072),    -- SPURAM       14
      (262144,262144),    -- VRAM         15
      (524288,524288)     -- RAM          16
   );
   
   signal transfered : std_logic := '0';
   
begin

   process
   
      variable data           : t_data := (others => 0);
      file infile             : bit_vector_file;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte      : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (0 downto 0);
      variable actual_len     : natural;
      variable targetpos      : integer;
      
      -- copy from std_logic_arith, not used here because numeric std is also included
      function CONV_STD_LOGIC_VECTOR(ARG: INTEGER; SIZE: INTEGER) return STD_LOGIC_VECTOR is
        variable result: STD_LOGIC_VECTOR (SIZE-1 downto 0);
        variable temp: integer;
      begin
 
         temp := ARG;
         for i in 0 to SIZE-1 loop
 
         if (temp mod 2) = 1 then
            result(i) := '1';
         else 
            result(i) := '0';
         end if;
 
         if temp > 0 then
            temp := temp / 2;
         elsif (temp > integer'low) then
            temp := (temp - 1) / 2; -- simulate ASR
         else
            temp := temp / 2; -- simulate ASR
         end if;
        end loop;
 
        return result;  
      end;
   
   begin
      wait until rising_edge(clk);
      
      if (reset_in = '0' and transfered = '0') then
      
         SS_reset <= '1';
         wait until rising_edge(clk);
         SS_reset <= '0';
         wait until rising_edge(clk);
         
         loading_savestate <= '1';
      
         if (LOADSTATE = '1') then

            for savetype in 0 to 13 loop
               for i in 0 to (savetypes(savetype).size - 1) loop
                  SS_DataWrite( 7 downto  0) <= std_logic_vector(to_unsigned(data((savetypes(savetype).offset + i) * 4 + 0), 8));
                  SS_DataWrite(15 downto  8) <= std_logic_vector(to_unsigned(data((savetypes(savetype).offset + i) * 4 + 1), 8));
                  SS_DataWrite(23 downto 16) <= std_logic_vector(to_unsigned(data((savetypes(savetype).offset + i) * 4 + 2), 8));
                  SS_DataWrite(31 downto 24) <= std_logic_vector(to_unsigned(data((savetypes(savetype).offset + i) * 4 + 3), 8));
                  SS_wren(savetype) <= '1';
                  SS_Adr            <= to_unsigned(i, 19);
                  wait until rising_edge(clk);
                  SS_wren(savetype) <= '0';
               end loop;
            end loop;
            
            -- special handling for SPU ram
            for i in 0 to (savetypes(14).size - 1) loop
               SS_DataWrite( 7 downto  0) <= std_logic_vector(to_unsigned(data((savetypes(14).offset + i) * 4 + 0), 8));
               SS_DataWrite(15 downto  8) <= std_logic_vector(to_unsigned(data((savetypes(14).offset + i) * 4 + 1), 8));
               SS_wren(14) <= '1';
               SS_Adr      <= to_unsigned(i * 4 + 0, 19);
               wait until rising_edge(clk);
               SS_wren(14) <= '0';
               wait until rising_edge(clk);
               
               SS_DataWrite( 7 downto  0) <= std_logic_vector(to_unsigned(data((savetypes(14).offset + i) * 4 + 2), 8));
               SS_DataWrite(15 downto  8) <= std_logic_vector(to_unsigned(data((savetypes(14).offset + i) * 4 + 3), 8));
               SS_wren(14) <= '1';
               SS_Adr      <= to_unsigned(i * 4 + 2, 19);
               wait until rising_edge(clk);
               SS_wren(14) <= '0';
               wait until rising_edge(clk);
            end loop;
            
         end if;
            
         transfered <= '1';
         reset_out <= '1';
         wait until rising_edge(clk);
         reset_out <= '0';
         loading_savestate <= '0';
         wait until rising_edge(clk);
      end if;

      if (initFromFile = '1' and LOADSTATE = '1') then
         initFromFile <= '0';
         file_open(f_status, infile, FILENAME, read_mode);
         targetpos := 0;
         while (not endfile(infile)) loop
            read(infile, next_vector, actual_len);  
            read_byte := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
            data(targetpos) := to_integer(unsigned(read_byte));
            targetpos       := targetpos + 1;
         end loop;
         file_close(infile);
      end if;
   
   end process;
   
end architecture;


