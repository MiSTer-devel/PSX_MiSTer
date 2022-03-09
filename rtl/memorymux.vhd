library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity memorymux is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      loadExe              : in  std_logic;
      reset_exe            : out std_logic := '0';
      
      fastboot             : in  std_logic;
      NOMEMWAIT            : in  std_logic;
      PATCHSERIAL          : in  std_logic;
      
      isIdle               : out std_logic;
      
      ram_dataWrite        : out std_logic_vector(31 downto 0) := (others => '0');
      ram_dataRead         : in  std_logic_vector(127 downto 0);
      ram_dataRead32       : in  std_logic_vector(31 downto 0);
      ram_Adr              : out std_logic_vector(22 downto 0) := (others => '0');
      ram_be               : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw              : out std_logic := '0';
      ram_ena              : out std_logic := '0';
      ram_128              : out std_logic := '0';
      ram_done             : in  std_logic;
      ram_idle             : in  std_logic;
      
      mem_request          : in  std_logic;
      mem_rnw              : in  std_logic; 
      mem_isData           : in  std_logic; 
      mem_isCache          : in  std_logic; 
      mem_addressInstr     : in  unsigned(31 downto 0); 
      mem_addressData      : in  unsigned(31 downto 0); 
      mem_reqsize          : in  unsigned(1 downto 0); 
      mem_writeMask        : in  std_logic_vector(3 downto 0); 
      mem_dataWrite        : in  std_logic_vector(31 downto 0); 
      mem_dataRead         : out std_logic_vector(31 downto 0); 
      mem_dataCache        : out std_logic_vector(127 downto 0); 
      mem_done             : out std_logic;
      
      --bus_exp1_addr        : out unsigned(22 downto 0); 
      --bus_exp1_dataWrite   : out std_logic_vector(31 downto 0);
      bus_exp1_read        : out std_logic;
      --bus_exp1_write       : out std_logic;
      bus_exp1_dataRead    : in  std_logic_vector(31 downto 0);
      
      bus_memc_addr        : out unsigned(5 downto 0); 
      bus_memc_dataWrite   : out std_logic_vector(31 downto 0);
      bus_memc_read        : out std_logic;
      bus_memc_write       : out std_logic;
      bus_memc_dataRead    : in  std_logic_vector(31 downto 0);
      
      bus_pad_addr         : out unsigned(3 downto 0); 
      bus_pad_dataWrite    : out std_logic_vector(31 downto 0);
      bus_pad_read         : out std_logic;
      bus_pad_write        : out std_logic;
      bus_pad_writeMask    : out std_logic_vector(3 downto 0);
      bus_pad_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_sio_addr         : out unsigned(3 downto 0); 
      bus_sio_dataWrite    : out std_logic_vector(31 downto 0);
      bus_sio_read         : out std_logic;
      bus_sio_write        : out std_logic;
      bus_sio_writeMask    : out std_logic_vector(3 downto 0);
      bus_sio_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_memc2_addr       : out unsigned(3 downto 0); 
      bus_memc2_dataWrite  : out std_logic_vector(31 downto 0);
      bus_memc2_read       : out std_logic;
      bus_memc2_write      : out std_logic;
      bus_memc2_dataRead   : in  std_logic_vector(31 downto 0);
      
      bus_irq_addr         : out unsigned(3 downto 0); 
      bus_irq_dataWrite    : out std_logic_vector(31 downto 0);
      bus_irq_read         : out std_logic;
      bus_irq_write        : out std_logic;
      bus_irq_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_dma_addr         : out unsigned(6 downto 0); 
      bus_dma_dataWrite    : out std_logic_vector(31 downto 0);
      bus_dma_read         : out std_logic;
      bus_dma_write        : out std_logic;
      bus_dma_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_tmr_addr         : out unsigned(5 downto 0); 
      bus_tmr_dataWrite    : out std_logic_vector(31 downto 0);
      bus_tmr_read         : out std_logic;
      bus_tmr_write        : out std_logic;
      bus_tmr_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_cd_addr          : out unsigned(3 downto 0); 
      bus_cd_dataWrite     : out std_logic_vector(7 downto 0);
      bus_cd_read          : out std_logic;
      bus_cd_write         : out std_logic;
      bus_cd_dataRead      : in  std_logic_vector(7 downto 0);
      
      bus_gpu_addr         : out unsigned(3 downto 0); 
      bus_gpu_dataWrite    : out std_logic_vector(31 downto 0);
      bus_gpu_read         : out std_logic;
      bus_gpu_write        : out std_logic;
      bus_gpu_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_mdec_addr        : out unsigned(3 downto 0); 
      bus_mdec_dataWrite   : out std_logic_vector(31 downto 0);
      bus_mdec_read        : out std_logic;
      bus_mdec_write       : out std_logic;
      bus_mdec_dataRead    : in  std_logic_vector(31 downto 0);
      
      bus_spu_addr         : out unsigned(9 downto 0) := (others => '0'); 
      bus_spu_dataWrite    : out std_logic_vector(15 downto 0);
      bus_spu_read         : out std_logic;
      bus_spu_write        : out std_logic;
      bus_spu_dataRead     : in  std_logic_vector(15 downto 0);
      
      bus_exp2_addr        : out unsigned(12 downto 0); 
      bus_exp2_dataWrite   : out std_logic_vector(31 downto 0);
      bus_exp2_read        : out std_logic;
      bus_exp2_write       : out std_logic;
      bus_exp2_dataRead    : in  std_logic_vector(31 downto 0);
      bus_exp2_writeMask   : out std_logic_vector(3 downto 0);
      
      --bus_exp3_dataWrite   : out std_logic_vector(31 downto 0);
      bus_exp3_read        : out std_logic;
      --bus_exp3_write       : out std_logic;
      bus_exp3_dataRead    : in  std_logic_vector(31 downto 0);
      
      loading_savestate    : in  std_logic;
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(18 downto 0);
      SS_wren_SDRam        : in  std_logic;
      SS_rden_SDRam        : in  std_logic
   );
end entity;

architecture arch of memorymux is
  
   type tState is
   (
      IDLE,
      --CHECKRAM,
      --ERRORRAM,
      READBIOS,
      READBIOSCACHE,
      BUSACTION,
      CD_WRITE,
      CD_READ_WAIT,
      CD_READ,      
      SPU_WRITE,
      SPU_READ_WAIT,
      SPU_READ,
      WAITING,
      
      EXEREADHEADER,
      EXEREADHEADER1,
      EXEREADHEADER2,
      EXEPATCHBIOSWRITE,
      EXEPATCHBIOSWAIT,
      EXECOPYREAD,
      EXECOPYWRITE
   );
   signal state            : tState := IDLE;
   
   signal byteStep         : unsigned(1 downto 0);
   signal waitcnt          : integer range 0 to 127;
   
   signal mem_dataRead_buf : std_logic_vector(31 downto 0);
   signal mem_done_buf     : std_logic := '0';
   
   signal readram          : std_logic := '0';
   signal writeram         : std_logic := '0';
   signal maskram          : std_logic := '0';
   signal instantwrite     : std_logic := '0';
   
   signal addressData_buf  : unsigned(31 downto 0);
   signal dataWrite_buf    : std_logic_vector(31 downto 0);
   signal reqsize_buf      : unsigned(1 downto 0);   
   signal writeMask_buf    : std_logic_vector(3 downto 0);
   
   signal addressBIOS_buf  : unsigned(18 downto 0);
   
   signal dataFromBusses   : std_logic_vector(31 downto 0);
   signal rotate32         : std_logic;
   signal rotate16         : std_logic;
   
   signal data_cd          : std_logic_vector(31 downto 0);
   signal data_spu         : std_logic_vector(31 downto 0);
   
   -- EXE handling
   signal loadExe_latched  : std_logic := '0';
   signal exestep          : integer range 0 to 8;
   signal execopycnt       : unsigned(31 downto 0);
   signal exe_initial_pc   : unsigned(31 downto 0);
   signal exe_initial_gp   : unsigned(31 downto 0);
   signal exe_load_address : unsigned(31 downto 0);
   signal exe_file_size    : unsigned(31 downto 0);
   signal exe_stackpointer : unsigned(31 downto 0);
   
   -- debug
   signal stallcountRead   : integer;
   signal stallcountWrite  : integer;
   signal stallcountWriteF : integer;
   signal stallcountIntBus : integer;
   
   signal addressDataF     : std_logic := '0';
   
begin 

   isIdle <= '1' when (state = IDLE and readram = '0' and writeram = '0') else '0';

   process (state, mem_request, mem_rnw, mem_isData, mem_addressData, mem_reqsize, mem_writeMask, mem_dataWrite, ce)
      variable address : unsigned(28 downto 0);
   begin
   
      address := mem_addressData(28 downto 0);
   
      -- exp1
      bus_exp1_read      <= '0';
      --bus_exp1_write     <= '0';
      --bus_exp1_addr      <= address(22 downto 0);
      --bus_exp1_dataWrite <= mem_dataWrite;
      if (address >= 16#1F000000# and address < 16#1F800000#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_exp1_read  <= mem_rnw;
            --bus_exp1_write <= not mem_rnw;
         end if;
      end if;
      
      -- memc
      bus_memc_read      <= '0';
      bus_memc_write     <= '0';
      bus_memc_addr      <= address(5 downto 0);
      bus_memc_dataWrite <= mem_dataWrite;
      if (address >= 16#1F801000# and address < 16#1F801040#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_memc_read  <= mem_rnw;
            bus_memc_write <= not mem_rnw;
         end if;
      end if;
      
      -- pad
      bus_pad_read      <= '0';
      bus_pad_write     <= '0';
      bus_pad_addr      <= address(3 downto 0);
      bus_pad_dataWrite <= mem_dataWrite;
      bus_pad_writeMask <= mem_writeMask;
      if (address >= 16#1F801040# and address < 16#1F801050#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_pad_read  <= mem_rnw;
            bus_pad_write <= not mem_rnw;
         end if;
      end if;
      
      -- sio
      bus_sio_read      <= '0';
      bus_sio_write     <= '0';
      bus_sio_addr      <= address(3 downto 0);
      bus_sio_dataWrite <= mem_dataWrite;
      bus_sio_writeMask <= mem_writeMask;
      if (address >= 16#1F801050# and address < 16#1F801060#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_sio_read  <= mem_rnw;
            bus_sio_write <= not mem_rnw;
         end if;
      end if;
      
      -- memc2
      bus_memc2_read      <= '0';
      bus_memc2_write     <= '0';
      bus_memc2_addr      <= address(3 downto 0);
      bus_memc2_dataWrite <= mem_dataWrite;
      if (address >= 16#1F801060# and address < 16#1F801070#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_memc2_read  <= mem_rnw;
            bus_memc2_write <= not mem_rnw;
         end if;
      end if;
      
      -- irq
      bus_irq_read      <= '0';
      bus_irq_write     <= '0';
      bus_irq_addr      <= address(3 downto 0);
      bus_irq_dataWrite <= mem_dataWrite;
      if (address >= 16#1F801070# and address < 16#1F801080#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_irq_read  <= mem_rnw;
            bus_irq_write <= not mem_rnw;
         end if;
      end if;
      
      -- dma
      bus_dma_read      <= '0';
      bus_dma_write     <= '0';
      bus_dma_addr      <= address(6 downto 0);
      bus_dma_dataWrite <= mem_dataWrite;
      if (address >= 16#1F801080# and address < 16#1F801100#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_dma_read  <= mem_rnw;
            bus_dma_write <= not mem_rnw;
         end if;
      end if;
      
      -- timer
      bus_tmr_read      <= '0';
      bus_tmr_write     <= '0';
      bus_tmr_addr      <= address(5 downto 0);
      bus_tmr_dataWrite <= mem_dataWrite;
      if (address >= 16#1F801100# and address < 16#1F801140#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_tmr_read  <= mem_rnw;
            bus_tmr_write <= not mem_rnw;
         end if;
      end if;
      
      -- gpu
      bus_gpu_read      <= '0';
      bus_gpu_write     <= '0';
      bus_gpu_addr      <= address(3 downto 0);
      bus_gpu_dataWrite <= mem_dataWrite;
      if (address >= 16#1F801810# and address < 16#1F801820#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_gpu_read  <= mem_rnw;
            bus_gpu_write <= not mem_rnw;
         end if;
      end if;
      
      -- mdec
      bus_mdec_read      <= '0';
      bus_mdec_write     <= '0';
      bus_mdec_addr      <= address(3 downto 0);
      bus_mdec_dataWrite <= mem_dataWrite;
      if (address >= 16#1F801820# and address < 16#1F801830#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_mdec_read  <= mem_rnw;
            bus_mdec_write <= not mem_rnw;
         end if;
      end if;
      
      -- exp2
      bus_exp2_read      <= '0';
      bus_exp2_write     <= '0';
      bus_exp2_addr      <= address(12 downto 0);
      bus_exp2_dataWrite <= mem_dataWrite;
      bus_exp2_writeMask <= mem_writeMask;
      if (address >= 16#1F802000# and address < 16#1F804000#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_exp2_read  <= mem_rnw;
            bus_exp2_write <= not mem_rnw;
         end if;
      end if;
      
      -- exp3
      bus_exp3_read      <= '0';
      --bus_exp3_write     <= '0';
      --bus_exp3_dataWrite <= mem_dataWrite;
      --bus_exp3_writeMask <= mem_writeMask;
      if (address = 16#1FA00000#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_exp3_read  <= mem_rnw;
            --bus_exp3_write <= not mem_rnw;
         end if;
      end if;

   end process;
   
   dataFromBusses <= bus_exp1_dataRead or bus_memc_dataRead or bus_pad_dataRead or bus_sio_dataRead or bus_memc2_dataRead or bus_irq_dataRead or 
                     bus_dma_dataRead or bus_tmr_dataRead or bus_gpu_dataRead or bus_mdec_dataRead or bus_exp2_dataRead or bus_exp3_dataRead or
                     data_cd or data_spu;
  
   mem_dataRead   <= ram_dataRead32 when (readram = '1' and ram_done = '1') else mem_dataRead_buf;
                     
   mem_done       <= '1'            when (instantwrite = '1') else
                     '1'            when (readram = '1'  and ram_done = '1' and maskram = '0') else 
                     '1'            when (writeram = '1' and ram_done = '1' and maskram = '0') else 
                     mem_done_buf;
  
   mem_dataCache  <= ram_dataRead;
  
   process (clk1x)
      variable biosPatch  : std_logic_vector(31 downto 0);
   begin
      if rising_edge(clk1x) then
      
         ram_ena        <= '0';
         mem_done_buf   <= '0';
         reset_exe      <= '0';
         
         bus_cd_read    <= '0';
         bus_cd_write   <= '0';         
         
         bus_SPU_read   <= '0';
         bus_SPU_write  <= '0';
         
         if (loadExe = '1') then
            loadExe_latched <= '1';
         end if;
         
         if (ram_done = '1') then
            maskram  <= '0';
            if (maskram = '0') then
               readram  <= '0';
               writeram <= '0';
            end if;
         end if;
         
         instantwrite <= '0';
      
         if (reset = '1') then

            state   <= IDLE;
            maskram <= '0';

         elsif (ce = '1') then
         
            case (state) is
               when IDLE =>
               
                  byteStep        <= (others => '0');
                  addressData_buf <= mem_addressData;
                  dataWrite_buf   <= mem_dataWrite;
                  reqsize_buf     <= mem_reqsize;
                  writeMask_buf   <= mem_writeMask;
                  
                  rotate32        <= '0';
                  rotate16        <= '0';
                  
                  data_cd         <= (others => '0');
                  data_spu        <= (others => '0');
                  
                  if (loadExe_latched = '1') then
                     
                     state           <= EXEREADHEADER;
               
                  elsif (mem_request = '1') then
                  
                     readram  <= '0';
                     writeram <= '0';
                  
                     if (mem_isData = '0') then
               
                        if (mem_addressInstr(28 downto 0) < 16#800000#) then -- RAM
                           ram_ena <= '1';
                           ram_128 <= '0';
                           ram_rnw <= '1';
                           ram_Adr <= "00" & std_logic_vector(mem_addressInstr(20 downto 0));
                           state   <= IDLE;
                           readram <= '1';
                           if (mem_isCache = '1') then
                              ram_Adr(3 downto 0) <= (others => '0');
                              ram_128             <= '1';
                           end if;
                        elsif (mem_addressInstr(28 downto 0) >= 16#1FC00000# and mem_addressInstr(28 downto 0) < 16#1FC80000#) then -- BIOS
                           ram_ena <= '1';
                           ram_128 <= '0';
                           ram_rnw <= '1';
                           ram_Adr <= "01" & "00" & std_logic_vector(mem_addressInstr(18 downto 0));
                           state   <= READBIOS;
                           addressBIOS_buf <= mem_addressInstr(18 downto 0);
                           waitcnt <= 16;
                           if (mem_isCache = '1') then
                              ram_Adr(3 downto 0) <= (others => '0');
                              state               <= READBIOSCACHE;
                              waitcnt             <= 87;
                              ram_128             <= '1';
                              if (NOMEMWAIT = '1') then
                                 state   <= IDLE;
                                 readram <= '1';
                              end if;
                           end if;
                        else
                           report "should never happen" severity failure; 
                        end if;
            
                     else
                     
                        if (mem_addressData(28 downto 0) < 16#800000#) then -- RAM
                           ram_ena <= '1';
                           ram_128 <= '0';
                           ram_rnw <= mem_rnw;
                           ram_Adr <= "00" & std_logic_vector(mem_addressData(20 downto 0));
                           if (mem_rnw = '1') then
                              state   <= IDLE;
                              readram <= '1';
                           else
                              state    <= IDLE;
                              if (ram_idle = '1') then
                                 instantwrite <= '1'; 
                                 maskram      <= '1';
                              else
                                 writeram <= '1';
                              end if;
                           end if;
                           ram_be        <= mem_writeMask;
                           ram_dataWrite <= mem_dataWrite;
                        elsif (mem_rnw = '1' and mem_addressData(28 downto 0) >= 16#1FC00000# and mem_addressData(28 downto 0) < 16#1FC80000#) then -- BIOS
                           ram_ena <= '1';
                           ram_128 <= '0';
                           ram_rnw <= '1';
                           ram_Adr <= "01" & "00" & std_logic_vector(mem_addressData(18 downto 0));
                           state   <= READBIOS;
                           addressBIOS_buf <= mem_addressData(18 downto 0);
                           case (mem_reqsize) is
                              when "00" => waitcnt <= 1;
                              when "01" => waitcnt <= 4;
                              when "10" => waitcnt <= 16;
                              when others => null;
                           end case;
                        else
                           if (mem_addressData(28 downto 0) >= 16#1F801800# and mem_addressData(28 downto 0) < 16#1F801810#) then
                              if (mem_rnw = '1') then
                                 state       <= CD_READ_WAIT;
                                 bus_cd_addr <= mem_addressData(3 downto 0);
                                 bus_cd_read <= '1';
                              else
                                 state   <= CD_WRITE;
                              end if;
                           elsif (mem_addressData(28 downto 0) >= 16#1F801C00# and mem_addressData(28 downto 0) < 16#1F802000#) then
                              if (mem_rnw = '1') then
                                 state        <= SPU_READ_WAIT;
                                 bus_spu_addr <= mem_addressData(9 downto 0);
                                 bus_spu_read <= '1';
                                 waitcnt      <= 15;
                              else
                                 state   <= SPU_WRITE;
                              end if;
                           else  
                              state <= BUSACTION;
                              if (bus_dma_read   = '1' and mem_reqsize /= 4) then rotate32 <= '1'; end if;
                              if (bus_memc_read  = '1' and mem_reqsize /= 2) then rotate16 <= '1'; end if;
                           end if;
                        end if;
            
                     end if;
                     
                  end if;                  
                  
               when READBIOS =>
                  if (ram_done = '1' and maskram = '0') then
                     if (fastboot = '1' and to_integer(addressBIOS_buf) >= 16#18000# and to_integer(addressBIOS_buf) <= 16#18013#) then
                        case (to_integer(addressBIOS_buf(4 downto 2))) is
                           when 0 => biosPatch := x"3C011F80";
                           when 1 => biosPatch := x"3C0A0300";
                           when 2 => biosPatch := x"AC2A1814";
                           when 3 => biosPatch := x"03E00008";
                           when 4 => biosPatch := x"00000000";
                           when others => null;
                        end case;
                        case (addressBIOS_buf(1 downto 0)) is
                           when "00" => mem_dataRead_buf <= biosPatch;
                           when "01" => mem_dataRead_buf <= x"00" & biosPatch(31 downto 8);
                           when "10" => mem_dataRead_buf <= x"0000" & biosPatch(31 downto 16);
                           when "11" => mem_dataRead_buf <= x"000000" & biosPatch(31 downto 24);
                           when others => null;
                        end case;
                     elsif (PATCHSERIAL = '1' and (to_integer(addressBIOS_buf(18 downto 2)) = 16#1BC3# or to_integer(addressBIOS_buf(18 downto 2)) = 16#1BC5#)) then
                        if (to_integer(addressBIOS_buf(18 downto 2)) = 16#1BC3#) then mem_dataRead_buf <= x"24010001"; end if;
                        if (to_integer(addressBIOS_buf(18 downto 2)) = 16#1BC5#) then mem_dataRead_buf <= x"AF81A9C0"; end if;
                     else
                        if (ram_Adr(0) = '1') then
                           mem_dataRead_buf <= x"00" & ram_dataRead(31 downto 8);
                        else
                           mem_dataRead_buf <= ram_dataRead(31 downto 0);
                        end if;
                     end if;
                        
                     if (NOMEMWAIT = '1') then
                        mem_done_buf <= '1';
                        state        <= IDLE;
                     else
                        state    <= WAITING;
                     end if;
                  end if;
                  
               when READBIOSCACHE =>
                  if (ram_done = '1' and maskram = '0') then
                     state    <= WAITING;
                  end if; 
                  
               when BUSACTION =>
                  if (rotate32 = '1') then
                     case (addressData_buf(1 downto 0)) is
                        when "00" => mem_dataRead_buf <= dataFromBusses;
                        when "01" => mem_dataRead_buf <= x"00" & dataFromBusses(31 downto 8);
                        when "10" => mem_dataRead_buf <= x"0000" & dataFromBusses(31 downto 16);
                        when "11" => mem_dataRead_buf <= x"000000" & dataFromBusses(31 downto 24);
                        when others => null;
                     end case;
                  elsif (rotate16 = '1') then
                     if (addressData_buf(0) = '1') then
                        mem_dataRead_buf <= x"00" & dataFromBusses(31 downto 8);
                     else
                        mem_dataRead_buf <= dataFromBusses;
                     end if;
                  else
                     mem_dataRead_buf <= dataFromBusses;
                  end if;
                  mem_done_buf <= '1';
                  state        <= IDLE;
                  
               -- CD
               when CD_WRITE =>
                  byteStep    <= byteStep + 1;
                  bus_cd_addr <= addressData_buf(3 downto 2) & byteStep;
                  case (byteStep) is
                     when "00" => if (writeMask_buf(0) = '1') then bus_cd_write <= '1'; bus_cd_dataWrite <= dataWrite_buf( 7 downto  0); end if;
                     when "01" => if (writeMask_buf(1) = '1') then bus_cd_write <= '1'; bus_cd_dataWrite <= dataWrite_buf(15 downto  8); end if;
                     when "10" => if (writeMask_buf(2) = '1') then bus_cd_write <= '1'; bus_cd_dataWrite <= dataWrite_buf(23 downto 16); end if;
                     when "11" => if (writeMask_buf(3) = '1') then bus_cd_write <= '1'; bus_cd_dataWrite <= dataWrite_buf(31 downto 24); end if;  state <= BUSACTION; 
                     when others => null;
                  end case;
                  
               when CD_READ_WAIT =>
                  state <= CD_READ;
                  
               when CD_READ =>
                  state       <= CD_READ_WAIT;
                  byteStep    <= byteStep + 1;
                  bus_cd_addr <= bus_cd_addr + 1;
                  case (byteStep) is
                     when "00" => 
                        data_cd( 7 downto  0) <= bus_cd_dataRead; 
                        if (reqsize_buf = "00") then 
                           state <= BUSACTION; 
                        else
                           bus_cd_read <= '1';
                        end if;
                        
                     when "01" => 
                        data_cd(15 downto  8) <= bus_cd_dataRead;
                        if (reqsize_buf = "01") then 
                           state <= BUSACTION; 
                        else
                           bus_cd_read <= '1';
                        end if;
                        
                     when "10" => 
                        data_cd(23 downto 16) <= bus_cd_dataRead;
                        bus_cd_read <= '1';
                        
                     when "11" => 
                        data_cd(31 downto 24) <= bus_cd_dataRead;
                        state <= BUSACTION; 
                        
                     when others => null;
                  end case;  
                  
               -- SPU
               when SPU_WRITE =>  -- todo: single byte write is special
                  byteStep    <= byteStep + 2;
                  bus_spu_addr <= addressData_buf(9 downto 2) & byteStep;
                  case (byteStep) is
                     when "00" => if (writeMask_buf(1 downto 0) /= "00") then bus_spu_write <= '1'; bus_spu_dataWrite <= dataWrite_buf(15 downto  0); end if;
                     when "10" => if (writeMask_buf(3 downto 2) /= "00") then bus_spu_write <= '1'; bus_spu_dataWrite <= dataWrite_buf(31 downto 16); end if; state <= BUSACTION; 
                     when others => null;
                  end case;
                  
               when SPU_READ_WAIT =>
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     state <= SPU_READ;
                  end if;
                  
               when SPU_READ =>
                  state        <= SPU_READ_WAIT;
                  byteStep     <= byteStep + 2;
                  bus_spu_addr <= bus_spu_addr + 2;
                  case (byteStep) is
                     when "00" => 
                        data_spu(15 downto  0) <= bus_spu_dataRead; 
                        if (reqsize_buf /= "10") then 
                           state <= BUSACTION; 
                        else
                           bus_spu_read <= '1';
                        end if;
                        
                     when "10" => 
                        data_spu(31 downto 16) <= bus_spu_dataRead;
                        state <= BUSACTION; 
                        
                     when others => null;
                  end case;  
                  
               when WAITING =>
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     mem_done_buf <= '1';
                     state        <= IDLE;
                  end if;
                  
-- #################################################
-- ##################### EXE loading 
-- #################################################
                
               when EXEREADHEADER =>
                  ram_ena    <= '1';
                  ram_128    <= '1';
                  ram_rnw    <= '1';
                  ram_Adr    <= "10" & std_logic_vector(to_unsigned(16#10#, 21));
                  state      <= EXEREADHEADER1;
                  exestep    <= 0;
                  execopycnt <= (others => '0');
                  
               when EXEREADHEADER1 =>
                  if (ram_done = '1') then
                     ram_ena <= '1';
                     ram_Adr <= "10" & std_logic_vector(to_unsigned(16#30#, 21));
                     state   <= EXEREADHEADER2;
                     
                     exe_initial_pc   <= unsigned(ram_dataRead( 31 downto  0));
                     exe_initial_gp   <= unsigned(ram_dataRead( 63 downto 32));
                     exe_load_address <= unsigned(ram_dataRead( 95 downto 64));
                     exe_file_size    <= unsigned(ram_dataRead(127 downto 96));
                  end if;
                  
               when EXEREADHEADER2 =>
                  if (ram_done = '1') then
                     state   <= EXEPATCHBIOSWRITE;
                     
                     exe_stackpointer <= unsigned(ram_dataRead(31 downto 0)) + unsigned(ram_dataRead(63 downto 32));
                     exe_file_size    <= (exe_file_size + 3);
                  end if;
                  
               when EXEPATCHBIOSWRITE =>
                  state   <= EXEPATCHBIOSWAIT;
                  ram_ena <= '1';
                  ram_rnw <= '0';
                  ram_be  <= "1111";
                  case (exestep) is
                     -- load PC
                     when 0 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#6FF0#, 21)); ram_dataWrite <= x"3C08" & std_logic_vector(exe_initial_pc(31 downto 16));
                     when 1 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#6FF4#, 21)); ram_dataWrite <= x"3508" & std_logic_vector(exe_initial_pc(15 downto  0));
                     when 2 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#6FF8#, 21)); ram_dataWrite <= x"3C1C" & std_logic_vector(exe_initial_gp(31 downto 16));
                     when 3 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#6FFC#, 21)); ram_dataWrite <= x"379C" & std_logic_vector(exe_initial_gp(15 downto  0));
                     -- load sp
                     when 4 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#7000#, 21)); ram_dataWrite <= x"3C1D" & std_logic_vector(exe_stackpointer(31 downto 16));
                     when 5 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#7004#, 21)); ram_dataWrite <= x"37BD" & std_logic_vector(exe_stackpointer(15 downto  0));
                     -- load fp
                     when 6 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#7008#, 21)); ram_dataWrite <= x"3C1E" & std_logic_vector(exe_stackpointer(31 downto 16));
                     when 7 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#700C#, 21)); ram_dataWrite <= x"01000008";
                     when 8 => ram_Adr <= "01" & std_logic_vector(to_unsigned(16#7010#, 21)); ram_dataWrite <= x"37DE" & std_logic_vector(exe_stackpointer(15 downto  0));
                     when others => null;
                  end case;
                  if (exe_stackpointer = 0 and (exestep = 4 or exestep = 5 or exestep = 6 or exestep = 8)) then
                     ram_dataWrite <= (others => '0');
                  end if;
                  
                  if (exestep < 8) then
                     state   <= EXEPATCHBIOSWAIT;
                     exestep <= exestep + 1;
                  else
                     state <= EXECOPYREAD;
                  end if;
                  
               when EXEPATCHBIOSWAIT =>
                  if (ram_done = '1') then
                     state   <= EXEPATCHBIOSWRITE;
                  end if;
                  
               when EXECOPYREAD =>
                  if (ram_done = '1') then
                     if (execopycnt >= exe_file_size) then
                        state           <= IDLE;
                        reset_exe       <= '1';
                        loadExe_latched <= '0';
                     else
                        state      <= EXECOPYWRITE;
                        ram_ena    <= '1';
                        ram_rnw    <= '1';
                        ram_128    <= '0';
                        ram_Adr    <= "10" & std_logic_vector(to_unsigned(16#800#, 21) + execopycnt(20 downto 0));
                     end if;
                  end if;
                  
               when EXECOPYWRITE =>
                  if (ram_done = '1') then
                     state         <= EXECOPYREAD;
                     ram_ena       <= '1';
                     ram_rnw       <= '0';
                     ram_Adr       <= "00" & std_logic_vector(exe_load_address(20 downto 0) + execopycnt(20 downto 0));
                     ram_dataWrite <= ram_dataRead(31 downto 0);
                     execopycnt    <= execopycnt + 4;
                  end if;
                  
               when others => null;
            
            end case;
            
         else
         
            case (state) is
               when IDLE =>
                  if (SS_wren_SDRam = '1') then
                     ram_ena       <= '1';
                     ram_128       <= '0';
                     ram_rnw       <= '0';
                     ram_Adr       <= "00" & std_logic_vector(SS_Adr(18 downto 0)) & "00";
                     ram_be        <= "1111";
                     ram_dataWrite <= SS_DataWrite;
                  end if;
                  if (SS_rden_SDRam = '1') then
                     ram_ena       <= '1';
                     ram_128       <= '0';
                     ram_rnw       <= '1';
                     ram_Adr       <= "00" & std_logic_vector(SS_Adr(18 downto 0)) & "00";
                  end if;
            
               when others => null;
            end case;

         end if;
      end if;
   end process;
   
--##############################################################
--############################### debug
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (reset = '1') then
         
            stallcountRead    <= 0;
            stallcountWrite   <= 0;
            stallcountWriteF  <= 0;
            stallcountIntBus  <= 0;
      
         elsif (ce = '1') then
         
            if (stallcountRead = 0 and stallcountWrite = 0 and stallcountIntBus = 0 and stallcountWriteF = 0) then
               stallcountRead <= 0;
            end if;
            
            if (readram = '1') then
               stallcountRead <= stallcountRead + 1;
            end if;            
            
            if (writeram = '1' or instantwrite = '1') then
               stallcountWrite <= stallcountWrite + 1;
               if (addressDataF = '1') then
                  stallcountWriteF <= stallcountWriteF + 1;
               end if;
            end if;
            
            if (mem_request = '1') then
               addressDataF <= '0';
               if (mem_addressData(30) = '0' and mem_rnw = '0' and mem_addressData(28 downto 0) < 16#800000#) then
                  addressDataF <= '1';
               end if;
            end if;
            
            if (state = BUSACTION or state = SPU_WRITE or state = SPU_READ or state = SPU_READ_WAIT or state = CD_READ or state = CD_READ_WAIT or state = CD_WRITE) then
               stallcountIntBus <= stallcountIntBus + 1;
            end if;
            
         end if;
      end if;
   end process;
   

end architecture;





