library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity savestates is
   generic 
   (
      SAVETYPESCOUNT : integer := 13
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
         
      load_done               : out std_logic := '0';
            
      increaseSSHeaderCount   : in  std_logic;  
      save                    : in  std_logic;  
      load                    : in  std_logic;
      savestate_address       : in  integer;
      savestate_busy          : out std_logic;

      system_idle             : in  std_logic;
      savestate_slow          : out std_logic := '0';
            
      SS_DataWrite            : out std_logic_vector(31 downto 0) := (others => '0');
      SS_Adr                  : out unsigned(18 downto 0) := (others => '0');
      SS_wren                 : out std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
      SS_DataRead_CPU         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_DataRead_GPU         : in  std_logic_vector(31 downto 0) := (others => '0');
      SS_busy                 : in  std_logic;
            
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
      ddr3_RD                 : out std_logic := '0'
   );
end entity;

architecture arch of savestates is

   constant STATESIZE      : integer := 1048576;
   
   constant SETTLECOUNT    : integer := 100;
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
      ( 1024, 128),    -- CPU          0 
      ( 2048,   8),    -- GPU          1 
      ( 3072,   8),    -- GPUTiming    2 
      ( 4096,  64),    -- DMA          3 
      ( 5120,  64),    -- GTE          4 
      ( 6144,   8),    -- Joypad       5 
      ( 7168, 256),    -- MDEC         6 
      ( 8192,  16),    -- Memory       7 
      ( 9216,  16),    -- Timer        8 
      (10240, 256),    -- Sound        9 
      (11264,   2),    -- IRQ          10
      (12288,   8),    -- SIO          11
      (31744,1024)     -- Scratchpad   12
   );

   type tstate is
   (
      IDLE,
      --SAVE_WAITIDLE,
      --SAVE_WAITSETTLE,
      --SAVEINTERNALS_WAIT,
      --SAVEINTERNALS_WRITE,
      --SAVEMEMORY_NEXT,
      --SAVEMEMORY_READY,
      --SAVEMEMORY_WAITREAD,
      --SAVEMEMORY_READ,
      --SAVEMEMORY_WRITE,
      --SAVESIZEAMOUNT,
      LOAD_WAITSETTLE,
      LOAD_HEADERAMOUNTCHECK,
      LOADMEMORY_NEXT,
      LOADMEMORY_READ,
      LOADMEMORY_READY,
      LOADMEMORY_WRITE,
      LOADMEMORY_WRITE_SLOW,
      LOADMEMORY_WRITE_NEXT
   );
   signal state : tstate := IDLE;
   
   signal count               : integer range 0 to 524288 := 0;
   signal maxcount            : integer range 0 to 524288;
               
   signal settle              : integer range 0 to SETTLECOUNT := 0;
   
   signal reset_2x            : std_logic := '0';
   signal loading_ss_2x       : std_logic := '0';
   
   signal SS_DataWrite_2x     : std_logic_vector(31 downto 0) := (others => '0');
   signal SS_Adr_2x           : unsigned(18 downto 0) := (others => '0');
   signal SS_wren_2x          : std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
   
   signal ddr3_DOUT_saved     : std_logic_vector(63 downto 0);
   signal dwordcounter        : integer range 0 to 1 := 0;
   signal SS_DataRead         : std_logic_vector(31 downto 0);
   signal RAMAddrNext         : unsigned(18 downto 0) := (others => '0');
   signal slowcounter         : integer range 0 to 2 := 0;
   
   signal header_amount       : unsigned(31 downto 0) := to_unsigned(1, 32);

begin 

   savestate_busy <= '0' when state = IDLE else '1';
   
   SS_DataRead <= SS_DataRead_CPU when savetype_counter = 0 else
                  SS_DataRead_GPU when savetype_counter = 1 else
                       (others => '0');

   ddr3_BE       <= x"FF";
   ddr3_BURSTCNT <= x"01";

   process (clk1x)
   begin
      if rising_edge(clk1x) then

         reset_out         <= reset_2x;
         
         if (loading_ss_2x = '1') then
            loading_savestate <= '1';
         elsif (reset_2x = '0') then
            loading_savestate <= '0';
         end if;
         
         SS_wren <= (others => '0');
         if (unsigned(SS_wren_2x) > 0) then
            SS_DataWrite <= SS_DataWrite_2x;
            SS_Adr       <= SS_Adr_2x;      
            SS_wren      <= SS_wren_2x;     
         end if;

      end if;
   end process;

   process (clk2x)
   begin
      if rising_edge(clk2x) then
   
         if (clk2xIndex = '0') then
            SS_wren_2x <= (others => '0');
         end if;
         
         ss_reset      <= '0';
         load_done     <= '0';
         
         if (reset_out = '1') then
            reset_2x <= '0';
         end if;
         
         if (ddr3_BUSY = '0') then
            ddr3_WE <= '0';
            ddr3_RD <= '0';
         end if;
         
         case state is
         
            when IDLE =>
               savetype_counter <= 0;
               savestate_slow   <= '0';
               if (reset_in = '1') then
                  reset_2x      <= '1';
                  ss_reset       <= '1';
               --elsif (save = '1') then
               --   savestate_slow       <= '1';
               --   state                <= SAVE_WAITIDLE;
               --   header_amount        <= header_amount + 1;
               elsif (load = '1') then
                  state                <= LOAD_WAITSETTLE;
                  settle               <= 0;
                  sleep_savestate      <= '1';
               end if;
               
            -- #################
            -- SAVE
            -- #################
            
            --when SAVE_WAITIDLE =>
            --   if (system_idle = '1' and ce = '0') then
            --      state                <= SAVE_WAITSETTLE;
            --      settle               <= 0;
            --      sleep_savestate      <= '1';
            --   end if;
            --
            --when SAVE_WAITSETTLE =>
            --   if (settle < SETTLECOUNT) then
            --      settle <= settle + 1;
            --   else
            --      state            <= SAVEINTERNALS_WAIT;
            --      bus_out_Adr      <= std_logic_vector(to_unsigned(savestate_address + HEADERCOUNT, 26));
            --      bus_out_rnw      <= '0';
            --      BUS_adr          <= (others => '0');
            --      count            <= 1;
            --      saving_savestate <= '1';
            --   end if;            
            --
            --when SAVEINTERNALS_WAIT =>
            --   bus_out_Din    <= BUS_Dout;
            --   bus_out_ena    <= '1';
            --   state          <= SAVEINTERNALS_WRITE;
            --
            --when SAVEINTERNALS_WRITE => 
            --   if (bus_out_done = '1') then
            --      bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
            --      if (count < INTERNALSCOUNT) then
            --         state       <= SAVEINTERNALS_WAIT;
            --         count       <= count + 1;
            --         BUS_adr     <= std_logic_vector(unsigned(BUS_adr) + 1);
            --      else 
            --         state       <= SAVEMEMORY_NEXT;
            --         count       <= 8;
            --      end if;
            --   end if;
            --
            --when SAVEMEMORY_NEXT =>
            --   if (savetype_counter < SAVETYPESCOUNT) then
            --      state        <= SAVEMEMORY_READY;
            --      bytecounter  <= 0;
            --      count        <= 8;
            --      maxcount     <= savetypes(savetype_counter);
            --      Save_RAMAddr <= (others => '0');
            --   else
            --      state          <= SAVESIZEAMOUNT;
            --      bus_out_Adr    <= std_logic_vector(to_unsigned(savestate_address, 26));
            --      bus_out_Din    <= std_logic_vector(to_unsigned(STATESIZE, 32)) & std_logic_vector(header_amount);
            --      bus_out_ena    <= '1';
            --      if (increaseSSHeaderCount = '0') then
            --         bus_out_be  <= x"F0";
            --      end if;
            --   end if;
            --   
            --when SAVEMEMORY_READY =>
            --   if (Save_busy = '0') then
            --      state        <= SAVEMEMORY_WAITREAD;
            --      Save_RAMRdEn(savetype_counter) <= '1';
            --      slowcounter  <= 0;
            --   end if;
            --   
            --when SAVEMEMORY_WAITREAD =>
            --   if (savetype_counter = 2 and slowcounter < 2) then
            --      slowcounter <= slowcounter + 1;
            --   else
            --      state <= SAVEMEMORY_READ;
            --   end if;
            --
            --when SAVEMEMORY_READ =>
            --   if (savetype_counter = 0) then
            --      bus_out_Din(bytecounter * 8 +  7 downto bytecounter * 8)  <= Save_RAMReadData(7 downto 0);
            --   else
            --      bus_out_Din(bytecounter * 8 + 15 downto bytecounter * 8)  <= Save_RAMReadData;
            --   end if;
            --   if (savetype_counter = 0) then
            --      Save_RAMAddr   <= std_logic_vector(unsigned(Save_RAMAddr) + 1);
            --   else
            --      Save_RAMAddr   <= std_logic_vector(unsigned(Save_RAMAddr) + 2);
            --   end if;
            --   if ((savetype_counter = 0 and bytecounter < 7) or (savetype_counter > 0 and bytecounter < 6)) then
            --      state       <= SAVEMEMORY_WAITREAD;
            --      slowcounter <= 0;
            --      Save_RAMRdEn(savetype_counter) <= '1';
            --      if (savetype_counter = 0) then
            --         bytecounter    <= bytecounter + 1;
            --      else
            --         bytecounter    <= bytecounter + 2;
            --      end if;
            --   else
            --      state          <= SAVEMEMORY_WRITE;
            --      bus_out_ena    <= '1';
            --   end if;
            --   
            --when SAVEMEMORY_WRITE =>
            --   if (bus_out_done = '1') then
            --      bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
            --      if (count < maxcount) then
            --         state        <= SAVEMEMORY_READY;
            --         bytecounter  <= 0;
            --         count        <= count + 8;
            --      else 
            --         savetype_counter <= savetype_counter + 1;
            --         state            <= SAVEMEMORY_NEXT;
            --      end if;
            --   end if;
            --
            --when SAVESIZEAMOUNT =>
            --   if (bus_out_done = '1') then
            --      state            <= IDLE;
            --      saving_savestate <= '0';
            --      sleep_savestate  <= '0';
            --   end if;
            
            
            -- #################
            -- LOAD
            -- #################
            
            when LOAD_WAITSETTLE =>
               if (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               else
                  state             <= LOAD_HEADERAMOUNTCHECK;
                  ddr3_ADDR         <= std_logic_vector(to_unsigned(savestate_address, 26));
                  ddr3_RD           <= '1';
               end if;
               
            when LOAD_HEADERAMOUNTCHECK =>
               if (ddr3_DOUT_READY = '1') then
                  if (ddr3_DOUT(63 downto 32) = std_logic_vector(to_unsigned(STATESIZE, 32))) then
                     header_amount        <= unsigned(ddr3_DOUT(31 downto 0));
                     state                <= LOADMEMORY_NEXT;
                     loading_ss_2x        <= '1';
                     reset_2x             <= '1';
                     ss_reset             <= '1';
                  else
                     state                <= IDLE;
                     sleep_savestate      <= '0';
                  end if;
               end if;
            
            when LOADMEMORY_NEXT =>
               if (savetype_counter < SAVETYPESCOUNT) then
                  ddr3_ADDR      <= std_logic_vector(to_unsigned(savestate_address + savetypes(savetype_counter).offset, 26));
                  ddr3_RD        <= '1';
                  state          <= LOADMEMORY_READ;
                  count          <= 2;
                  maxcount       <= savetypes(savetype_counter).size;
                  RAMAddrNext    <= (others => '0');
                  dwordcounter   <= 0;
               else
                  state             <= IDLE;
                  reset_2x          <= '1';
                  loading_ss_2x     <= '0';
                  sleep_savestate   <= '0';
                  load_done         <= '1';
               end if;
            
            when LOADMEMORY_READ =>
               if (ddr3_DOUT_READY = '1') then
                  state             <= LOADMEMORY_READY;
                  ddr3_DOUT_saved   <= ddr3_DOUT;
               end if;
               
            when LOADMEMORY_READY =>
               if (SS_busy = '0') then
                  state             <= LOADMEMORY_WRITE;
               end if;
               
            when LOADMEMORY_WRITE =>
               if (clk2xIndex = '0') then
                  RAMAddrNext      <= RAMAddrNext + 1;
                  SS_DataWrite_2x  <= ddr3_DOUT_saved(dwordcounter * 32 + 31 downto dwordcounter * 32);
                  SS_Adr_2x        <= RAMAddrNext;
                  SS_wren_2x(savetype_counter) <= '1';
                  state            <= LOADMEMORY_WRITE_NEXT;
               end if;
         
            when LOADMEMORY_WRITE_SLOW =>
               state <= LOADMEMORY_WRITE_NEXT;
               
            when LOADMEMORY_WRITE_NEXT =>
               state <= LOADMEMORY_WRITE;
               if (dwordcounter < 1) then
                  dwordcounter <= dwordcounter + 1;
               else
                  ddr3_ADDR  <= std_logic_vector(unsigned(ddr3_ADDR) + 2);
                  if (count < maxcount) then
                     state          <= LOADMEMORY_READ;
                     count          <= count + 2;
                     dwordcounter   <= 0;
                     ddr3_RD        <= '1';
                  else 
                     savetype_counter <= savetype_counter + 1;
                     state            <= LOADMEMORY_NEXT;
                  end if;
               end if;
            
         
         end case;
         
         if (reset_in = '1') then
            state <= IDLE;
         end if;
         
      end if;
   end process;
   

end architecture;





