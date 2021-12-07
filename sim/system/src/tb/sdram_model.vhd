library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library tb;
use tb.globals.all;

entity sdram_model is
   generic
   (
      DOREFRESH         : std_logic := '0';
      INITFILE          : string := "NONE";
      SCRIPTLOADING     : std_logic := '0';
      FILELOADING       : std_logic := '0'
   );
   port 
   (
      clk               : in  std_logic;
      refresh           : in  std_logic;
      addr              : in  std_logic_vector(26 downto 0);
      req               : in  std_logic;
      ram_128           : in  std_logic;
      rnw               : in  std_logic;
      be                : in  std_logic_vector(3 downto 0);
      di                : in  std_logic_vector(31 downto 0);
      do                : out std_logic_vector(127 downto 0);
      done              : out std_logic := '0';
      reqprocessed      : out std_logic := '0';
      ram_idle          : out std_logic := '0';
      fileSize          : out unsigned(29 downto 0) := (others => '0')
   );
end entity;

architecture arch of sdram_model is

   -- not full size, because of memory required
   type t_data is array(0 to (2**27)-1) of integer;
   type bit_vector_file is file of bit_vector;
   
   signal waitrfs    : integer range 0 to 8 := 0;
   signal waitcnt    : integer range 0 to 8 := 0;
   
   signal req_buffer  : std_logic := '0';
   signal addr_buffer : std_logic_vector(26 downto 0);
   
   signal refreshcnt  : integer range 0 to 260 := 0;
   
   signal initFromFile : std_logic := '1';
   
begin

   process
   
      variable data           : t_data := (others => 0);
      variable bs93           : std_logic;
      
      file infile             : bit_vector_file;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte      : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (0 downto 0);
      variable actual_len     : natural;
      variable targetpos      : integer;
      variable loadcount      : integer;
      
      variable addr_rotate    : std_logic_vector(26 downto 0);
      
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
      
      done         <= '0';
      reqprocessed <= '0';
      
      if (req = '1') then
         req_buffer <= '1';
      end if;
      
      ram_idle <= '1';
      
      if (DOREFRESH = '1' and refreshcnt < 260) then
         refreshcnt <= refreshcnt + 1;
      end if;
      
      if (waitcnt > 0) then
         ram_idle <= '0';
         waitcnt <= waitcnt - 1;
         if (waitcnt = 1) then
            if (rnw = '1') then
               addr_rotate := addr_buffer;
               for i in 0 to 7 loop
                  do(7  + (i * 16) downto     (i * 16))  <= std_logic_vector(to_unsigned(data(to_integer(unsigned(addr_rotate(26 downto 1)) & '0') + 0), 8));
                  do(15 + (i * 16) downto 8 + (i * 16))  <= std_logic_vector(to_unsigned(data(to_integer(unsigned(addr_rotate(26 downto 1)) & '0') + 1), 8));
                  addr_rotate(3 downto 1) := std_logic_vector(unsigned(addr_rotate(3 downto 1)) + 1); 
               end loop;
            end if;
            done <= '1';
            if (DOREFRESH = '1' and refreshcnt >= 260) then
               refreshcnt <= 0;
               waitrfs    <= 2;
            end if;
         end if;
      elsif (waitrfs > 0) then
         waitrfs  <= waitrfs - 1;
         ram_idle <= '0';
      elsif (refresh = '1') then
         waitrfs    <= 1;
         refreshcnt <= 0;
      elsif (DOREFRESH = '1' and refreshcnt >= 260) then
         refreshcnt <= 0;
         waitrfs    <= 2;
      elsif ((req = '1' or req_buffer = '1') and rnw = '0') then
         ram_idle <= '0';
         if (be(3) = '1') then data(to_integer(unsigned(addr(26 downto 1)) & '0') + 3) := to_integer(unsigned(di(31 downto 24))); end if;
         if (be(2) = '1') then data(to_integer(unsigned(addr(26 downto 1)) & '0') + 2) := to_integer(unsigned(di(23 downto 16))); end if;
         if (be(1) = '1') then data(to_integer(unsigned(addr(26 downto 1)) & '0') + 1) := to_integer(unsigned(di(15 downto  8))); end if;
         if (be(0) = '1') then data(to_integer(unsigned(addr(26 downto 1)) & '0') + 0) := to_integer(unsigned(di( 7 downto  0))); end if;
         waitcnt    <= 1;
         req_buffer <= '0';
      elsif ((req = '1' or req_buffer = '1') and rnw = '1') then
         ram_idle     <= '0';
         do           <= (others => 'X');
         if (ram_128 = '1') then
            if (req_buffer = '1') then
               waitcnt      <= 3;
            else
               waitcnt      <= 4;
            end if;
            if (refreshcnt >= 260) then
               refreshcnt <= 0;
               waitcnt    <= 6;
            end if;
         else
            if (req_buffer = '1') then
               waitcnt      <= 1;
            else
               waitcnt      <= 2;
            end if;
         end if;
         reqprocessed <= '1';
         req_buffer   <= '0';
         addr_buffer  <= addr;
      end if;

      if (SCRIPTLOADING = '1') then
         COMMAND_FILE_ACK_1 <= '0';
         if COMMAND_FILE_START_1 = '1' then
            
            assert false report "received" severity note;
            assert false report COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN) severity note;
         
            file_open(f_status, infile, COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN), read_mode);
         
            targetpos := COMMAND_FILE_TARGET;
            
            wait until rising_edge(clk);
            
            for i in 1 to COMMAND_FILE_OFFSET loop
               read(infile, next_vector, actual_len); 
            end loop;
            
            loadcount := 0;
      
            while (not endfile(infile) and (COMMAND_FILE_SIZE = 0 or loadcount < COMMAND_FILE_SIZE)) loop
               
               read(infile, next_vector, actual_len);  
               
               read_byte := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
               
               --report "read_byte=" & integer'image(to_integer(unsigned(read_byte)));
               
               data(targetpos) := to_integer(unsigned(read_byte));
               targetpos       := targetpos + 1;
               loadcount       := loadcount + 1;
               
            end loop;
            
            wait until rising_edge(clk);
         
            file_close(infile);
         
            COMMAND_FILE_ACK_1 <= '1';
         
         end if;
      end if;
      
      if (FILELOADING = '1') then
         if (initFromFile = '1') then
            initFromFile <= '0';
            file_open(f_status, infile, INITFILE, read_mode);
            targetpos := 0;
            while (not endfile(infile)) loop
               read(infile, next_vector, actual_len);  
               read_byte := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
               data(targetpos) := to_integer(unsigned(read_byte));
               targetpos       := targetpos + 1;
            end loop;
            fileSize <= to_unsigned(targetpos, 30);
            file_close(infile);
         end if;
      end if;
   
   
   end process;
   
end architecture;


