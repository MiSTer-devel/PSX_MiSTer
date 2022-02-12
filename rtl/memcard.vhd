library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity memcard is
   port 
   (
      clk2x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      save                 : in  std_logic;
      load                 : in  std_logic;
      
      pause                : out std_logic := '0';
      system_paused        : in  std_logic;
      
      mounted              : in  std_logic;
      anyChange            : in  std_logic;
      
      changePending        : out std_logic;
      
      mem_request          : out std_logic := '0';
      mem_BURSTCNT         : out std_logic_vector(7 downto 0) := (others => '0'); 
      mem_ADDR             : out std_logic_vector(19 downto 0) := (others => '0');                       
      mem_DIN              : out std_logic_vector(63 downto 0) := (others => '0');
      mem_BE               : out std_logic_vector(7 downto 0) := (others => '0'); 
      mem_WE               : out std_logic := '0';
      mem_RD               : out std_logic := '0';
      mem_ack              : in  std_logic;
      mem_DOUT             : in  std_logic_vector(63 downto 0);
      mem_DOUT_READY       : in  std_logic;

      memcard_rd           : out std_logic := '0';
      memcard_wr           : out std_logic := '0';
      memcard_lba          : out std_logic_vector(6 downto 0);
      memcard_ack          : in  std_logic;
      memcard_write        : in  std_logic;
      memcard_addr         : in  std_logic_vector(8 downto 0);
      memcard_dataIn       : in  std_logic_vector(15 downto 0);
      memcard_dataOut      : out std_logic_vector(15 downto 0)
   );
end entity;

architecture arch of memcard is
   
   type tState is
   (
      IDLE,
      
      LOAD_WAITPAUSED,
      LOAD_REQREAD,
      LOAD_WAITACKSTART,
      LOAD_WAITACKDONE,
      LOAD_READDATA,
      LOAD_REQWRITE,
      LOAD_WAITACK,
      
      SAVE_WAITPAUSED,
      SAVE_REQDATA,
      SAVE_WAITACK,
      SAVE_READDATA,
      SAVE_REQWRITE,
      SAVE_WAITACKSTART,
      SAVE_WAITACKDONE
   );
   signal state         : tState := IDLE;
  
   signal loadLatched   : std_logic := '0';
   signal saveLatched   : std_logic := '0';
  
   signal anyChangeBuf  : std_logic := '0';
  
   signal readCnt       : std_logic_vector(6 downto 0);   
   signal blockCnt      : unsigned(6 downto 0);   
  
   -- memory
   signal mem_addrA     : std_logic_vector(6 downto 0) := (others => '0');
   signal mem_DataInA   : std_logic_vector(63 downto 0);
   signal mem_wrenA     : std_logic := '0';
   signal mem_DataOutA  : std_logic_vector(63 downto 0);

begin 

   changePending <= anyChangeBuf;
  
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         mem_wrenA      <= '0';  
         
         if (memcard_ack = '1') then
            memcard_rd <= '0';
            memcard_wr <= '0';
         end if;

         if (load = '1') then loadLatched <= '1'; end if;
         if (save = '1') then saveLatched <= '1'; end if;

         if (anyChange = '1') then anyChangeBuf <= '1'; end if;

         if (reset = '1') then
         
            state       <= IDLE;
            memcard_rd  <= '0';
            memcard_wr  <= '0';            
            
            pause        <= '0';

         else
         
            case (state) is
               when IDLE => 
                  if (loadLatched = '1' and mounted = '1') then
                     state        <= LOAD_WAITPAUSED;
                     pause        <= '1';
                     loadLatched  <= '0';
                     anyChangeBuf <= '0';
                  elsif (saveLatched = '1') then
                     if (anyChangeBuf = '1') then
                        state        <= SAVE_WAITPAUSED;
                        pause        <= '1';
                        anyChangeBuf <= '0';
                     end if;
                     saveLatched  <= '0';
                  end if;
               
               -- loading
               when LOAD_WAITPAUSED =>
                  if (system_paused = '1') then
                     state     <= LOAD_REQREAD;
                     blockCnt  <= (others => '0');
                  end if;
                  
               when LOAD_REQREAD =>
                  state <= LOAD_WAITACKSTART;
                  memcard_lba <= std_logic_vector(blockCnt);
                  memcard_rd  <= '1';
                  
               when LOAD_WAITACKSTART =>
                  if (memcard_ack = '1') then
                     state <= LOAD_WAITACKDONE;
                  end if;
                  
               when LOAD_WAITACKDONE =>
                  mem_addrA <= (others => '0');
                  if (memcard_ack = '0') then
                     state <= LOAD_READDATA;
                  end if;
               
               when LOAD_READDATA =>
                  state <= LOAD_REQWRITE;
            
               when LOAD_REQWRITE =>
                  state        <= LOAD_WAITACK;
                  mem_request  <= '1';
                  mem_BURSTCNT <= x"01";
                  mem_ADDR     <= "000" & std_logic_vector(blockCnt) & mem_addrA & "000";
                  mem_DIN      <= mem_DataOutA;
                  mem_BE       <= x"FF";
                  mem_WE       <= '1';
                  mem_RD       <= '0';
                  
               when LOAD_WAITACK =>
                  if (mem_ack = '1') then
                     mem_request <= '0';
                     if (unsigned(mem_addrA) = 127) then
                        if (blockCnt = 127) then
                           state <= IDLE;
                           pause <= '0';
                        else
                           blockCnt <= blockCnt + 1;
                           state    <= LOAD_REQREAD;
                        end if;
                     else
                        mem_addrA <= std_logic_vector(unsigned(mem_addrA) + 1);
                        state     <= LOAD_READDATA;
                     end if;
                  end if;
                  
               -- saving
               when SAVE_WAITPAUSED =>
                  if (system_paused = '1') then
                     state    <= SAVE_REQDATA;
                     blockCnt <= (others => '0');
                  end if;
               
               when SAVE_REQDATA =>
                  state        <= SAVE_WAITACK;
                  mem_request  <= '1';
                  mem_BURSTCNT <= x"80";
                  mem_ADDR     <= "000" & std_logic_vector(blockCnt) & "0000000" & "000";
                  mem_BE       <= x"FF";
                  mem_WE       <= '0';
                  mem_RD       <= '1';
               
               when SAVE_WAITACK =>
                  if (mem_ack = '1') then
                     state     <= SAVE_READDATA;
                     readCnt   <= (others => '0');
                  end if;
                  
               when SAVE_READDATA =>
                  if (mem_DOUT_READY = '1') then
                  
                     mem_addrA   <= readCnt;
                     mem_DataInA <= mem_DOUT;
                     mem_wrenA   <= '1';
                  
                     if (unsigned(readCnt) = 127) then
                        state       <= SAVE_REQWRITE;
                        mem_request <= '0';
                     else 
                        readCnt <= std_logic_vector(unsigned(readCnt) + 1);
                     end if;
                  end if;
                  
               when SAVE_REQWRITE =>
                  state <= SAVE_WAITACKSTART;
                  memcard_lba <= std_logic_vector(blockCnt);
                  memcard_wr  <= '1';
                 
               when SAVE_WAITACKSTART =>
                  if (memcard_ack = '1') then 
                     state <= SAVE_WAITACKDONE;
                  end if;
                  
               when SAVE_WAITACKDONE =>
                  mem_addrA <= (others => '0');
                  if (memcard_ack = '0') then 
                     if (blockCnt = 127) then
                        state <= IDLE;
                        pause <= '0';
                     else
                        blockCnt <= blockCnt + 1;
                        state    <= SAVE_REQDATA;
                     end if;
                  end if;
              
            end case;
            
         end if;
         
      end if;
   end process;
   
   iramSectorBuffer: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 7,
      data_width_a  => 64,
      addr_width_b  => 9,
      data_width_b  => 16
   )
   port map
   (
      clock       => clk2x,
      
      address_a   => mem_addrA,
      data_a      => mem_DataInA,
      wren_a      => mem_wrenA,
      q_a         => mem_DataOutA,
      
      address_b   => memcard_addr,                    
      data_b      => memcard_dataIn,                  
      wren_b      => (memcard_write and memcard_ack),
      q_b         => memcard_dataOut
   );
   
end architecture;





