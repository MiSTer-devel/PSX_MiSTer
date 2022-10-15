library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity memorymux is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      loadExe              : in  std_logic;
      exe_initial_pc       : in  unsigned(31 downto 0);
      exe_initial_gp       : in  unsigned(31 downto 0);
      exe_load_address     : in  unsigned(31 downto 0);
      exe_file_size        : in  unsigned(31 downto 0);
      exe_stackpointer     : in  unsigned(31 downto 0);
      reset_exe            : out std_logic := '0';
      
      fastboot             : in  std_logic;
      PATCHSERIAL          : in  std_logic;
      TURBO                : in  std_logic;
      region_in            : in  std_logic_vector(1 downto 0);
      
      isIdle               : out std_logic;
      
      ram_dataWrite        : out std_logic_vector(31 downto 0) := (others => '0');
      ram_dataRead         : in  std_logic_vector(31 downto 0);
      ram_Adr              : out std_logic_vector(24 downto 0) := (others => '0');
      ram_be               : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw              : out std_logic := '0';
      ram_ena              : out std_logic := '0';
      ram_cache            : out std_logic := '0';
      ram_done             : in  std_logic;
      
      mem_in_request       : in  std_logic;
      mem_in_rnw           : in  std_logic; 
      mem_in_isData        : in  std_logic; 
      mem_in_isCache       : in  std_logic;
      mem_in_oldtagvalids  : in  std_logic_vector(3 downto 0);      
      mem_in_addressInstr  : in  unsigned(31 downto 0); 
      mem_in_addressData   : in  unsigned(31 downto 0); 
      mem_in_reqsize       : in  unsigned(1 downto 0); 
      mem_in_writeMask     : in  std_logic_vector(3 downto 0); 
      mem_in_dataWrite     : in  std_logic_vector(31 downto 0); 
      mem_dataRead         : out std_logic_vector(31 downto 0); 
      mem_done             : out std_logic;
      mem_fifofull         : out std_logic;
      mem_tagvalids        : out std_logic_vector(3 downto 0);
      
      bios_memctrl         : in  unsigned(13 downto 0);
      
      ex1_memctrl          : in  unsigned(13 downto 0);
      --bus_exp1_addr        : out unsigned(22 downto 0); 
      --bus_exp1_dataWrite   : out std_logic_vector(7 downto 0);
      bus_exp1_read        : out std_logic;
      --bus_exp1_write       : out std_logic;
      bus_exp1_dataRead    : in  std_logic_vector(7 downto 0);
      
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
      
      cd_memctrl           : in  unsigned(13 downto 0);
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
      bus_gpu_stall        : in  std_logic;
      
      bus_mdec_addr        : out unsigned(3 downto 0); 
      bus_mdec_dataWrite   : out std_logic_vector(31 downto 0);
      bus_mdec_read        : out std_logic;
      bus_mdec_write       : out std_logic;
      bus_mdec_dataRead    : in  std_logic_vector(31 downto 0);
      
      spu_memctrl          : in  unsigned(13 downto 0);
      bus_spu_addr         : out unsigned(9 downto 0) := (others => '0'); 
      bus_spu_dataWrite    : out std_logic_vector(15 downto 0);
      bus_spu_read         : out std_logic;
      bus_spu_write        : out std_logic;
      bus_spu_dataRead     : in  std_logic_vector(15 downto 0);
      
      ex2_memctrl          : in  unsigned(13 downto 0);
      bus_exp2_addr        : out unsigned(12 downto 0); 
      bus_exp2_dataWrite   : out std_logic_vector(7 downto 0);
      bus_exp2_read        : out std_logic;
      bus_exp2_write       : out std_logic;
      bus_exp2_dataRead    : in  std_logic_vector(7 downto 0);
      
      ex3_memctrl          : in  unsigned(13 downto 0);
      --bus_exp3_dataWrite   : out std_logic_vector(7 downto 0);
      bus_exp3_read        : out std_logic;
      --bus_exp3_write       : out std_logic;
      bus_exp3_dataRead    : in  std_logic_vector(15 downto 0);
      
      com0_delay           : in  unsigned(3 downto 0);
      com1_delay           : in  unsigned(3 downto 0);
      com2_delay           : in  unsigned(3 downto 0);
      com3_delay           : in  unsigned(3 downto 0);
      
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
      WAITFORRAMREAD,
      WAITFORRAMWRITE,
      READBIOS,
      BUSWRITE,
      BUSWRITEEXTERNAL,
      BUSREADEXTERNAL,
      BUSREADREQUEST,
      BUSREAD, 
      WAITING,
      
      EXEPATCHBIOSWRITE,
      EXEPATCHBIOSWAIT,
      EXECOPYREAD,
      EXECOPYWRITE
   );
   signal state                  : tState := IDLE;
      
   signal mem_request            : std_logic;
   signal mem_rnw                : std_logic; 
   signal mem_isData             : std_logic; 
   signal mem_isCache            : std_logic; 
   signal mem_oldtagvalids       : std_logic_vector(3 downto 0);
   signal mem_addressInstr       : unsigned(31 downto 0); 
   signal mem_addressData        : unsigned(31 downto 0); 
   signal mem_reqsize            : unsigned(1 downto 0); 
   signal mem_writeMask          : std_logic_vector(3 downto 0); 
   signal mem_dataWrite          : std_logic_vector(31 downto 0); 
   
   signal mem_save_request       : std_logic := '0'; 
   signal mem_save_rnw           : std_logic := '0'; 
   signal mem_save_isData        : std_logic := '0'; 
   signal mem_save_isCache       : std_logic := '0'; 
   signal mem_save_oldtagvalids  : std_logic_vector(3 downto 0) := (others => '0');
   signal mem_save_addressInstr  : unsigned(31 downto 0) := (others => '0'); 
   signal mem_save_addressData   : unsigned(31 downto 0) := (others => '0');
   signal mem_save_reqsize       : unsigned(1 downto 0) := (others => '0'); 
   signal mem_save_writeMask     : std_logic_vector(3 downto 0) := (others => '0');
   signal mem_save_dataWrite     : std_logic_vector(31 downto 0) := (others => '0'); 
   
   signal writeFifo_Din          : std_logic_vector(69 downto 0);
   signal writeFifo_Wr           : std_logic; 
   signal writeFifo_NearFull     : std_logic; 
   signal writeFifo_Dout         : std_logic_vector(69 downto 0);
   signal writeFifo_Rd           : std_logic;
   signal writeFifo_Empty        : std_logic;
   signal writeFifo_busy         : std_logic;
   signal writeFifo_Wr_1         : std_logic;
   
   signal bios_page_open         : std_logic;
   signal ram_page_open          : std_logic;
   signal ram_page_addr          : unsigned(10 downto 0);
   signal ram_load_last          : integer range 0 to 7 := 0;
   
   signal waitcnt                : integer range 0 to 127;
         
   signal mem_dataRead_buf       : std_logic_vector(31 downto 0);
   signal mem_done_buf           : std_logic := '0';
         
   signal readram                : std_logic := '0';
   signal writeram               : std_logic := '0';
         
   signal data_ram               : std_logic_vector(31 downto 0);
   signal data_ram_rotate        : std_logic_vector(31 downto 0);
   signal ram_rotate_bits        : std_logic_vector(1 downto 0);
   signal region                 : std_logic_vector(1 downto 0);
            
   signal addressData_buf        : unsigned(31 downto 0);
   signal dataWrite_buf          : std_logic_vector(31 downto 0);
   signal reqsize_buf            : unsigned(1 downto 0);   
   signal writeMask_buf          : std_logic_vector(3 downto 0);
            
   signal addressBIOS_buf        : unsigned(18 downto 0);
            
   signal bus_stall              : std_logic;
   signal dataFromBusses         : std_logic_vector(31 downto 0);
   signal rotate32               : std_logic;
   signal rotate16               : std_logic;
         
   -- EXE handling      
   signal loadExe_latched        : std_logic := '0';
   signal exestep                : integer range 0 to 8;
   signal execopycnt             : unsigned(31 downto 0);
   
   -- external busses
   type tExtState is
   (
      EXT_IDLE,
      EXE_WRITE_PREWAIT,
      EXT_WRITE,
      EXT_WRITE_WAIT,
      EXT_READ_NEXT,
      EXT_READ,
      EXT_READ_WAIT
   );
   signal ext_state              : tExtState := EXT_IDLE; 
   
   signal ext_done               : std_logic := '0';
   signal ext_finished           : std_logic := '0';
   signal ext_lastactive         : std_logic := '0';
   signal ext_recovered          : std_logic := '0';
   signal ext_data               : std_logic_vector(31 downto 0);
   signal ext_data_new           : std_logic_vector(31 downto 0);
   signal ext_dataWrite_buf      : std_logic_vector(31 downto 0);
   signal ext_writeMask_buf      : std_logic_vector(3 downto 0);
   
   signal ext_bus_addr           : unsigned(12 downto 0) := (others => '0'); 
   
   signal ext_memctrl            : unsigned(13 downto 0);
   signal ext_memctrl_WDelay     : unsigned(3 downto 0);
   signal ext_memctrl_RDelay     : unsigned(3 downto 0);
   signal ext_memctrl_RecP       : std_logic;
   signal ext_memctrl_Hold       : std_logic;
   signal ext_memctrl_Float      : std_logic;
   signal ext_memctrl_PStrobe    : std_logic;
   signal ext_memctrl_width      : std_logic;
   signal ext_memctrl_autoinc    : std_logic;
   signal ext_byteStep           : unsigned(1 downto 0);
   signal ext_waitcnt            : integer range 0 to 63;
   signal ext_reccount           : integer range 0 to 31;
   signal ext_write_ena          : std_logic;
   signal ext_dataWrite          : std_logic_vector(15 downto 0);
   
   signal ext_select_spu         : std_logic := '0';
   signal ext_select_spu_saved   : std_logic := '0';   
   signal ext_select_cd          : std_logic := '0';
   signal ext_select_cd_saved    : std_logic := '0';
   signal ext_select_ex1         : std_logic := '0';
   signal ext_select_ex1_saved   : std_logic := '0';   
   signal ext_select_ex2         : std_logic := '0';
   signal ext_select_ex2_saved   : std_logic := '0';   
   signal ext_select_ex3         : std_logic := '0';
   signal ext_select_ex3_saved   : std_logic := '0';     
         
   -- debug    
   signal stallcountRead         : integer;
   signal stallcountReadC        : integer;
   signal stallcountWrite        : integer;
   signal stallcountWriteF       : integer;
   signal stallcountIntBus       : integer;
         
   signal addressDataF           : std_logic := '0';
   
begin 

   isIdle <= '1' when (state = IDLE and readram = '0' and writeram = '0' and writeFifo_busy = '0' and mem_save_request = '0') else '0';

   process (state, addressData_buf, writeMask_buf, dataWrite_buf)
      variable address  : unsigned(28 downto 0);
      variable enableRead  : std_logic;
      variable enableWrite : std_logic;
   begin
   
      address := addressData_buf(28 downto 0);
   
      enableRead  := '0';
      enableWrite := '0';
      if (state = BUSREADREQUEST) then 
         enableRead := '1';
      end if;
      if (state = BUSWRITE) then 
         enableWrite := '1';
      end if;
      
      -- memc
      bus_memc_read      <= '0';
      bus_memc_write     <= '0';
      bus_memc_addr      <= address(5 downto 0);
      bus_memc_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801000# and address < 16#1F801040#) then
         bus_memc_read  <= enableRead;
         bus_memc_write <= enableWrite;
      end if;
      
      -- pad
      bus_pad_read      <= '0';
      bus_pad_write     <= '0';
      bus_pad_addr      <= address(3 downto 0);
      bus_pad_dataWrite <= dataWrite_buf;
      bus_pad_writeMask <= writeMask_buf;
      if (address >= 16#1F801040# and address < 16#1F801050#) then
         bus_pad_read  <= enableRead;
         bus_pad_write <= enableWrite;
      end if;
      
      -- sio
      bus_sio_read      <= '0';
      bus_sio_write     <= '0';
      bus_sio_addr      <= address(3 downto 0);
      bus_sio_dataWrite <= dataWrite_buf;
      bus_sio_writeMask <= writeMask_buf;
      if (address >= 16#1F801050# and address < 16#1F801060#) then
         bus_sio_read  <= enableRead;
         bus_sio_write <= enableWrite;
      end if;
      
      -- memc2
      bus_memc2_read      <= '0';
      bus_memc2_write     <= '0';
      bus_memc2_addr      <= address(3 downto 0);
      bus_memc2_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801060# and address < 16#1F801070#) then
         bus_memc2_read  <= enableRead;
         bus_memc2_write <= enableWrite;
      end if;
      
      -- irq
      bus_irq_read      <= '0';
      bus_irq_write     <= '0';
      bus_irq_addr      <= address(3 downto 0);
      bus_irq_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801070# and address < 16#1F801080#) then
         bus_irq_read  <= enableRead;
         bus_irq_write <= enableWrite;
      end if;
      
      -- dma
      bus_dma_read      <= '0';
      bus_dma_write     <= '0';
      bus_dma_addr      <= address(6 downto 0);
      bus_dma_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801080# and address < 16#1F801100#) then
         bus_dma_read  <= enableRead;
         bus_dma_write <= enableWrite;
      end if;
      
      -- timer
      bus_tmr_read      <= '0';
      bus_tmr_write     <= '0';
      bus_tmr_addr      <= address(5 downto 0);
      bus_tmr_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801100# and address < 16#1F801140#) then
         bus_tmr_read  <= enableRead;
         bus_tmr_write <= enableWrite;
      end if;
      
      -- gpu
      bus_gpu_read      <= '0';
      bus_gpu_write     <= '0';
      bus_gpu_addr      <= address(3 downto 0);
      bus_gpu_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801810# and address < 16#1F801820#) then
         bus_gpu_read  <= enableRead;
         bus_gpu_write <= enableWrite;
      end if;
      
      -- mdec
      bus_mdec_read      <= '0';
      bus_mdec_write     <= '0';
      bus_mdec_addr      <= address(3 downto 0);
      bus_mdec_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801820# and address < 16#1F801830#) then
         bus_mdec_read  <= enableRead;
         bus_mdec_write <= enableWrite;
      end if;

   end process;
   
   bus_stall         <= bus_gpu_stall;
   
   dataFromBusses    <= bus_memc_dataRead or bus_pad_dataRead or bus_sio_dataRead or bus_memc2_dataRead or bus_irq_dataRead or 
                        bus_dma_dataRead or bus_tmr_dataRead or bus_gpu_dataRead or bus_mdec_dataRead;
   
   data_ram          <= ram_dataRead;
  
   data_ram_rotate   <= data_ram                            when ram_rotate_bits(1 downto 0) = "00" else
                        x"00" & data_ram(31 downto 8)       when ram_rotate_bits(1 downto 0) = "01" else
                        x"0000" & data_ram(31 downto 16)    when ram_rotate_bits(1 downto 0) = "10" else
                        x"000000" & data_ram(31 downto 24);
      
   mem_dataRead      <= data_ram_rotate when (readram = '1' and ram_done = '1') else
                        ext_data_new    when (ext_done = '1') else
                        mem_dataRead_buf;
                        
   mem_done          <= '1'            when (readram = '1'  and ram_done = '1') else 
                        '1'            when (ext_done = '1') else 
                        mem_done_buf;
   
   
   -- write fifo
   iwritefifo: entity mem.SyncFifoFallThroughMLAB
   generic map
   (
      SIZE              => 8,
      DATAWIDTH         => 70,
      NEARFULLDISTANCE  => 4,
      NEAREMPTYDISTANCE => 2
   )
   port map
   ( 
      clk         => clk1x,
      reset       => reset,
                  
      Din         => writeFifo_Din,     
      Wr          => writeFifo_Wr,      
      Full        => open,                -- NearFull will stall cpu to have full 4 element size
      NearFull    => writeFifo_NearFull,
            
      Dout        => writeFifo_Dout,     
      Rd          => writeFifo_Rd,   
      Empty       => writeFifo_Empty,
      NearEmpty   => open
   );
   
   writeFifo_Din <= mem_in_writeMask & std_logic_vector(mem_in_reqsize) & std_logic_vector(mem_in_addressData) & mem_in_dataWrite;
   writeFifo_Wr  <= '1' when (ce = '1' and mem_in_request = '1' and mem_in_rnw = '0' and (state /= IDLE or writeFifo_busy = '1' or ((readram = '1' or writeram = '1') and ram_done = '0'))) else '0';
   
   writeFifo_Rd  <= '1' when (ce = '1' and state = IDLE and writeFifo_Empty = '0' and ((readram = '0' and writeram = '0') or ram_done = '1')) else '0';
   
   mem_fifofull  <= writeFifo_NearFull;
   
   -- input muxing with buffer and writefifo
   mem_request      <= mem_in_request or mem_save_request;
   mem_rnw          <= '0'                                    when writeFifo_Empty = '0' else mem_save_rnw          when mem_save_request = '1' else mem_in_rnw         ;
   mem_isData       <= '1'                                    when writeFifo_Empty = '0' else mem_save_isData       when mem_save_request = '1' else mem_in_isData      ;
   mem_isCache      <= '0'                                    when writeFifo_Empty = '0' else mem_save_isCache      when mem_save_request = '1' else mem_in_isCache     ;
   mem_oldtagvalids <= "0000"                                 when writeFifo_Empty = '0' else mem_save_oldtagvalids when mem_save_request = '1' else mem_in_oldtagvalids; 
   mem_addressInstr <= unsigned(writeFifo_Dout(63 downto 32)) when writeFifo_Empty = '0' else mem_save_addressInstr when mem_save_request = '1' else mem_in_addressInstr;
   mem_addressData  <= unsigned(writeFifo_Dout(63 downto 32)) when writeFifo_Empty = '0' else mem_save_addressData  when mem_save_request = '1' else mem_in_addressData ;
   mem_reqsize      <= unsigned(writeFifo_Dout(65 downto 64)) when writeFifo_Empty = '0' else mem_save_reqsize      when mem_save_request = '1' else mem_in_reqsize     ;
   mem_writeMask    <= writeFifo_Dout(69 downto 66)           when writeFifo_Empty = '0' else mem_save_writeMask    when mem_save_request = '1' else mem_in_writeMask   ;
   mem_dataWrite    <= writeFifo_Dout(31 downto  0)           when writeFifo_Empty = '0' else mem_save_dataWrite    when mem_save_request = '1' else mem_in_dataWrite   ;
  
   process (clk1x)
      variable biosPatch  : std_logic_vector(31 downto 0);
   begin
      if rising_edge(clk1x) then
      
         ram_ena              <= '0';
         mem_done_buf         <= '0';
         reset_exe            <= '0';
         
         if (loadExe = '1') then
            loadExe_latched <= '1';
         end if;
         
         if (ram_done = '1') then
            readram  <= '0';
            writeram <= '0';
         end if;
      
         if (ram_load_last > 0) then
            ram_load_last <= ram_load_last - 1;
         end if;
      
         if (reset = '1') then

            state            <= IDLE;
            region           <= region_in;
            mem_save_request <= '0';
            writeFifo_busy   <= '0';
            ram_page_open    <= '0';
            ext_lastactive   <= '0';

         elsif (ce = '1') then
         
            if (mem_in_request = '1' and mem_in_rnw = '1') then
               mem_save_request      <= '1';
               mem_save_rnw          <= '1';         
               mem_save_isData       <= mem_in_isData;
               mem_save_isCache      <= mem_in_isCache;     
               mem_save_oldtagvalids <= mem_in_oldtagvalids;     
               mem_save_addressInstr <= mem_in_addressInstr;
               mem_save_addressData  <= mem_in_addressData; 
               mem_save_reqsize      <= mem_in_reqsize;     
               mem_save_writeMask    <= mem_in_writeMask;   
               mem_save_dataWrite    <= mem_in_dataWrite;   
            end if;
            
            writeFifo_Wr_1 <= writeFifo_Wr;
            if (writeFifo_Wr = '1') then
               writeFifo_busy <= '1';
            elsif (writeFifo_Wr_1 = '0' and writeFifo_Empty = '1') then
               writeFifo_busy <= '0';
            end if;
          
            case (state) is
               when IDLE =>

                  addressData_buf <= mem_addressData;
                  dataWrite_buf   <= mem_dataWrite;
                  reqsize_buf     <= mem_reqsize;
                  writeMask_buf   <= mem_writeMask;
                  
                  if (loadExe_latched = '1') then
                     
                     state      <= EXEPATCHBIOSWRITE;
                     exestep    <= 0;
                     execopycnt <= (others => '0');
               
                  elsif (((readram = '0' and writeram = '0') or ram_done = '1') and ((mem_request = '1' and writeFifo_busy = '0') or writeFifo_Empty = '0')) then
                  
                     if (mem_request = '1' and writeFifo_busy = '0') then
                        mem_save_request <= '0';
                     end if;
                  
                     readram  <= '0';
                     writeram <= '0';
                     
                     ram_page_open  <= '0';
                     bios_page_open <= '0';
                  
                     if (mem_isData = '0') then
               
                        if (mem_addressInstr(28 downto 0) < 16#800000#) then -- RAM
                           ram_ena     <= '1';
                           ram_cache   <= mem_isCache;
                           ram_rnw     <= '1';
                           ram_Adr     <= "00" & std_logic_vector(mem_addressInstr(22 downto 2)) & "00";
                           state       <= IDLE;
                           readram     <= '1';
                           ram_rotate_bits <= "00";
                           if (mem_isCache = '0') then
                              if (TURBO = '0') then
                                 state   <= WAITFORRAMREAD;
                                 waitcnt <= 0;
                                 ram_ena <= '0';
                                 readram <= '0';
                              end if;
                           end if;
                           
                           case (mem_addressInstr(3 downto 2)) is
                              when "00" => mem_tagvalids <= "1111";
                              when "01" => mem_tagvalids <= "1110";
                              when "10" => mem_tagvalids <= "1100";
                              when "11" => mem_tagvalids <= "1000";
                              when others => null;
                           end case;
                           
                        elsif (mem_addressInstr(28 downto 0) >= 16#1FC00000# and mem_addressInstr(28 downto 0) < 16#1FC80000#) then -- BIOS
                           ram_ena         <= '1';
                           ram_cache       <= '0';
                           ram_rnw         <= '1';
                           ram_Adr         <= "01" & "00" & region & std_logic_vector(mem_addressInstr(18 downto 2)) & "00";
                           state           <= READBIOS;
                           addressBIOS_buf <= mem_addressInstr(18 downto 0);
                           ram_rotate_bits <= "00";
                           if (bios_page_open = '1') then
                              waitcnt        <= 25;
                           else
                              waitcnt        <= 26;
                              bios_page_open <= '1';
                           end if;
                           
                           mem_tagvalids <= mem_oldtagvalids;
                           case (mem_addressInstr(3 downto 2)) is
                              when "00" => mem_tagvalids(0) <= '1';
                              when "01" => mem_tagvalids(1) <= '1';
                              when "10" => mem_tagvalids(2) <= '1';
                              when "11" => mem_tagvalids(3) <= '1';
                              when others => null;
                           end case;
                        else
                           report "should never happen" severity failure; 
                        end if;
            
                     else
                     
                        if (mem_addressData(28 downto 0) < 16#800000#) then -- RAM
                           ext_lastactive  <= '0';
                           ram_cache       <= '0';
                           ram_rnw         <= mem_rnw;
                           ram_Adr         <= "00" & std_logic_vector(mem_addressData(22 downto 2)) & "00";
                           ram_rotate_bits <= std_logic_vector(mem_addressData(1 downto 0));
                           if (mem_rnw = '1') then
                              ram_load_last <= 7;
                              if (TURBO = '1' or ram_load_last > 0) then
                                 state   <= IDLE;
                                 ram_ena <= '1';
                                 readram <= '1';
                              else
                                 state   <= WAITFORRAMREAD;
                                 waitcnt <= 0;
                              end if;
                           else
                              ram_page_open <= '1';
                              ram_page_addr <= mem_addressData(20 downto 10);
                              if (TURBO = '1' or (ram_page_open = '1' and mem_addressData(20 downto 10) = ram_page_addr)) then
                                 state    <= IDLE;
                                 ram_ena  <= '1';
                                 writeram <= '1';
                              else
                                 state   <= WAITFORRAMWRITE;
                                 waitcnt <= 0;
                                 if (ram_page_open = '1' and mem_addressData(20 downto 10) /= ram_page_addr) then
                                    waitcnt <= 3;
                                 end if;
                              end if;
                           end if;
                           ram_be        <= mem_writeMask;
                           ram_dataWrite <= mem_dataWrite;
                        elsif (mem_rnw = '1' and mem_addressData(28 downto 0) >= 16#1FC00000# and mem_addressData(28 downto 0) < 16#1FC80000#) then -- BIOS
                           ram_ena         <= '1';
                           ram_cache       <= '0';
                           ram_rnw         <= '1';
                           ram_Adr         <= "01" & "00" & region & std_logic_vector(mem_addressData(18 downto 2)) & "00";
                           ram_rotate_bits <= std_logic_vector(mem_addressData(1 downto 0));
                           state           <= READBIOS;
                           addressBIOS_buf <= mem_addressData(18 downto 0);
                           case (mem_reqsize) is
                              when "00" => waitcnt <= 1;
                              when "01" => waitcnt <= 9;
                              when "10" => waitcnt <= 25;
                              when others => null;
                           end case;
                        else
                           ext_select_spu <= '0';
                           ext_select_cd  <= '0';
                           ext_select_ex1 <= '0';
                           ext_select_ex2 <= '0';
                           ext_select_ex3 <= '0';
                           if (mem_addressData(28 downto 0) >= 16#1F801800# and mem_addressData(28 downto 0) < 16#1F801810#) then
                              ext_select_cd <= '1';
                              if (mem_rnw = '1') then
                                 state    <= BUSREADEXTERNAL;
                              else
                                 state    <= BUSWRITEEXTERNAL;
                              end if;
                           elsif (mem_addressData(28 downto 0) >= 16#1F801C00# and mem_addressData(28 downto 0) < 16#1F802000#) then
                              ext_select_spu <= '1';
                              if (mem_rnw = '1') then
                                 state    <= BUSREADEXTERNAL;
                              else
                                 state    <= BUSWRITEEXTERNAL;
                              end if;
                           elsif (mem_addressData(28 downto 0) >= 16#1F000000# and mem_addressData(28 downto 0) < 16#1F800000#) then
                              ext_select_ex1 <= '1';
                              if (mem_rnw = '1') then
                                 state    <= BUSREADEXTERNAL;
                              else
                                 state    <= BUSWRITEEXTERNAL;
                              end if;                 
                           elsif (mem_addressData(28 downto 0) >= 16#1F802000# and mem_addressData(28 downto 0) < 16#1F804000#) then
                              ext_select_ex2 <= '1';
                              if (mem_rnw = '1') then
                                 state    <= BUSREADEXTERNAL;
                              else
                                 state    <= BUSWRITEEXTERNAL;
                              end if;                           
                           elsif (mem_addressData(28 downto 0) = 16#1FA00000#) then
                              ext_select_ex3 <= '1';
                              if (mem_rnw = '1') then
                                 state    <= BUSREADEXTERNAL;
                              else
                                 state    <= BUSWRITEEXTERNAL;
                              end if;
                           else  
                              ext_lastactive <= '0';
                              if (mem_rnw = '0') then
                                 state   <= BUSWRITE;
                              else
                                 state   <= BUSREADREQUEST;
                                 waitcnt <= 0;
                              end if;
                           end if;
                        end if;
            
                     end if;
                     
                  end if;        

               when WAITFORRAMREAD =>
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     state   <= IDLE;
                     ram_ena <= '1';
                     readram <= '1';
                  end if;
                  
               when WAITFORRAMWRITE =>
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     state   <= IDLE;
                     ram_ena  <= '1';
                     writeram <= '1';
                  end if;
                  
               when READBIOS =>
                  if (ram_done = '1') then
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
                        mem_dataRead_buf <= data_ram_rotate;
                     end if;
                        
                     state    <= WAITING;
                  end if;
                  
               when BUSWRITE => 
                  state        <= IDLE;               
                  
               when BUSWRITEEXTERNAL => 
                  if (ext_state = EXT_IDLE) then
                     state          <= IDLE;
                  end if;
                  
               when BUSREADEXTERNAL => 
                  if (ext_done = '1') then
                     state          <= IDLE;
                     ext_lastactive <= '1';
                  end if;
                  
               when BUSREADREQUEST =>
                  state <= BUSREAD;
                  rotate32       <= '0';
                  rotate16       <= '0';
                  if (bus_memc_read  = '1') then rotate32 <= '1'; end if;
                  if (bus_pad_read   = '1') then rotate16 <= '1'; end if;
                  if (bus_sio_read   = '1') then rotate16 <= '1'; end if;
                  if (bus_memc2_read = '1') then rotate32 <= '1'; end if;
                  if (bus_dma_read   = '1') then rotate32 <= '1'; end if;
                  if (bus_tmr_read   = '1') then rotate32 <= '1'; end if;
                  if (bus_irq_read   = '1') then rotate32 <= '1'; end if;
                  if (bus_gpu_read   = '1') then rotate32 <= '1'; end if;
                  if (bus_mdec_read  = '1') then rotate32 <= '1'; end if;
                  
               when BUSREAD =>
                  if (bus_stall = '0') then
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
                  end if;
                  
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
                  
               when EXEPATCHBIOSWRITE =>
                  state       <= EXEPATCHBIOSWAIT;
                  ram_ena     <= '1';
                  ram_cache   <= '0';
                  ram_rnw     <= '0';
                  ram_be      <= "1111";
                  case (exestep) is
                     -- load PC
                     when 0 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#6FF0#, 19)); ram_dataWrite <= x"3C08" & std_logic_vector(exe_initial_pc(31 downto 16));
                     when 1 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#6FF4#, 19)); ram_dataWrite <= x"3508" & std_logic_vector(exe_initial_pc(15 downto  0));
                     when 2 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#6FF8#, 19)); ram_dataWrite <= x"3C1C" & std_logic_vector(exe_initial_gp(31 downto 16));
                     when 3 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#6FFC#, 19)); ram_dataWrite <= x"379C" & std_logic_vector(exe_initial_gp(15 downto  0));
                     -- load sp                       
                     when 4 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#7000#, 19)); ram_dataWrite <= x"3C1D" & std_logic_vector(exe_stackpointer(31 downto 16));
                     when 5 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#7004#, 19)); ram_dataWrite <= x"37BD" & std_logic_vector(exe_stackpointer(15 downto  0));
                     -- load fp                       
                     when 6 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#7008#, 19)); ram_dataWrite <= x"3C1E" & std_logic_vector(exe_stackpointer(31 downto 16));
                     when 7 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#700C#, 19)); ram_dataWrite <= x"01000008";
                     when 8 => ram_Adr <= "01" & "00" & region & std_logic_vector(to_unsigned(16#7010#, 19)); ram_dataWrite <= x"37DE" & std_logic_vector(exe_stackpointer(15 downto  0));
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
                     if (execopycnt >= (exe_file_size + 3)) then
                        state           <= IDLE;
                        reset_exe       <= '1';
                        loadExe_latched <= '0';
                     else
                        state      <= EXECOPYWRITE;
                        ram_ena    <= '1';
                        ram_rnw    <= '1';
                        ram_Adr    <= "10" & std_logic_vector(to_unsigned(16#800#, 23) + execopycnt(22 downto 0));
                     end if;
                  end if;
                  
               when EXECOPYWRITE =>
                  if (ram_done = '1') then
                     state         <= EXECOPYREAD;
                     ram_ena       <= '1';
                     ram_rnw       <= '0';
                     ram_Adr       <= "00" & std_logic_vector(exe_load_address(22 downto 0) + execopycnt(22 downto 0));
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
                     ram_cache     <= '0';
                     ram_rnw       <= '0';
                     ram_Adr       <= "00" & "00" & std_logic_vector(SS_Adr(18 downto 0)) & "00";
                     ram_be        <= "1111";
                     ram_dataWrite <= SS_DataWrite;
                  end if;
                  if (SS_rden_SDRam = '1') then
                     ram_ena       <= '1';
                     ram_cache     <= '0';
                     ram_rnw       <= '1';
                     ram_Adr       <= "00" & "00" & std_logic_vector(SS_Adr(18 downto 0)) & "00";
                  end if;
            
               when others => null;
            end case;

         end if;
      end if;
   end process;
   
--##############################################################
--############################### external busses
--##############################################################
   
   
   ext_memctrl <= spu_memctrl when (ext_select_spu = '1') else
                  cd_memctrl  when (ext_select_cd  = '1') else
                  ex1_memctrl when (ext_select_ex1 = '1') else
                  ex2_memctrl when (ext_select_ex2 = '1') else
                  ex3_memctrl when (ext_select_ex3 = '1') else
                  (others => '0');
   
   
   bus_spu_addr      <= ext_bus_addr(9 downto 0);
   bus_spu_write     <= '1' when (ext_write_ena = '1' and ext_select_spu_saved = '1') else '0';
   bus_spu_read      <= '1' when (ext_state = EXT_READ_NEXT and ext_select_spu_saved = '1') else '0';
   bus_spu_dataWrite <= ext_dataWrite;
   
   bus_cd_addr       <= ext_bus_addr(3 downto 0);
   bus_cd_write      <= '1' when (ext_write_ena = '1' and ext_select_cd_saved = '1') else '0';
   bus_cd_read       <= '1' when (ext_state = EXT_READ_NEXT and ext_select_cd_saved = '1') else '0';
   bus_cd_dataWrite  <= ext_dataWrite(7 downto 0);
   
   bus_exp2_addr      <= ext_bus_addr;
   bus_exp2_write     <= '1' when (ext_write_ena = '1' and ext_select_ex2_saved = '1') else '0';
   bus_exp2_read      <= '1' when (ext_state = EXT_READ_NEXT and ext_select_ex2_saved = '1') else '0';
   bus_exp2_dataWrite <= ext_dataWrite(7 downto 0);
   
   -- busses EXP1+3 are stubs that are working in general, but there is nothing connected to them, so unused parts are not implemented
   bus_exp1_read     <= '1' when (ext_state = EXT_READ_NEXT and ext_select_ex1_saved = '1') else '0';
   bus_exp3_read     <= '1' when (ext_state = EXT_READ_NEXT and ext_select_ex3_saved = '1') else '0';
   
   ext_done          <= '1' when (ext_state = EXT_READ and ext_finished = '1') else '0';
   
   
   process (ext_select_spu_saved, ext_select_cd_saved, ext_select_ex1_saved, ext_select_ex2_saved, ext_select_ex3_saved,
            bus_spu_dataRead, bus_cd_dataRead, bus_exp1_dataRead, bus_exp2_dataRead, bus_exp3_dataRead,
            ext_byteStep, addressData_buf, ext_data)
   begin
   
      ext_data_new <= ext_data;
   
      if (ext_select_spu_saved = '1') then
         case (ext_byteStep) is
            when "00" => 
               if (addressData_buf(0) = '1') then 
                  ext_data_new( 7 downto  0) <= bus_spu_dataRead(15 downto 8); 
               else 
                  ext_data_new(15 downto  0) <= bus_spu_dataRead; 
               end if;
            when "10" => 
               if (addressData_buf(0) = '1') then 
                  ext_data_new(23 downto  8) <= bus_spu_dataRead;
               else 
                  ext_data_new(31 downto 16) <= bus_spu_dataRead; 
               end if;  
            when others => null;
         end case;
      elsif (ext_select_cd_saved = '1') then
         case (ext_byteStep) is
            when "00" => ext_data_new( 7 downto  0) <= bus_cd_dataRead;
            when "01" => ext_data_new(15 downto  8) <= bus_cd_dataRead;
            when "10" => ext_data_new(23 downto 16) <= bus_cd_dataRead;
            when "11" => ext_data_new(31 downto 24) <= bus_cd_dataRead;
            when others => null;
         end case;                 
      elsif (ext_select_ex1_saved = '1') then
         case (ext_byteStep) is
            when "00" => ext_data_new( 7 downto  0) <= bus_exp1_dataRead;
            when "01" => ext_data_new(15 downto  8) <= bus_exp1_dataRead;
            when "10" => ext_data_new(23 downto 16) <= bus_exp1_dataRead;
            when "11" => ext_data_new(31 downto 24) <= bus_exp1_dataRead;
            when others => null;
         end case;
      elsif (ext_select_ex2_saved = '1') then
         case (ext_byteStep) is
            when "00" => ext_data_new( 7 downto  0) <= bus_exp2_dataRead;
            when "01" => ext_data_new(15 downto  8) <= bus_exp2_dataRead;
            when "10" => ext_data_new(23 downto 16) <= bus_exp2_dataRead;
            when "11" => ext_data_new(31 downto 24) <= bus_exp2_dataRead;
            when others => null;
         end case;
      elsif (ext_select_ex3_saved = '1') then
         case (ext_byteStep) is
            when "00" => 
               if (addressData_buf(0) = '1') then 
                  ext_data_new( 7 downto  0) <= bus_exp3_dataRead(15 downto 8); 
               else 
                  ext_data_new(15 downto  0) <= bus_exp3_dataRead; 
               end if;
            when "10" => 
               if (addressData_buf(0) = '1') then 
                  ext_data_new(23 downto  8) <= bus_exp3_dataRead;
               else 
                  ext_data_new(31 downto 16) <= bus_exp3_dataRead; 
               end if;  
            when others => null;
         end case;
      end if;
 
   end process;
   
   
   process (clk1x)
      variable newWait : integer range 0 to 63;
   begin
      if rising_edge(clk1x) then
      
         ext_write_ena        <= '0';
         ext_recovered        <= '0';
         
         if (reset = '1') then

            ext_state     <= EXT_IDLE;
            ext_reccount  <= 0;

         elsif (ce = '1') then
         
            if (ext_reccount > 0) then
               ext_reccount  <= ext_reccount - 1;
               ext_recovered <= '1';
            end if;
         
            case (ext_state) is
            
               when EXT_IDLE =>
                  ext_finished         <= '0';
                  ext_dataWrite_buf    <= dataWrite_buf;
                  ext_writeMask_buf    <= writeMask_buf;
                  ext_byteStep         <= (others => '0');
                  ext_data             <= (others => '0');
                  ext_bus_addr         <= addressData_buf(12 downto 0);
                  
                  ext_select_spu_saved <= ext_select_spu;
                  ext_select_cd_saved  <= ext_select_cd;
                  ext_select_ex1_saved <= ext_select_ex1;
                  ext_select_ex2_saved <= ext_select_ex2;
                  ext_select_ex3_saved <= ext_select_ex3;

                  ext_memctrl_WDelay   <= ext_memctrl(3 downto 0);
                  ext_memctrl_RDelay   <= ext_memctrl(7 downto 4);
                  ext_memctrl_RecP     <= ext_memctrl(8);
                  ext_memctrl_Hold     <= ext_memctrl(9);
                  ext_memctrl_Float    <= ext_memctrl(10);
                  ext_memctrl_PStrobe  <= ext_memctrl(11);
                  ext_memctrl_width    <= ext_memctrl(12);
                  ext_memctrl_autoinc  <= ext_memctrl(13);
                  
                  if (state = BUSWRITEEXTERNAL) then
                  
                     ext_state  <= EXT_WRITE;
                     if (ext_reccount > 1) then
                        ext_state   <= EXE_WRITE_PREWAIT;
                        ext_waitcnt <= ext_reccount - 1;
                     end if;
                     
                     if (ext_memctrl(12) = '0' and writeMask_buf(2 downto 0) = "000") then
                        ext_byteStep                   <= "11";
                        ext_bus_addr(1 downto 0)       <= "11";
                     elsif (writeMask_buf(1 downto 0) = "00") then
                        ext_byteStep                   <= "10";
                        ext_bus_addr(1 downto 0)       <= "10";
                     elsif (ext_memctrl(12) = '0' and writeMask_buf(0) = '0') then
                        ext_byteStep                   <= "01";
                        ext_bus_addr(1 downto 0)       <= "01";
                     end if;

                  elsif (state = BUSREADEXTERNAL and ext_reccount = 0) then
                  
                     newWait := 0;
                     if (ext_lastactive = '1' and ext_recovered = '0') then
                        newWait := 1;
                     end if;
                     if (ext_memctrl(7 downto 4) > 0) then
                        newWait := newWait + to_integer(ext_memctrl(7 downto 4));
                     end if;
                     if (ext_memctrl(11) = '1' and com3_delay > ext_memctrl(7 downto 4)) then -- assumption from cd test! 
                        newWait := newWait + to_integer(com3_delay) - to_integer(ext_memctrl(7 downto 4));
                     end if;
                     ext_waitcnt <= newWait;
                     
                     if (newWait > 0) then
                        ext_state    <= EXT_READ_WAIT;
                     else
                        ext_state    <= EXT_READ_NEXT;
                     end if;
                        
                  end if;
                  
               -- write
               when EXE_WRITE_PREWAIT =>
                  if (ext_waitcnt > 0) then
                     ext_waitcnt    <= ext_waitcnt - 1;
                  else
                     ext_state  <= EXT_WRITE; 
                  end if;
               
               when EXT_WRITE =>
                  case (ext_byteStep) is
                     when "00" => if (ext_writeMask_buf(0) = '1') then ext_write_ena <= '1'; ext_dataWrite <=         ext_dataWrite_buf(15 downto  0); end if;
                     when "01" => if (ext_writeMask_buf(1) = '1') then ext_write_ena <= '1'; ext_dataWrite <= x"00" & ext_dataWrite_buf(15 downto  8); end if;
                     when "10" => if (ext_writeMask_buf(2) = '1') then ext_write_ena <= '1'; ext_dataWrite <=         ext_dataWrite_buf(31 downto 16); end if;
                     when "11" => if (ext_writeMask_buf(3) = '1') then ext_write_ena <= '1'; ext_dataWrite <= x"00" & ext_dataWrite_buf(31 downto 24); end if;
                     when others => null;
                  end case;
                  ext_state   <= EXT_WRITE_WAIT;
                  
                  newWait := to_integer(ext_memctrl_WDelay);
                  if (ext_memctrl_PStrobe = '1' and com3_delay > ext_memctrl_WDelay) then -- assumption from cd test! 
                     newWait := newWait + to_integer(com3_delay) - to_integer(ext_memctrl_WDelay);
                  end if;
                  if (ext_memctrl_Hold = '1') then
                     newWait := newWait + to_integer(com1_delay);
                  end if;
                  ext_waitcnt <= newWait;
                  
                  if (ext_memctrl_width = '0' and ext_byteStep = "11") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '0' and ext_byteStep = "01" and ext_writeMask_buf(3 downto 2) = "00") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '0' and ext_byteStep = "00" and ext_writeMask_buf(3 downto 1) = "000") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '1' and (ext_byteStep = "10" or ext_writeMask_buf(2) = '0')) then
                     ext_finished       <= '1';
                  end if;
                  
                  if (ext_memctrl_RecP = '1') then 
                     if (ext_memctrl_PStrobe = '1') then  -- assumption from cd test! 
                        ext_reccount <= to_integer(com0_delay) + to_integer(ext_memctrl_WDelay);
                     else
                        ext_reccount <= to_integer(com0_delay);
                     end if;
                  end if;
                  
               when EXT_WRITE_WAIT =>
                  if (ext_waitcnt > 0) then
                     ext_waitcnt    <= ext_waitcnt - 1;
                  elsif (ext_finished = '1') then
                     ext_state      <= EXT_IDLE;
                  else
                     
                     if (ext_memctrl_RecP = '1' and com0_delay > 1) then 
                        ext_state   <= EXE_WRITE_PREWAIT;
                        ext_waitcnt <= to_integer(com0_delay) - 2; 
                     else
                        ext_state   <= EXT_WRITE;
                     end if;
                     
                     if (ext_memctrl_width = '1') then
                        ext_byteStep             <= ext_byteStep + 2;
                        if (ext_memctrl_autoinc = '1') then
                           ext_bus_addr(1 downto 0) <= ext_bus_addr(1 downto 0) + 2;
                        end if;
                     else
                        ext_byteStep             <= ext_byteStep + 1;
                        if (ext_memctrl_autoinc = '1') then
                           ext_bus_addr(1 downto 0) <= ext_bus_addr(1 downto 0) + 1;
                        end if;
                     end if;
                  end if;
                  
               -- read
               when EXT_READ_NEXT =>
                  ext_state <= EXT_READ;
                  
                  if (ext_memctrl_width = '0' and ext_byteStep = "11") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '0' and ext_byteStep = "01" and reqsize_buf = "01") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '0' and ext_byteStep = "00" and reqsize_buf = "00") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '1' and (ext_byteStep = "10" or reqsize_buf /= "10")) then
                     ext_finished       <= '1';
                  end if;
                  
                  newWait := 0;
                  if (ext_memctrl_RecP = '1') then 
                     newWait := newWait + to_integer(com0_delay);
                  end if;
                  if (ext_memctrl_Float = '1') then 
                     newWait := newWait + to_integer(com2_delay) + 1;
                  end if;
                  ext_reccount <= newWait;
                  
               when EXT_READ =>
               
                  ext_data <= ext_data_new;
               
                  if (ext_finished = '1') then
                     ext_state      <= EXT_IDLE;
                  else
                  
                     newWait  := to_integer(ext_memctrl_RDelay);
                     if (ext_memctrl_RecP = '1' and com0_delay > 0) then 
                        newWait := newWait + (to_integer(com0_delay) - 1); 
                     end if;
                     if (ext_memctrl_PStrobe = '1') then 
                        if (ext_memctrl_RecP = '0') then
                           newWait := newWait + to_integer(com3_delay);
                        elsif (com3_delay > com0_delay) then
                           newWait := newWait + to_integer(com3_delay) - to_integer(com0_delay);  -- assumption from cd test! 
                        end if;
                     end if;
                     if (ext_memctrl_Float = '1') then 
                        newWait := newWait + to_integer(com2_delay);
                     end if;
                     if (ext_memctrl_RecP = '1' and ext_memctrl_Float = '1') then -- assumption from exp2 read test! 
                        newWait := newWait + 1;
                     end if;
                     ext_waitcnt  <= newWait;
                  
                     if (newWait > 0) then
                        ext_state    <= EXT_READ_WAIT;
                     else
                        ext_state    <= EXT_READ_NEXT;
                     end if;
                     
                     if (ext_memctrl_width = '1') then
                        ext_byteStep             <= ext_byteStep + 2;
                        if (ext_memctrl_autoinc = '1') then
                           ext_bus_addr(1 downto 0) <= ext_bus_addr(1 downto 0) + 2;
                        end if;
                     else
                        ext_byteStep             <= ext_byteStep + 1;
                        if (ext_memctrl_autoinc = '1') then
                           ext_bus_addr(1 downto 0) <= ext_bus_addr(1 downto 0) + 1;
                        end if;
                     end if;
                  end if;
                  
               when EXT_READ_WAIT =>
                  if (ext_waitcnt > 1) then
                     ext_waitcnt <= ext_waitcnt - 1;
                  else
                     ext_state   <= EXT_READ_NEXT;
                  end if;
            
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
            stallcountReadC    <= 0;
            stallcountWrite   <= 0;
            stallcountWriteF  <= 0;
            stallcountIntBus  <= 0;
      
         elsif (ce = '1') then
         
            if (stallcountRead = 0 and stallcountReadC = 0 and stallcountWrite = 0 and stallcountIntBus = 0 and stallcountWriteF = 0) then
               stallcountRead <= 0;
            end if;
            
            if (readram = '1') then
               stallcountRead <= stallcountRead + 1;
               if (ram_cache = '1') then
                  stallcountReadC <= stallcountReadC + 1;
               end if;
            end if;            
            
            if (writeram = '1') then
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
            
            --if (state = BUSREAD or state = BUSWRITE or state = SPU_WRITE or state = SPU_READ or state = SPU_READ_WAIT or state = CD_READ or state = CD_READ_WAIT or state = CD_WRITE) then
            --   stallcountIntBus <= stallcountIntBus + 1;
            --end if;
            
         end if;
      end if;
   end process;
   

end architecture;





