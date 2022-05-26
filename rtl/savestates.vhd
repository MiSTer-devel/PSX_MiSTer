library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity savestates is
   generic 
   (
      FASTSIM        : std_logic;
      SAVETYPESCOUNT : integer := 17
   );
   port 
   (
      clk1x                   : in  std_logic;  
      clk2x                   : in  std_logic;  
      clk2xIndex              : in  std_logic;  
      ce                      : in  std_logic;  
      reset_in                : in  std_logic;
      reset_out               : out std_logic := '0';
      ss_reset                : out std_logic := '0';
         
      loadExe                 : in  std_logic;
         
      load_done               : out std_logic := '0';
            
      increaseSSHeaderCount   : in  std_logic;  
      save                    : in  std_logic;  
      load                    : in  std_logic;
      savestate_address       : in  integer;
      savestate_busy          : out std_logic;

      SS_idle                 : in  std_logic;
      system_paused           : in  std_logic;
      savestate_pause         : out std_logic := '0';
      ddr3_savestate          : out std_logic := '0';
      
      useSPUSDRAM             : in  std_logic;
            
      SS_DataWrite            : out std_logic_vector(31 downto 0) := (others => '0');
      SS_Adr                  : out unsigned(18 downto 0) := (others => '0');
      SS_wren                 : out std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
      SS_rden                 : out std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
      SS_DataRead_CPU         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_GPU         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_GPUTiming   : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_DMA         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_GTE         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_JOYPAD      : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_MDEC        : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_MEMORY      : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_TIMER       : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_SOUND       : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_IRQ         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_SIO         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_SCP         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_CD          : in  std_logic_vector(31 downto 0) := (others => '0');

      sdram_done              : in  std_logic;
            
      loading_savestate       : out std_logic := '0';
      saving_savestate        : out std_logic := '0';
      sleep_savestate         : out std_logic := '0';
      
      ddr3_BUSY               : in  std_logic;                    
      ddr3_DOUT               : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY         : in  std_logic;
      ddr3_BURSTCNT           : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_ADDR               : out std_logic_vector(25 downto 0) := (others => '0');              
      ddr3_DIN                : out std_logic_vector(63 downto 0) := (others => '0');
      ddr3_BE                 : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_WE                 : out std_logic := '0';
      ddr3_RD                 : out std_logic := '0';
      
      ram_done                : in std_logic;
      ram_data                : in std_logic_vector(31 downto 0);
      
      SS_SPURAM_dataWrite     : out std_logic_vector(15 downto 0) := (others => '0');
      SS_SPURAM_Adr           : out std_logic_vector(18 downto 0) := (others => '0');
      SS_SPURAM_request       : out std_logic := '0';
      SS_SPURAM_rnw           : out std_logic := '0';
      SS_SPURAM_dataRead      : in  std_logic_vector(15 downto 0);
      SS_SPURAM_done          : in  std_logic
   );
end entity;

architecture arch of savestates is

   constant STATESIZE      : integer := 1048574;
   
   constant SETTLECOUNT    : integer := 4095;
   constant HEADERCOUNT    : integer := 2;
   constant INTERNALSCOUNT : integer := 63; -- not all used, room for some more
   
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
      (  8192,    32),    -- Memory       7 
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

   type tstate is
   (
      IDLE,
      SAVE_WAITPAUSE,
      SAVE_WAITIDLE,
      SAVE_WAITSETTLE,
      SAVEMEMORY_NEXT,
      SAVEMEMORY_STARTREAD,
      SAVEMEMORY_WAITREAD,
      SAVEMEMORY_LOAD_VRAM,
      SAVEMEMORY_LOAD_RAM,
      SAVEMEMORY_LOAD_SPURAM,
      SAVEMEMORY_WAIT_SPURAM,
      SAVEMEMORY_READ,
      SAVEMEMORY_WRITE,
      SAVESIZEAMOUNT,
      SAVEWAITHPSDONE,
      LOAD_WAITSETTLE,
      LOAD_HEADERAMOUNTCHECK,
      LOADMEMORY_NEXT,
      LOADMEMORY_READ,
      LOADMEMORY_WRITE,
      LOADMEMORY_WRITE_VRAM,
      LOADMEMORY_WRITE_SDRAM,
      LOADMEMORY_WRITE_SPURAM,
      LOADMEMORY_WAIT_SPURAM,
      LOADMEMORY_WRITE_NEXT
   );
   signal state : tstate := IDLE;
   
   signal count               : integer range 0 to 524288 := 0;
   signal maxcount            : integer range 0 to 524288;
               
   signal settle              : integer range 0 to SETTLECOUNT := 0;
   
   signal reset_2x            : std_logic := '0';
   signal ss_reset_2x         : std_logic := '0';
   signal load_done_2x        : std_logic := '0';
   signal loading_ss_2x       : std_logic := '0';
   
   signal SS_DataWrite_2x     : std_logic_vector(31 downto 0) := (others => '0');
   signal SS_Adr_2x           : unsigned(18 downto 0) := (others => '0');
   signal SS_wren_2x          : std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
   signal SS_rden_2x          : std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
   
   signal unstallwait         : integer range 0 to 16777215 := 0;
   
   signal ddr3_ADDR_save      : std_logic_vector(25 downto 0) := (others => '0');
   signal ddr3_DOUT_saved     : std_logic_vector(63 downto 0);
   signal dwordcounter        : integer range 0 to 1 := 0;
   signal SPUwordcounter      : integer range 0 to 3 := 0;
   signal SS_DataRead         : std_logic_vector(31 downto 0);
   signal SS_DataRead_2x      : std_logic_vector(31 downto 0);
   signal RAMAddrNext         : unsigned(18 downto 0) := (others => '0');
   signal slowcounter         : integer range 0 to 8 := 0;
   
   signal SPURAM_done2X       : std_logic := '0';
   signal SPURAM_dataRead2x   : std_logic_vector(15 downto 0);
   signal spu_din             : std_logic_vector(63 downto 0);
   
   signal header_amount       : unsigned(31 downto 0) := to_unsigned(1, 32);
   
   signal resetMode           : std_logic := '0';
   
   signal reset_in_1          : std_logic := '0';
   
   signal exeMode             : std_logic := '0';

begin 

   savestate_busy <= '0' when state = IDLE else '1';

   ddr3_BURSTCNT <= x"01";

   process (clk1x)
   begin
      if rising_edge(clk1x) then

         reset_out         <= reset_2x and (not ss_reset_2x);
         ss_reset          <= ss_reset_2x;
         load_done         <= load_done_2x;
         
         if (loading_ss_2x = '1') then
            loading_savestate <= not resetMode;
         elsif (reset_2x = '0') then
            loading_savestate <= '0';
         end if;
         
         SS_wren <= (others => '0');
         if (unsigned(SS_wren_2x) > 0) then
            SS_DataWrite <= SS_DataWrite_2x;
            SS_Adr       <= SS_Adr_2x;      
            SS_wren      <= SS_wren_2x;     
         end if;

         SS_rden <= (others => '0');
         if (unsigned(SS_rden_2x) > 0) then
            SS_Adr       <= SS_Adr_2x;      
            SS_rden      <= SS_rden_2x;     
         end if;

         case (savetype_counter) is
            when  0 => SS_DataRead <= SS_DataRead_CPU;
            when  1 => SS_DataRead <= SS_DataRead_GPU;
            when  2 => SS_DataRead <= SS_DataRead_GPUTiming;
            when  3 => SS_DataRead <= SS_DataRead_DMA;
            when  4 => SS_DataRead <= SS_DataRead_GTE;
            when  5 => SS_DataRead <= SS_DataRead_JOYPAD;
            when  6 => SS_DataRead <= SS_DataRead_MDEC;
            when  7 => SS_DataRead <= SS_DataRead_MEMORY;
            when  8 => SS_DataRead <= SS_DataRead_TIMER;
            when  9 => SS_DataRead <= SS_DataRead_SOUND;
            when 10 => SS_DataRead <= SS_DataRead_IRQ;
            when 11 => SS_DataRead <= SS_DataRead_SIO;
            when 12 => SS_DataRead <= SS_DataRead_SCP;
            when 13 => SS_DataRead <= SS_DataRead_CD;
            when 16 => SS_DataRead <= ram_data;
            when others => SS_DataRead <= (others => '0');
         end case;
         
      end if;
   end process;

   process (clk2x)
   begin
      if rising_edge(clk2x) then
   
         SS_DataRead_2x <= SS_DataRead;
   
         if (clk2xIndex = '0') then
            SS_wren_2x        <= (others => '0');
            SS_rden_2x        <= (others => '0');
            SS_SPURAM_request <= '0';
         end if;
         
         if (reset_out = '1') then
            reset_2x <= '0';
         end if;
         
         if (ss_reset = '1') then
            ss_reset_2x <= '0';
         end if;
         
         if (load_done = '1') then
            load_done_2x <= '0';
         end if;
         
         SPURAM_done2X <= '0';
         if (SS_SPURAM_done = '1') then
            SPURAM_done2X     <= '1';
            SPURAM_dataRead2x <= SS_SPURAM_dataRead;
         end if;
         
         if (ddr3_BUSY = '0') then
            ddr3_WE <= '0';
            ddr3_RD <= '0';
         end if;
         
         if (loadExe = '1') then
            exeMode <= '1';
         elsif (save = '1' or load = '1') then
            exeMode <= '0';
         end if;
         
         case state is
         
            when IDLE =>
               savestate_pause   <= '0';
               ddr3_savestate    <= '0';
               if (reset_in_1 = '1' and reset_in = '0') then
                  state                <= LOAD_WAITSETTLE;
                  resetMode            <= '1';
                  savetype_counter     <= 12;
                  settle               <= 0;
                  sleep_savestate      <= '1';
               elsif (save = '1') then
                  resetMode            <= '0';
                  savetype_counter     <= 0;
                  state                <= SAVE_WAITPAUSE;
                  header_amount        <= header_amount + 1;
               elsif (load = '1') then
                  state                <= LOAD_WAITSETTLE;
                  resetMode            <= '0';
                  savetype_counter     <= 0;
                  settle               <= 0;
                  sleep_savestate      <= '1';
               end if;
               
            -- #################
            -- SAVE
            -- #################
            
            when SAVE_WAITPAUSE =>
               if (settle < 8) then
                  settle <= settle + 1;
               else
                  savestate_pause  <= '1';
                  if (system_paused = '1') then
                     state                <= SAVE_WAITIDLE;
                     settle               <= 0;
                  end if;
               end if;
            
            when SAVE_WAITIDLE =>
               if (settle < 8) then
                  settle <= settle + 1;
               else
                  if (SS_idle = '1') then
                     state             <= SAVE_WAITSETTLE;
                     settle            <= 0;
                  else
                     state             <= SAVE_WAITPAUSE;
                     settle            <= 0;
                     savestate_pause   <= '0';
                  end if;
               end if;
            
            when SAVE_WAITSETTLE =>
               if (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               else
                  state            <= SAVEMEMORY_NEXT;
                  saving_savestate <= '1';
                  ddr3_savestate   <= '1';
               end if;            
            
            when SAVEMEMORY_NEXT =>
               if (savetype_counter < SAVETYPESCOUNT) then
                  state          <= SAVEMEMORY_STARTREAD;
                  count          <= 2;
                  maxcount       <= savetypes(savetype_counter).size;
                  ddr3_ADDR_save <= std_logic_vector(to_unsigned(savestate_address + savetypes(savetype_counter).offset, 26));
                  RAMAddrNext    <= (others => '0');
                  dwordcounter   <= 0;
               else
                  state          <= SAVESIZEAMOUNT;
                  ddr3_ADDR      <= std_logic_vector(to_unsigned(savestate_address, 26));
                  ddr3_DIN       <= std_logic_vector(to_unsigned(STATESIZE, 32)) & std_logic_vector(header_amount);
                  ddr3_WE        <= '1';
                  ddr3_BE        <= x"FF";
                  if (increaseSSHeaderCount = '0') then
                     ddr3_BE  <= x"F0";
                  end if;
               end if;
               
            when SAVEMEMORY_STARTREAD =>
               if (savetype_counter = 14) then -- spuram
                  if (useSPUSDRAM = '1' or count <= 1024 or count > 16#1C000#) then
                     state          <= SAVEMEMORY_LOAD_SPURAM;
                     SPUwordcounter <= 0;
                     dwordcounter   <= 1;
                  else
                     state          <= SAVEMEMORY_LOAD_VRAM;
                     ddr3_RD        <= '1'; 
                     ddr3_ADDR      <= "000000110" & std_logic_vector(RAMAddrNext(17 downto 1));
                     dwordcounter   <= 1;
                     RAMAddrNext    <= RAMAddrNext + 4;
                  end if;
               elsif (savetype_counter = 15) then -- vram
                  state          <= SAVEMEMORY_LOAD_VRAM;
                  ddr3_RD        <= '1'; 
                  ddr3_ADDR      <= "0000000" & std_logic_vector(RAMAddrNext);
                  dwordcounter   <= 1;
                  RAMAddrNext    <= RAMAddrNext + 2;
               else
                  if (savetype_counter = 16) then -- sdram
                     state                     <= SAVEMEMORY_LOAD_RAM;
                  else
                     state                     <= SAVEMEMORY_WAITREAD;
                  end if;
                  slowcounter                  <= 0;
                  SS_rden_2x(savetype_counter) <= '1';
                  SS_Adr_2x                    <= RAMAddrNext;
                  RAMAddrNext                  <= RAMAddrNext + 1;
               end if;
               
            when SAVEMEMORY_WAITREAD =>
               if (slowcounter < 8) then
                  slowcounter <= slowcounter + 1;
               else
                  state <= SAVEMEMORY_READ;
               end if;
               
            when SAVEMEMORY_LOAD_VRAM =>
               if (ddr3_DOUT_READY = '1') then
                  state             <= SAVEMEMORY_READ;
                  ddr3_DOUT_saved   <= ddr3_DOUT;
               end if;
               
            when SAVEMEMORY_LOAD_RAM =>
               if (ram_done = '1') then
                  state             <= SAVEMEMORY_WAITREAD;
                  slowcounter       <= 4;
               end if;
               
            when SAVEMEMORY_LOAD_SPURAM =>
               state               <= SAVEMEMORY_WAIT_SPURAM;
               SS_SPURAM_Adr       <= std_logic_vector(RAMAddrNext(17 downto 0) & '0');
               SS_SPURAM_request   <= '1';
               SS_SPURAM_rnw       <= '1';
               RAMAddrNext         <= RAMAddrNext + 1;
               
            when SAVEMEMORY_WAIT_SPURAM =>
               if (SPURAM_done2X = '1') then
                  spu_din(SPUwordcounter * 16 + 15 downto SPUwordcounter * 16) <= SPURAM_dataRead2x;
                  if (SPUwordcounter = 3) then
                     state       <= SAVEMEMORY_READ;
                  else
                     state <= SAVEMEMORY_LOAD_SPURAM;
                     SPUwordcounter <=  SPUwordcounter + 1;
                  end if;
               end if;
            
            when SAVEMEMORY_READ =>
               if (dwordcounter = 0) then
                  ddr3_DIN(31 downto 0)  <= SS_DataRead_2x;
                  state                  <= SAVEMEMORY_STARTREAD;
                  dwordcounter           <= 1;
               else
                  ddr3_DIN(63 downto 32) <= SS_DataRead_2x;
                  ddr3_ADDR              <= ddr3_ADDR_save;
                  ddr3_WE                <= '1';
                  ddr3_BE                <= x"FF";
                  state                  <= SAVEMEMORY_WRITE;
                  dwordcounter           <= 0;
                  
                  if (savetype_counter = 14) then -- SPUram
                     if (useSPUSDRAM = '1' or count <= 1024 or count > 16#1C000#) then
                        ddr3_DIN <= spu_din;
                     else
                        ddr3_DIN <= ddr3_DOUT_saved;
                     end if;
                  elsif (savetype_counter = 15) then -- vram
                     ddr3_DIN <= ddr3_DOUT_saved;
                  end if;
               end if;
               
            when SAVEMEMORY_WRITE =>
               if (DDR3_busy = '0') then
                  ddr3_ADDR_save <= std_logic_vector(unsigned(ddr3_ADDR_save) + 2);
                  if (count < maxcount) then
                     state        <= SAVEMEMORY_STARTREAD;
                     count        <= count + 2;
                  else 
                     savetype_counter <= savetype_counter + 1;
                     state            <= SAVEMEMORY_NEXT;
                  end if;
               end if;
            
            when SAVESIZEAMOUNT =>
               if (DDR3_busy = '0') then
                  state       <= SAVEWAITHPSDONE;
                  if (increaseSSHeaderCount = '1') then
                     unstallwait <= 16777215;
                  end if;
               end if;
             
            when SAVEWAITHPSDONE =>
               if (unstallwait > 0) then
                  unstallwait <= unstallwait - 1;
               else
                  state            <= IDLE;
                  saving_savestate <= '0';
                  ddr3_savestate   <= '0';
               end if;

            -- #################
            -- LOAD
            -- #################
            
            when LOAD_WAITSETTLE =>
               if (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               else
                  state             <= LOAD_HEADERAMOUNTCHECK;
                  ddr3_savestate    <= '1';
                  ddr3_ADDR         <= std_logic_vector(to_unsigned(savestate_address, 26));
                  ddr3_RD           <= not resetMode;
               end if;
               
            when LOAD_HEADERAMOUNTCHECK =>
               if (ddr3_DOUT_READY = '1' or resetMode = '1') then
                  if (ddr3_DOUT(63 downto 32) = std_logic_vector(to_unsigned(STATESIZE, 32)) or resetMode = '1') then
                     if (resetMode = '1') then
                        header_amount     <= (others => '0');
                     else
                        header_amount     <= unsigned(ddr3_DOUT(31 downto 0));
                     end if;
                     state                <= LOADMEMORY_NEXT;
                     loading_ss_2x        <= '1';
                     reset_2x             <= '1';
                     ss_reset_2x          <= '1';
                  else
                     state                <= IDLE;
                     sleep_savestate      <= '0';
                     ddr3_savestate       <= '0';
                  end if;
               end if;
            
            when LOADMEMORY_NEXT =>
               if ((FASTSIM = '0' and ((exeMode = '0' and savetype_counter < SAVETYPESCOUNT) or (exeMode = '1' and savetype_counter < 16))) or 
                   (FASTSIM = '1' and savetype_counter < 14 and resetMode = '1') or 
                   (FASTSIM = '1' and savetype_counter < 15 and resetMode = '0')) then
                  ddr3_ADDR      <= std_logic_vector(to_unsigned(savestate_address + savetypes(savetype_counter).offset, 26));
                  ddr3_RD        <= not resetMode;
                  state          <= LOADMEMORY_READ;
                  count          <= 2;
                  maxcount       <= savetypes(savetype_counter).size;
                  RAMAddrNext    <= (others => '0');
                  dwordcounter   <= 0;
               else
                  state             <= IDLE;
                  ddr3_savestate    <= '0';
                  reset_2x          <= '1';
                  loading_ss_2x     <= '0';
                  sleep_savestate   <= '0';
                  load_done_2x      <= not resetMode;
               end if;
            
            when LOADMEMORY_READ =>
               ddr3_ADDR_save <= ddr3_ADDR;
               if (ddr3_DOUT_READY = '1' or resetMode = '1') then
                  state             <= LOADMEMORY_WRITE;
                  
                  if (resetMode = '1') then
                     ddr3_DOUT_saved   <= (others => '0');
                     ddr3_DIN          <= (others => '0');
                  else
                     ddr3_DOUT_saved   <= ddr3_DOUT;
                     ddr3_DIN          <= ddr3_DOUT;
                  end if;
                  
                  if (savetype_counter = 14) then -- spuram
                     if (useSPUSDRAM = '1' or count <= 1024 or count > 16#1C000#) then
                        dwordcounter   <= 1;
                        state          <= LOADMEMORY_WRITE_SPURAM; 
                        SPUwordcounter <= 0;
                     else
                        dwordcounter <= 1;
                        state        <= LOADMEMORY_WRITE_VRAM;
                        ddr3_WE      <= '1';
                        ddr3_BE      <= x"FF";    
                        
                        ddr3_ADDR    <= "000000110" & std_logic_vector(RAMAddrNext(17 downto 1));
                        RAMAddrNext  <= RAMAddrNext + 4;
                     end if;
                  end if;
                  if (savetype_counter = 15) then -- vram
                     dwordcounter <= 1;
                     state        <= LOADMEMORY_WRITE_VRAM;
                     ddr3_WE      <= '1';
                     ddr3_BE      <= x"FF";    
                     
                     ddr3_ADDR    <= "0000000" & std_logic_vector(RAMAddrNext);
                     RAMAddrNext  <= RAMAddrNext + 2;
                  end if;
               end if;
               
            when LOADMEMORY_WRITE =>
               if (clk2xIndex = '0') then
                  RAMAddrNext      <= RAMAddrNext + 1;
                  SS_DataWrite_2x  <= ddr3_DOUT_saved(dwordcounter * 32 + 31 downto dwordcounter * 32);
                  SS_Adr_2x        <= RAMAddrNext;
                  SS_wren_2x(savetype_counter) <= '1';
                  state            <= LOADMEMORY_WRITE_NEXT;
                  if (savetype_counter = 16) then -- sdram
                     state <= LOADMEMORY_WRITE_SDRAM;
                  end if;
               end if;
         
            when LOADMEMORY_WRITE_VRAM =>
               if (ddr3_BUSY = '0') then
                  state <= LOADMEMORY_WRITE_NEXT;
               end if;
               
            when LOADMEMORY_WRITE_SDRAM =>
               if (sdram_done = '1') then
                  state <= LOADMEMORY_WRITE_NEXT;
               end if;
               
            when LOADMEMORY_WRITE_SPURAM =>
               state               <= LOADMEMORY_WAIT_SPURAM;
               SS_SPURAM_dataWrite <= ddr3_DOUT_saved(SPUwordcounter * 16 + 15 downto SPUwordcounter * 16);
               SS_SPURAM_Adr       <= std_logic_vector(RAMAddrNext(17 downto 0) & '0');
               SS_SPURAM_request   <= '1';
               SS_SPURAM_rnw       <= '0';
               RAMAddrNext         <= RAMAddrNext + 1;
            
            when LOADMEMORY_WAIT_SPURAM => 
               if (SPURAM_done2X = '1') then
                  if (SPUwordcounter = 3) then
                     state <= LOADMEMORY_WRITE_NEXT;
                     if (FASTSIM = '1' and count = 1024) then
                        count          <= count + 16#1C000# - 1024;
                        RAMAddrNext    <= RAMAddrNext + (16#38000# - 2048);
                        ddr3_ADDR_save <= std_logic_vector(unsigned(ddr3_ADDR_save) + 16#1C000# - 1024);
                     end if;
                  else
                     state <= LOADMEMORY_WRITE_SPURAM;
                     SPUwordcounter <=  SPUwordcounter + 1;
                  end if;
               end if;
               
            when LOADMEMORY_WRITE_NEXT =>
               state <= LOADMEMORY_WRITE;
               if (dwordcounter < 1) then
                  dwordcounter <= dwordcounter + 1;
               else
                  ddr3_ADDR  <= std_logic_vector(unsigned(ddr3_ADDR_save) + 2);
                  if (count < maxcount) then
                     state          <= LOADMEMORY_READ;
                     count          <= count + 2;
                     dwordcounter   <= 0;
                     ddr3_RD        <= not resetMode;
                  else 
                     if (savetype_counter = 12 and resetMode = '1') then
                        savetype_counter <= 14;
                     else
                        savetype_counter <= savetype_counter + 1;
                     end if;
                     state            <= LOADMEMORY_NEXT;
                  end if;
               end if;
            
         
         end case;
         
         reset_in_1 <= reset_in;
         if (reset_in = '1' and reset_in_1 = '0') then
            state           <= IDLE;
         end if;
         
      end if;
   end process;
   

end architecture;





