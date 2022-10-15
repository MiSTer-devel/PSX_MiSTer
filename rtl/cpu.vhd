library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    

library mem;

use work.pexport.all;

entity cpu is
   port 
   (
      clk1x                 : in  std_logic;
      clk2x                 : in  std_logic;
      clk3x                 : in  std_logic;
      ce                    : in  std_logic;
      ce_system             : in  std_logic;
      reset                 : in  std_logic;
      
      TURBO                 : in  std_logic;
      TURBO_CACHE           : in  std_logic;
      TURBO_CACHE50         : in  std_logic;
      
      irqRequest            : in  std_logic;
      dmaRequest            : in  std_logic;
      
      error                 : out std_logic := '0';
      error2                : out std_logic := '0';
      
      mem_request           : out std_logic;
      mem_rnw               : out std_logic; 
      mem_isData            : out std_logic; 
      mem_isCache           : out std_logic; 
      mem_oldtagvalids      : out std_logic_vector(3 downto 0);
      mem_addressInstr      : out unsigned(31 downto 0); 
      mem_addressData       : out unsigned(31 downto 0); 
      mem_reqsize           : out unsigned(1 downto 0); 
      mem_writeMask         : out std_logic_vector(3 downto 0); 
      mem_dataWrite         : out std_logic_vector(31 downto 0); 
      mem_dataRead          : in  std_logic_vector(31 downto 0); 
      mem_done              : in  std_logic;
      mem_fifofull          : in  std_logic;
      mem_tagvalids         : in  std_logic_vector(3 downto 0);
      
      cache_wr              : in  std_logic_vector(3 downto 0);
      cache_data            : in  std_logic_vector(31 downto 0);
      cache_addr            : in  std_logic_vector(7 downto 0);
      
      stallNext             : out std_logic;
      
      dma_cache_Adr         : in  std_logic_vector(20 downto 0);
      dma_cache_data        : in  std_logic_vector(31 downto 0);
      dma_cache_write       : in  std_logic;
      
      ram_done              : in  std_logic;
      ram_dataRead          : in  std_logic_vector(31 downto 0); 
      
      gte_busy              : in  std_logic;
      gte_readEna           : out std_logic := '0';
      gte_readAddr          : out unsigned(5 downto 0);
      gte_readData          : in  unsigned(31 downto 0);
      gte_writeAddr         : out unsigned(5 downto 0);
      gte_writeData         : out unsigned(31 downto 0);
      gte_writeEna          : out std_logic := '0'; 
      gte_cmdData           : out unsigned(31 downto 0);
      gte_cmdEna            : out std_logic := '0'; 
      
      SS_reset              : in  std_logic;
      SS_DataWrite          : in  std_logic_vector(31 downto 0);
      SS_Adr                : in  unsigned(7 downto 0);
      SS_wren_CPU           : in  std_logic;
      SS_wren_SCP           : in  std_logic;
      SS_rden_CPU           : in  std_logic;
      SS_rden_SCP           : in  std_logic;
      SS_DataRead_CPU       : out std_logic_vector(31 downto 0);
      SS_DataRead_SCP       : out std_logic_vector(31 downto 0);
      SS_idle               : out std_logic;
   
-- synthesis translate_off
      cpu_done              : out std_logic := '0'; 
      cpu_export            : out cpu_export_type := ((others => (others => '0')), (others => '0'), (others => '0'), (others => '0'));
-- synthesis translate_on
      
      debug_firstGTE        : in  std_logic
   );
end entity;

architecture arch of cpu is
     
   -- register file
   signal regs_address_a               : std_logic_vector(4 downto 0);
   signal regs_data_a                  : std_logic_vector(31 downto 0);
   signal regs_wren_a                  : std_logic;
   signal regs1_address_b              : std_logic_vector(4 downto 0);
   signal regs1_q_b                    : std_logic_vector(31 downto 0);
   signal regs2_address_b              : std_logic_vector(4 downto 0);
   signal regs2_q_b                    : std_logic_vector(31 downto 0);   
   signal regsSS_address_b             : std_logic_vector(4 downto 0) := (others => '0');
   signal regsSS_q_b                   : std_logic_vector(31 downto 0);
   signal regsSS_rden                  : std_logic := '0';
   
   signal ss_regs_loading              : std_logic := '0';
   signal ss_regs_load                 : std_logic := '0';
   signal ss_regs_addr                 : unsigned(4 downto 0);
   signal ss_regs_data                 : std_logic_vector(31 downto 0);
   
   -- other register
   signal PC                           : unsigned(31 downto 0) := (others => '0');
   signal hi                           : unsigned(31 downto 0) := (others => '0');
   signal lo                           : unsigned(31 downto 0) := (others => '0');
               
   signal cop0_BPC                     : unsigned(31 downto 0) := (others => '0');
   signal cop0_BDA                     : unsigned(31 downto 0) := (others => '0');
   signal cop0_JUMPDEST                : unsigned(31 downto 0) := (others => '0');
   signal cop0_DCIC                    : unsigned(31 downto 0) := (others => '0');
   signal cop0_BADVADDR                : unsigned(31 downto 0) := (others => '0');
   signal cop0_BDAM                    : unsigned(31 downto 0) := (others => '0');
   signal cop0_BPCM                    : unsigned(31 downto 0) := (others => '0');
   signal cop0_SR                      : unsigned(31 downto 0) := (others => '0');
   signal cop0_CAUSE                   : unsigned(31 downto 0) := (others => '0');
   signal cop0_EPC                     : unsigned(31 downto 0) := (others => '0');
   signal cop0_PRID                    : unsigned(31 downto 0) := (others => '0');
     
   signal CACHECONTROL                 : unsigned(31 downto 0) := (others => '0');
               
   -- common   
   signal ce_1                         : std_logic := '0';
   
   signal stallNew1                    : std_logic := '0';
   signal stallNew2                    : std_logic := '0';
   signal stallNew3                    : std_logic := '0';
   signal stallNew4                    : std_logic := '0';
   signal stallNew5                    : std_logic := '0';
               
   signal stall1                       : std_logic := '0';
   signal stall2                       : std_logic := '0';
   signal stall3                       : std_logic := '0';
   signal stall4                       : std_logic := '0';
   signal stall                        : unsigned(4 downto 0) := (others => '0');
                     
   signal exception                    : unsigned(4 downto 0) := (others => '0');
               
   signal exceptionNew1                : std_logic := '0';
   signal exceptionNew3                : std_logic := '0';
   signal exceptionNew5                : std_logic := '0';
   signal exceptionNew                 : unsigned(4 downto 0) := (others => '0');
   
   signal exception_SR                 : unsigned(31 downto 0) := (others => '0');
   signal exception_CAUSE              : unsigned(31 downto 0) := (others => '0');
   signal exception_EPC                : unsigned(31 downto 0) := (others => '0');
   signal exception_JMP                : unsigned(31 downto 0) := (others => '0');
   
   signal exceptionCode                : unsigned(3 downto 0);
   signal exceptionCode_3              : unsigned(3 downto 0);   
   signal exceptionInstr               : unsigned(1 downto 0);
   signal exception_PC                 : unsigned(31 downto 0);
   signal exception_branch             : std_logic;
   signal exception_brslot             : std_logic;
   signal exception_JMPnext            : unsigned(31 downto 0);
               
   signal memoryMuxStage4              : std_logic := '0';
   signal memoryMuxBusy                : std_logic := '0';
   signal mem1_request_latched         : std_logic := '0';
               
   signal opcode0                      : unsigned(31 downto 0) := (others => '0');
   signal opcode1                      : unsigned(31 downto 0) := (others => '0');
   signal opcode2                      : unsigned(31 downto 0) := (others => '0');
-- synthesis translate_off
   signal opcode3                      : unsigned(31 downto 0) := (others => '0');
   signal opcode4                      : unsigned(31 downto 0) := (others => '0');
-- synthesis translate_on  
  
   signal PCold0                       : unsigned(31 downto 0) := (others => '0');
   signal PCold1                       : unsigned(31 downto 0) := (others => '0');
   
-- synthesis translate_off
   signal PCold2                       : unsigned(31 downto 0) := (others => '0');
   signal PCold3                       : unsigned(31 downto 0) := (others => '0');
   signal PCold4                       : unsigned(31 downto 0) := (others => '0');
-- synthesis translate_on
   
   signal value1                       : unsigned(31 downto 0) := (others => '0');
   signal value2                       : unsigned(31 downto 0) := (others => '0');
               
   -- stage 1          
   -- cache
   signal tag_address_a                : std_logic_vector(7 downto 0);
   signal tag_data_a                   : std_logic_vector(23 downto 0);
   signal tag_wren_a                   : std_logic;
   signal tag_address_b                : std_logic_vector(7 downto 0);
   signal tag_q_b                      : std_logic_vector(23 downto 0);
   
   signal cache_address_b              : std_logic_vector(7 downto 0);
   signal cache_q_b                    : std_logic_vector(127 downto 0);
   
   signal FetchAddr                    : unsigned(31 downto 0) := (others => '0'); 
   signal FetchLastAddr                : unsigned(31 downto 0) := (others => '0'); 
   signal FetchLastCache               : std_logic := '0';
   signal FetchLastTagvalids           : std_logic_vector(3 downto 0);
   
   signal cacheValueLast               : unsigned(31 downto 0) := (others => '0'); 
   signal cacheHitLast                 : std_logic := '0';
   
   -- regs           
   signal blockIRQ                     : std_logic := '0';
   signal blockIRQCnt                  : integer range 0 to 10;
   signal fetchReady                   : std_logic := '0';
   signal cacheHit                     : std_logic := '0';
               
   -- wires          
   signal mem1_request                 : std_logic := '0';
   signal mem1_cacherequest            : std_logic := '0';
   signal mem1_tagvalids               : std_logic_vector(3 downto 0);
   signal mem1_address                 : unsigned(31 downto 0) := (others => '0'); 
               
   signal PCnext                       : unsigned(31 downto 0) := (others => '0');
   signal opcodeNext                   : unsigned(31 downto 0) := (others => '0');
   signal fetchReadyNext               : std_logic := '0';
   signal fetchReadyNow                : std_logic := '0';
   signal cacheHitTest                 : std_logic;
   signal cacheHitNext                 : std_logic := '0';
   signal blockIRQNext                 : std_logic := '0';
   signal blockIRQCntNext              : integer range 0 to 10;
            
   -- stage 2           
   --regs            
   signal decodeException              : std_logic := '0';
   signal decodeImmData                : unsigned(15 downto 0) := (others => '0');
   signal decodeSource1                : unsigned(4 downto 0) := (others => '0');
   signal decodeSource2                : unsigned(4 downto 0) := (others => '0');
   signal decodeValue1                 : unsigned(31 downto 0) := (others => '0');
   signal decodeValue2                 : unsigned(31 downto 0) := (others => '0');
   signal decodeOP                     : unsigned(5 downto 0) := (others => '0');
   signal decodeFunct                  : unsigned(5 downto 0) := (others => '0');
   signal decodeShamt                  : unsigned(4 downto 0) := (others => '0');
   signal decodeRD                     : unsigned(4 downto 0) := (others => '0');
   signal decodeTarget                 : unsigned(4 downto 0) := (others => '0');
   signal decodeJumpTarget             : unsigned(25 downto 0) := (others => '0');
   signal decode_gte_readAddr          : unsigned(5 downto 0) := (others => '0');
   
   signal decodeReqSource1             : std_logic := '0';
   signal decodeReqSource2             : std_logic := '0';
   signal decodeLateStall              : std_logic := '0';
   
   -- wires
   signal opcodeCacheMuxed             : unsigned(31 downto 0) := (others => '0');
   
   signal decImmData                   : unsigned(15 downto 0);
   signal decSource1                   : unsigned(4 downto 0);
   signal decSource2                   : unsigned(4 downto 0);
   signal decOP                        : unsigned(5 downto 0);
   signal decFunct                     : unsigned(5 downto 0);
   signal decShamt                     : unsigned(4 downto 0);
   signal decRD                        : unsigned(4 downto 0);
   signal decTarget                    : unsigned(4 downto 0);
   signal decJumpTarget                : unsigned(25 downto 0);
   
   signal decReqSource1                : std_logic;
   signal decReqSource2                : std_logic;
            
   -- stage 3    
   type CPU_LOADTYPE is
   (
      LOADTYPE_SBYTE,
      LOADTYPE_SWORD,
      LOADTYPE_LEFT,
      LOADTYPE_DWORD,
      LOADTYPE_BYTE,
      LOADTYPE_WORD,
      LOADTYPE_RIGHT
   );
   
   type CPU_EXESTALLTYPE is
   (
      EXESTALLTYPE_NONE,
      EXESTALLTYPE_READLO,
      EXESTALLTYPE_READHI,
      EXESTALLTYPE_GTE,
      EXESTALLTYPE_GTECMD
   );
   
   --regs         
   signal blockLoadforward             : std_logic := '0';
   signal executeException             : std_logic := '0';
   signal resultWriteEnable            : std_logic := '0';
   signal executeGTEReadEnable         : std_logic := '0';
   signal executeBranchdelaySlot       : std_logic := '0';
   signal executeBranchTaken           : std_logic := '0';
   signal resultTarget                 : unsigned(4 downto 0) := (others => '0');
   signal resultData                   : unsigned(31 downto 0) := (others => '0');
   signal executeMemWriteEnable        : std_logic;
   signal executeMemWriteData          : unsigned(31 downto 0) := (others => '0');
   signal executeMemWriteMask          : std_logic_vector(3 downto 0) := (others => '0');
   signal executeMemWriteAddr          : unsigned(31 downto 0) := (others => '0');
   signal executeCOP0WriteEnable       : std_logic := '0';
   signal executeCOP0WriteDestination  : unsigned(4 downto 0) := (others => '0');
   signal executeCOP0WriteValue        : unsigned(31 downto 0) := (others => '0');
   signal executeLoadType              : CPU_LOADTYPE;
   signal executeReadAddress           : unsigned(31 downto 0) := (others => '0');
   signal executeReadEnable            : std_logic := '0';
   signal executeGTETarget             : unsigned(4 downto 0) := (others => '0');
   signal hiloWait                     : integer range 0 to 38;
   signal executeStalltype             : CPU_EXESTALLTYPE;
   signal execute_gte_writeAddr        : unsigned(5 downto 0) := (others => '0');
   signal execute_gte_writeData        : unsigned(31 downto 0) := (others => '0');
   signal execute_gte_writeEna         : std_logic := '0'; 
   signal execute_gte_cmdData          : unsigned(31 downto 0);
   signal execute_gte_cmdEna           : std_logic := '0'; 
   signal execute_gte_readAddr         : unsigned(5 downto 0) := (others => '0');
   signal execute_lastreadCOP          : std_logic := '0'; 

   --wires
   signal branch                       : std_logic := '0';
   signal PCbranch                     : unsigned(31 downto 0) := (others => '0');
   signal EXEresultWriteEnable         : std_logic;
   signal EXEresultData                : unsigned(31 downto 0) := (others => '0');
   signal EXEresultTarget              : unsigned(4 downto 0) := (others => '0');
   signal EXEBranchdelaySlot           : std_logic := '0';
   signal EXEBranchTaken               : std_logic := '0';
   signal EXEMemWriteEnable            : std_logic := '0';
   signal EXEMemWriteData              : unsigned(31 downto 0) := (others => '0');
   signal EXEMemWriteMask              : std_logic_vector(3 downto 0) := (others => '0');
   signal EXEMemAddr                   : unsigned(31 downto 0) := (others => '0');
   signal EXEMemWriteException         : std_logic := '0';
   signal EXECOP0WriteEnable           : std_logic := '0';
   signal EXECOP0WriteDestination      : unsigned(4 downto 0) := (others => '0');
   signal EXECOP0WriteValue            : unsigned(31 downto 0) := (others => '0');
   signal EXELoadType                  : CPU_LOADTYPE;
   signal EXEReadEnable                : std_logic := '0';
   signal EXEReadException             : std_logic := '0';
   signal EXEGTeReadEnable             : std_logic := '0';
   signal EXEcalcMULT                  : std_logic := '0';
   signal EXEcalcMULTU                 : std_logic := '0';
   signal EXEcalcDIV                   : std_logic := '0';
   signal EXEcalcDIVU                  : std_logic := '0';
   signal EXEhiUpdate                  : std_logic := '0';
   signal EXEloUpdate                  : std_logic := '0';
   signal EXEstalltype                 : CPU_EXESTALLTYPE;
   signal EXEgte_writeAddr             : unsigned(5 downto 0);
   signal EXEgte_writeData             : unsigned(31 downto 0);
   signal EXEgte_writeEna              : std_logic := '0';    
   signal EXEgte_cmdData               : unsigned(31 downto 0);
   signal EXEgte_cmdEna                : std_logic := '0'; 
   signal EXElastreadCOP               : std_logic := '0'; 
   
   --MULT/DIV
   type CPU_HILOCALC is
   (
      HILOCALC_MULT, 
      HILOCALC_MULTU,
      HILOCALC_DIV,  
      HILOCALC_DIVU,
      HILOCALC_DIV0
   );
   signal hilocalc                     : CPU_HILOCALC;
   
   signal mul1                         : unsigned(31 downto 0);
   signal mul2                         : unsigned(31 downto 0);
   signal mulResultS                   : signed(63 downto 0);
   signal mulResultU                   : unsigned(63 downto 0);
   
   signal DIVstart                     : std_logic;
   signal DIVdividend                  : signed(32 downto 0);
   signal DIVdivisor                   : signed(32 downto 0);
   signal DIVquotient                  : signed(32 downto 0);
   signal DIVremainder                 : signed(32 downto 0);    
   signal DIV0quotient                 : unsigned(31 downto 0);
   signal DIV0remainder                : unsigned(31 downto 0);    
         
   -- stage 4 
   -- scratchpad
   signal scratchpad_address_a         : std_logic_vector(7 downto 0);
   signal scratchpad_data_a            : std_logic_vector(31 downto 0);
   signal scratchpad_wren_a            : std_logic_vector(3 downto 0);
   signal scratchpad_q_a               : std_logic_vector(31 downto 0);
   signal scratchpad_address_b         : std_logic_vector(7 downto 0);
   signal scratchpad_q_b               : std_logic_vector(31 downto 0);
   signal scratchpad_dataread          : unsigned(31 downto 0);
   
   -- data cache  
   signal dcache_read_enable           : std_logic := '0';
   signal dcache_read_addr             : std_logic_vector(18 downto 0) := (others => '0');
   signal dcache_read_hit              : std_logic;
   signal dcache_read_data             : std_logic_vector(31 downto 0);
         
   signal dcache_hit_next              : std_logic := '0';
         
   signal dcache_write_enable          : std_logic := '0';
   signal dcache_write_clear           : std_logic := '0';
   signal dcache_write_addr            : std_logic_vector(18 downto 0) := (others => '0');
   signal dcache_write_data            : std_logic_vector(31 downto 0) := (others => '0');
   
   signal spad_cache_dataread          : unsigned(31 downto 0);
   
   -- reg      
   signal writebackException           : std_logic := '0';
   signal writebackTarget              : unsigned(4 downto 0) := (others => '0');
   signal writebackData                : unsigned(31 downto 0) := (others => '0');
   signal writebackWriteEnable         : std_logic := '0';
   signal writebackGTEReadEnable       : std_logic := '0';
   signal writebackLoadType            : CPU_LOADTYPE;
   signal writebackReadAddress         : unsigned(31 downto 0) := (others => '0');
   signal writebackInvalidateCacheEna  : std_logic := '0';
   signal writebackInvalidateCacheLine : unsigned(7 downto 0) := (others => '0');
   signal WBgte_writeAddr              : unsigned(5 downto 0);
   
   signal lateReadTarget               : unsigned(4 downto 0) := (others => '0');
   signal lateReadOldData              : unsigned(31 downto 0) := (others => '0');
   signal lateReadData                 : unsigned(31 downto 0) := (others => '0');
   signal lateReadWrite                : std_logic := '0';
   signal lateReadBypass               : std_logic := '0';
   signal lateReadReqDone              : std_logic := '0';
   signal lateReadWriteAfterWrite      : std_logic := '0';
   signal lateReadStall                : std_logic := '0';
   signal lateReadRam                  : std_logic := '0';
         
   -- wire     
   signal mem4_request                 : std_logic := '0';
   signal mem4_address                 : unsigned(31 downto 0) := (others => '0');
   signal mem4_reqsize                 : unsigned(1 downto 0) := (others => '0');
   signal mem4_rnw                     : std_logic := '0';
   signal mem4_pending                 : std_logic := '0';
   signal mem4_dataWrite               : std_logic_vector(31 downto 0) := (others => '0');
   signal WBCACHECONTROL               : unsigned(31 downto 0) := (others => '0');
   signal WBinvalidateCacheEna         : std_logic := '0';
   signal WBinvalidateCacheLine        : unsigned(7 downto 0) := (others => '0');
         
         
   -- stage 5     
   -- reg      
   signal writeDoneTarget              : unsigned(4 downto 0) := (others => '0');
   signal writeDoneData                : unsigned(31 downto 0) := (others => '0');
   signal writeDoneWriteEnable         : std_logic := '0';
   
   -- savestates
   type t_ssarray is array(0 to 95) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0')); 

   signal ss_scp_rden_1                : std_logic;              
   
   -- debug
-- synthesis translate_off
   signal debugCnt                     : unsigned(31 downto 0);
   signal debugSum                     : unsigned(31 downto 0);
   signal debugTmr                     : unsigned(31 downto 0);
   
   signal stallcountNo                 : integer;
   signal stallcount1                  : integer;
   signal stallcount3                  : integer;
   signal stallcount4                  : integer;
   signal stallcountDMA                : integer;
-- synthesis translate_on
   
   signal debugStallcounter            : unsigned(9 downto 0);
   signal debug300exception            : std_logic := '0';
   
   -- export
-- synthesis translate_off
   type tRegs is array(0 to 31) of unsigned(31 downto 0);
   signal regs                         : tRegs := (others => (others => '0'));
-- synthesis translate_on
   
begin 

   -- IO
   mem_request       <= mem1_request or mem1_request_latched or mem4_request when (memoryMuxBusy = '0' or mem_done = '1') else '0';
   mem_isCache       <= FetchLastCache     when (mem1_request_latched = '1') else mem1_cacherequest;
   mem_oldtagvalids  <= FetchLastTagvalids when (mem1_request_latched = '1') else mem1_tagvalids;
   mem_addressInstr  <= FetchLastAddr      when (mem1_request_latched = '1') else mem1_address;
   mem_isData        <= mem4_request;
   mem_rnw           <= mem4_rnw     when mem4_request = '1' else '1';
   mem_addressData   <= mem4_address;
   mem_reqsize       <= mem4_reqsize when mem4_request = '1' else "10";
   mem_dataWrite     <= mem4_dataWrite;
   mem_writeMask     <= executeMemWriteMask;

   mem1_cacherequest <= '1' when (to_integer(FetchAddr(31 downto 29)) = 0 or to_integer(FetchAddr(31 downto 29)) = 4) else '0';

   stallNext         <= mem_request or stallNew3;

   -- common
   stall        <= dmaRequest & stall4 & stall3 & stall2 & stall1;

   exceptionNew <= exceptionNew5 & '0' & exceptionNew3 & '0' & exceptionNew1;
   
   mem4_pending <= memoryMuxBusy and memoryMuxStage4;
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         if (reset = '1') then
         
            -- no ss when stalled -> not relevant for savestate
            memoryMuxStage4       <= '0'; 
            memoryMuxBusy         <= '0';
            mem1_request_latched  <= '0';
         
         elsif (ce = '1') then
            
            if (mem1_request = '1') then
               FetchLastAddr      <= mem1_address;
               FetchLastCache     <= mem1_cacherequest;
               FetchLastTagvalids <= mem1_tagvalids;
               if (mem4_request = '1' or memoryMuxBusy = '1') then
                  mem1_request_latched <= '1';
               end if;
            end if;
            
            if (mem_done = '1') then
               memoryMuxBusy <= '0';
            end if;
            
            if (mem_request = '1' and (memoryMuxBusy = '0' or mem_done = '1')) then
               memoryMuxStage4  <= mem_isData;
               memoryMuxBusy    <= mem_rnw;
               if (mem_isData = '0') then
                  mem1_request_latched <= '0';
               end if;
            end if;

         end if;
      end if;
   end process;
   
--##############################################################
--############################### register file
--##############################################################
   iregisterfile1 : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => regs1_address_b,
      q          => regs1_q_b
	);
   
   regs_wren_a    <= '1' when (ss_regs_load = '1') else
                     '1' when (lateReadWrite = '1') else
                     '1' when (ce = '1' and stall = 0 and writebackWriteEnable = '1' and writebackException = '0' and writebackTarget > 0) else 
                     '0';
   
   regs_data_a    <= ss_regs_data when (ss_regs_load = '1') else 
                     std_logic_vector(lateReadData) when (lateReadWrite = '1') else 
                     std_logic_vector(writebackData);
                     
   regs_address_a <= std_logic_vector(ss_regs_addr) when (ss_regs_load = '1') else 
                     std_logic_vector(lateReadTarget) when (lateReadWrite = '1') else 
                     std_logic_vector(writebackTarget);
   
   
   regs1_address_b <= std_logic_vector(decSource1);
   regs2_address_b <= std_logic_vector(decSource2);
   
   iregisterfile2 : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => regs2_address_b,
      q          => regs2_q_b
	);
   
   iregisterfileSS : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => regsSS_address_b,
      q          => regsSS_q_b
	);

--##############################################################
--############################### stage 1
--##############################################################

   itagram : entity mem.RamMLAB
   generic map
   (
      width      => 24,
      widthad    => 8
   )
   port map
   (
      inclock    => clk1x,
      wren       => tag_wren_a,
      data       => tag_data_a,
      wraddress  => tag_address_a,
      rdaddress  => tag_address_b,
      q          => tag_q_b
   );

   tag_address_a <= std_logic_vector(writebackInvalidateCacheLine) when (writebackInvalidateCacheEna = '1') else std_logic_vector(FetchLastAddr(11 downto 4));
   
   tag_data_a    <= "0000"        & std_logic_vector(FetchLastAddr(31 downto 12)) when (writebackInvalidateCacheEna = '1') else
                    mem_tagvalids & std_logic_vector(FetchLastAddr(31 downto 12));
   
   tag_address_b <= std_logic_vector(FetchAddr(11 downto 4));

   gcache: for i in 0 to 3 generate
   begin
      icache: entity work.dpram
      generic map ( addr_width => 8, data_width => 32)
      port map
      (
         clock_a     => clk3x,
         address_a   => cache_addr,
         data_a      => cache_data,
         wren_a      => cache_wr(i),
         
         clock_b     => clk1x,
         address_b   => cache_address_b,
         data_b      => x"00000000",
         wren_b      => '0',
         q_b         => cache_q_b((32*i) + 31 downto (32*i))
      );
   end generate; 
   
   FetchAddr       <= x"BFC00180" when (exception > 0 and cop0_SR(22) = '1') else
                      x"80000080" when (exception > 0 and cop0_SR(22) = '0') else
                      PCbranch when branch = '1' else
                      PC;
                      
   cache_address_b <= std_logic_vector(FetchAddr(11 downto 4));
   
   cacheHitTest    <= '1' when (unsigned(tag_q_b(19 downto 0)) = FetchAddr(31 downto 12) and tag_q_b(20 + to_integer(unsigned(FetchAddr(3 downto 2)))) = '1') else '0';
            

   mem1_address    <= FetchAddr;

   process (blockirq, cop0_SR, cop0_CAUSE, exception, stall, mem_done, mem_dataRead, memoryMuxStage4, fetchReady, stall1, opcode0, reset, FetchAddr, 
            tag_q_b, blockirqCnt, FetchLastAddr, writebackInvalidateCacheEna, cacheHitTest)
   begin
      PCnext          <= FetchAddr;
      fetchReadyNext  <= fetchReady;
      fetchReadyNow   <= '0';
      stallNew1       <= stall1;
      opcodeNext      <= opcode0;
      blockirqNext    <= blockirq;
      blockirqCntNext <= blockirqCnt;
      
      exceptionNew1   <= '0';
      exceptionNew5   <= '0';

      tag_wren_a      <= '0';
      
      mem1_request    <= '0';
      cacheHitNext    <= '0';
      mem1_tagvalids  <= "0000";
      
      if (mem_done = '1' and memoryMuxStage4 = '0') then 
         case (to_integer(unsigned(FetchLastAddr(31 downto 29)))) is
            when 0 | 4 => -- cached
               tag_wren_a   <= '1';
            when others => null;
         end case;
      end if;
      
      if (writebackInvalidateCacheEna = '1') then
         tag_wren_a   <= '1';
      end if;

      if (exception = 0 and blockirq = '0' and cop0_SR(0) = '1' and (cop0_SR(10 downto 8) and cop0_CAUSE(10 downto 8)) /= "000") then
      
         if (stall = 0) then
            blockirqNext    <= '1';
            blockirqCntNext <= 10;     
            exceptionNew5   <= '1';
         elsif (stall1 = '1') then
            if (mem_done = '1' and memoryMuxStage4 = '0') then
               stallNew1 <= '0';
            end if;
         end if;
         
      elsif (stall = 0) then
      
         if (reset = '0') then
         
            case (to_integer(FetchAddr(31 downto 29))) is
               
               when 0 | 4 => -- cache
                  if (cacheHitTest = '1') then
                     cacheHitNext      <= '1';
                     PCnext            <= FetchAddr + 4;
                  else
                     mem1_request      <= '1';
                     stallNew1         <= '1';
                     if (unsigned(tag_q_b(19 downto 0)) = FetchAddr(31 downto 12)) then
                        mem1_tagvalids <= tag_q_b(23 downto 20);
                     end if;
                  end if;
                  
               when 5 =>
                  mem1_request      <= '1';
                  stallNew1         <= '1';
               
               when others =>
                  -- todo
               
            end case;
         
         end if;
      
         if (exception > 0) then
      
            blockirqNext    <= '1';
            blockirqCntNext <= 10;    
            
         else 
         
            fetchReadyNext <= '0';

            if (blockirqCnt > 0) then
               blockirqCntNext <= blockirqCnt - 1;
               if (blockirqCnt = 1) then
                  blockirqNext <= '0';
               end if;
            end if;
      
         end if;
      
      elsif (stall1 = '1') then
      
         if (mem_done = '1' and memoryMuxStage4 = '0') then
            
            stallNew1      <= '0';
            PCnext         <= FetchAddr + 4;
            fetchReadyNext <= '1';
            fetchReadyNow  <= '1';
            opcodeNext     <= unsigned(mem_dataRead);
            
         end if;
      
      end if;
      
   end process;
   
   ss_out( 0) <= std_logic_vector(PC);
   ss_out(25)(0) <= fetchReady;
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         
         ce_1 <= ce;
      
         if (reset = '1') then
                     
            stall1         <= '0';
            PC             <= unsigned(ss_in(0)); -- x"BFC00000";
                           
            blockIRQ       <= '0'; -- todo: busy for savestate?
            blockirqCnt    <= 0;
            fetchReady     <= ss_in(25)(0);
            opcode0        <= unsigned(ss_in(14));
            PCold0         <= unsigned(ss_in(19));
            
            cacheHit       <= '0';
            cacheHitLast   <= '0';
         
         elsif (ce = '1') then
            
            fetchReady     <= fetchReadyNext;
            PC             <= PCnext;
            stall1         <= stallNew1;
            
            blockirq       <= blockirqNext;   
            blockirqCnt    <= blockirqCntNext;
            
            cacheHit       <= cacheHitNext;
            if (cacheHit = '1' and stall > 0) then
               cacheHitLast   <= '1';
               case (PCold0(3 downto 2)) is
                  when "00" => cacheValueLast <= unsigned(cache_q_b( 31 downto  0));
                  when "01" => cacheValueLast <= unsigned(cache_q_b( 63 downto 32));
                  when "10" => cacheValueLast <= unsigned(cache_q_b( 95 downto 64));
                  when "11" => cacheValueLast <= unsigned(cache_q_b(127 downto 96));
                  when others => null;
               end case;
            elsif (stall = 0) then
               cacheHitLast <= '0';
            end if;
            
            if (fetchReadyNow = '1') then
               opcode0        <= opcodeNext; 
               PCold0         <= PC;
            end if;
            
            if (cacheHitNext = '1') then
               PCold0 <= FetchAddr;
            end if;
            
         elsif (ce_1 = '1') then
            
            if (cacheHit = '1') then
               cacheHitLast   <= '1';
               case (PCold0(3 downto 2)) is
                  when "00" => cacheValueLast <= unsigned(cache_q_b( 31 downto  0));
                  when "01" => cacheValueLast <= unsigned(cache_q_b( 63 downto 32));
                  when "10" => cacheValueLast <= unsigned(cache_q_b( 95 downto 64));
                  when "11" => cacheValueLast <= unsigned(cache_q_b(127 downto 96));
                  when others => null;
               end case;
            end if;
               
         end if;
      end if;
     
   end process;
   
   
--##############################################################
--############################### stage 2
--##############################################################
   
   opcodeCacheMuxed <= cacheValueLast when cacheHitLast = '1' else
                       unsigned(cache_q_b( 31 downto  0)) when (cacheHit = '1' and PCold0(3 downto 2) = "00") else
                       unsigned(cache_q_b( 63 downto 32)) when (cacheHit = '1' and PCold0(3 downto 2) = "01") else
                       unsigned(cache_q_b( 95 downto 64)) when (cacheHit = '1' and PCold0(3 downto 2) = "10") else
                       unsigned(cache_q_b(127 downto 96)) when (cacheHit = '1' and PCold0(3 downto 2) = "11") else
                       opcode0;
                       
                       
                       
   decImmData    <= opcodeCacheMuxed(15 downto 0);
   decJumpTarget <= opcodeCacheMuxed(25 downto 0);
   decSource1    <= opcodeCacheMuxed(25 downto 21);
   decSource2    <= opcodeCacheMuxed(20 downto 16);
   decOP         <= opcodeCacheMuxed(31 downto 26);
   decFunct      <= opcodeCacheMuxed(5 downto 0);
   decShamt      <= opcodeCacheMuxed(10 downto 6);
   decRD         <= opcodeCacheMuxed(15 downto 11);
   decTarget     <= opcodeCacheMuxed(20 downto 16) when (opcodeCacheMuxed(31 downto 26) > 0) else opcodeCacheMuxed(15 downto 11);                 
               
   -- find which value is required by which opcode for blocking
   process (decSource1, decSource2, decOP, decFunct, decShamt, decRD)
   begin
   
      decReqSource1 <= '0';
      decReqSource2 <= '0';

      case (to_integer(decOP)) is
      
         when 16#00# =>
            case (to_integer(decFunct)) is
      
               when 16#08# | -- JR 
                    16#09# | -- JALR
                    16#11# | -- MTHI
                    16#13#   -- MTLO
               => decReqSource1 <= '1'; 
               
               when 16#00# | -- SLL
                    16#02# | -- SRL
                    16#03#   -- SRA
               => decReqSource2 <= '1'; 
                        
               when 16#04# | -- SLLV
                    16#06# | -- SRLV
                    16#07# | -- SRAV
                    16#18# | -- MULT
                    16#19# | -- MULTU
                    16#1A# | -- DIV
                    16#1B# | -- DIVU
                    16#20# | -- ADD
                    16#21# | -- ADDU
                    16#22# | -- SUB
                    16#23# | -- SUBU
                    16#24# | -- AND
                    16#25# | -- OR
                    16#26# | -- XOR
                    16#27# | -- NOR
                    16#2A# | -- SLT
                    16#2B#   -- SLTI
               => decReqSource1 <= '1';
                  decReqSource2 <= '1';                   
                  
               when others => null;
                  
            end case;
            
         when 16#01# | -- B: BLTZ, BGEZ, BLTZAL, BGEZAL
              16#06# | -- BLEZ
              16#07# | -- BGTZ
              16#08# | -- ADDI
              16#09# | -- ADDIU
              16#0A# | -- SLTI
              16#0B# | -- SLTIU
              16#0C# | -- ANDI
              16#0D# | -- ORI
              16#0E# | -- XORI
              16#20# | -- LB
              16#21# | -- LH
              16#23# | -- LW
              16#24# | -- LBU
              16#25# | -- LHU
              16#32# | -- LWC2
              16#3A#   -- SWC2
            => decReqSource1 <= '1';

         when 16#04# | -- BEQ
              16#05# | -- BNE
              16#28# | -- SB
              16#29# | -- SH
              16#2A# | -- SWL
              16#2B# | -- SW
              16#2E# | -- SWR
              16#22# | -- LWL
              16#26#   -- LWR
            => decReqSource1 <= '1';
               decReqSource2 <= '1';  
         
         
         when 16#10# => -- COP0
            if (to_integer(decSource1) = 4) then
               decReqSource2 <= '1';   
            end if;
            
         when 16#12# => -- COP2
            if (to_integer(decSource1) = 4 or to_integer(decSource1) = 6) then
               decReqSource2 <= '1';   
            end if;   

         when others => 
            null;
      
      end case;
      
   end process;
                
   ss_out(14) <= std_logic_vector(opcodeCacheMuxed);
   ss_out(19) <= std_logic_vector(PCold0);

   ss_out(15) <= std_logic_vector(opcode1);
   ss_out(20) <= std_logic_vector(pcOld1);

   ss_out(32)(25) <= decodeException;
   
   ss_out(26)(15 downto 0)   <= std_logic_vector(decodeImmData);
   ss_out(31)( 4 downto 0)   <= std_logic_vector(decodeSource1);
   ss_out(31)(12 downto 8)   <= std_logic_vector(decodeSource2);
   ss_out(27)                <= std_logic_vector(decodeValue1);
   ss_out(28)                <= std_logic_vector(decodeValue2);
   ss_out(31)(29 downto 24)  <= std_logic_vector(decodeOP);
   ss_out(32)(13 downto  8)  <= std_logic_vector(decodeFunct);
   ss_out(32)(20 downto 16)  <= std_logic_vector(decodeShamt);
   ss_out(32)( 4 downto  0)  <= std_logic_vector(decodeRD);
   ss_out(31)(20 downto 16)  <= std_logic_vector(decodeTarget);
   ss_out(29)(25 downto  0)  <= std_logic_vector(decodeJumpTarget);

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         if (reset = '1') then
         
            stall2     <= '0';
            
            pcOld1  <= unsigned(ss_in(20));
            opcode1 <= unsigned(ss_in(15));
            
            decodeException  <= ss_in(32)(25);
            decodeImmData    <= unsigned(ss_in(26)(15 downto 0));
            decodeSource1    <= unsigned(ss_in(31)(4 downto 0));
            decodeSource2    <= unsigned(ss_in(31)(12 downto 8));
            decodeValue1     <= unsigned(ss_in(27));
            decodeValue2     <= unsigned(ss_in(28));
            decodeOP         <= unsigned(ss_in(31)(29 downto 24));
            decodeFunct      <= unsigned(ss_in(32)(13 downto 8));
            decodeShamt      <= unsigned(ss_in(32)(20 downto 16));
            decodeRD         <= unsigned(ss_in(32)(4 downto 0));
            decodeTarget     <= unsigned(ss_in(31)(20 downto 16));
            decodeJumpTarget <= unsigned(ss_in(29)(25 downto 0));
            
            if (unsigned(ss_in(31)(29 downto 24)) = 16#12#) then
               decode_gte_readAddr <= ss_in(31)(1) & unsigned(ss_in(32)(4 downto 0)); -- decodeSource1(1) & decodeRD 
            else
               decode_gte_readAddr <= '0' & unsigned(ss_in(31)(12 downto 8)); -- decodeSource2
            end if;
            
            decodeReqSource1 <= '0'; -- no savestate required, cannot save while load is pending
            decodeReqSource2 <= '0';
         
         elsif (ce = '1') then
            
            if (stall = 0) then
            
               if (exception(4 downto 1) > 0) then
               
                  if (exception(4) = '1') then decodeException <= '1'; end if;
                  
                  decodeImmData    <= (others => '0');
                  decodeSource1    <= (others => '0');
                  decodeSource2    <= (others => '0');
                  decodeValue1     <= (others => '0');
                  decodeValue2     <= (others => '0');
                  decodeOP         <= (others => '0');
                  decodeFunct      <= (others => '0');
                  decodeShamt      <= (others => '0');
                  decodeRD         <= (others => '0');
                  decodeTarget     <= (others => '0');
                  decodeJumpTarget <= (others => '0');
               
               else
               
                  decodeException <= '0';
                  if (exception(0) = '1') then decodeException <= '1'; end if;
   
                  pcOld1  <= pcOld0;
                  opcode1 <= opcodeCacheMuxed;
                  
                  decodeValue1     <= unsigned(regs1_q_b);
                  decodeValue2     <= unsigned(regs2_q_b);
   
                  decodeImmData    <= decImmData;   
                  decodeJumpTarget <= decJumpTarget;
                  decodeSource1    <= decSource1;
                  decodeSource2    <= decSource2;
                  decodeOP         <= decOP;
                  decodeFunct      <= decFunct;     
                  decodeShamt      <= decShamt;     
                  decodeRD         <= decRD;        
                  decodeTarget     <= decTarget;    
                                     
                  if (opcodeCacheMuxed(31 downto 26) = 16#12#) then
                     decode_gte_readAddr <= opcodeCacheMuxed(22) & opcodeCacheMuxed(15 downto 11); -- decodeSource1(1) & decodeRD 
                  else
                     decode_gte_readAddr <= '0' & opcodeCacheMuxed(20 downto 16); -- decodeSource2
                  end if;
                  
                  decodeReqSource1 <= decReqSource1;
                  decodeReqSource2 <= decReqSource2;
                  
               end if;
      
            end if;
            
            if (mem4_pending = '1') then
               if ((decReqSource1    = '1' and decSource1    = lateReadTarget) or (decodeReqSource1 = '1' and decodeSource1 = lateReadTarget) or
                   (decReqSource2    = '1' and decSource2    = lateReadTarget) or (decodeReqSource2 = '1' and decodeSource2 = lateReadTarget)) then
                  stall2          <= '1'; 
                  -- for some reason the original cpu stalls 1 cycle longer than needed if the value is required by next op...need to compensate
                  if (stall2 = '0') then
                     decodeLateStall <= not stall4;
                  end if;
               end if;
            elsif (TURBO = '1' or stall4 = '0' or decodeLateStall = '0') then
               stall2 <= '0';
            end if;
            
         end if;
      end if;
   end process;
   
   
--##############################################################
--############################### stage 3
--##############################################################

   process (decodeValue1, decodeValue2, decodeSource1, decodeSource2, resultTarget, writebackTarget, writeDoneTarget, resultWriteEnable, writebackWriteEnable, writeDoneWriteEnable, 
            resultData, writebackData, writeDoneData, blockLoadforward, execute_lastreadCOP, lateReadBypass, lateReadTarget, lateReadData)
   begin
   
      value1 <= decodeValue1;
      if    (decodeSource1 > 0 and resultTarget    = decodeSource1 and resultWriteEnable    = '1' and execute_lastreadCOP = '0') then value1 <= resultData;
      elsif (decodeSource1 = lateReadTarget and lateReadBypass = '1' and blockLoadforward = '0' )                                then value1 <= lateReadData;
      elsif (decodeSource1 > 0 and writebackTarget = decodeSource1 and writebackWriteEnable = '1' and blockLoadforward = '0')    then value1 <= writebackData;
      elsif (decodeSource1 > 0 and writeDoneTarget = decodeSource1 and writeDoneWriteEnable = '1')                               then value1 <= writeDoneData;
      end if;
      
      value2 <= decodeValue2;
      if    (decodeSource2 > 0 and resultTarget    = decodeSource2 and resultWriteEnable    = '1' and execute_lastreadCOP = '0') then value2 <= resultData;
      elsif (decodeSource2 = lateReadTarget and lateReadBypass = '1' and blockLoadforward = '0' )                                then value2 <= lateReadData;
      elsif (decodeSource2 > 0 and writebackTarget = decodeSource2 and writebackWriteEnable = '1' and blockLoadforward = '0'   ) then value2 <= writebackData;
      elsif (decodeSource2 > 0 and writeDoneTarget = decodeSource2 and writeDoneWriteEnable = '1')                               then value2 <= writeDoneData;
      end if;
      
   end process;

   process (decodeImmData, decodeTarget, decodeJumpTarget, decodeSource1, decodeSource2, decodeValue1, decodeValue2, decodeOP, decodeFunct, decodeShamt, decodeRD, exception, stall3, stall, value1, value2, pcOld0, resultData, executeStalltype,
            cop0_BPC, cop0_BDA, cop0_JUMPDEST, cop0_DCIC, cop0_BADVADDR, cop0_BDAM, cop0_BPCM, cop0_SR, cop0_CAUSE, cop0_EPC, cop0_PRID, PC, hi, lo, hiloWait, 
            opcode1, gte_readAddr, decode_gte_readAddr, gte_readData, gte_busy, execute_gte_cmdEna, ce, execute_gte_readAddr)
      variable calcResult  : unsigned(31 downto 0);
      variable calcMemAddr : unsigned(31 downto 0);
   begin
   
      branch                  <= '0';
      exceptionNew3           <= '0';
      stallNew3               <= stall3;
      EXEresultData           <= resultData;
      PCbranch                <= pcOld0;
      EXEresultTarget         <= decodeTarget;
      EXEresultWriteEnable    <= '0';          
            
      calcMemAddr             := value1 + unsigned(resize(signed(decodeImmData), 32));
      EXEMemAddr              <= calcMemAddr;
      
      EXEMemWriteEnable       <= '0';
      EXEMemWriteData         <= value2;
      EXEMemWriteMask         <= "1111";
      EXEMemWriteException    <= '0';
      
      EXELoadType             <= LOADTYPE_DWORD;
      EXEReadEnable           <= '0';
      EXEReadException        <= '0';
      EXEGTeReadEnable        <= '0';
      
      EXECOP0WriteEnable      <= '0';
      EXECOP0WriteDestination <= decodeRD;
      EXECOP0WriteValue       <= value2;
      
      EXEBranchdelaySlot      <= '0';
      EXEBranchTaken          <= '0';
      
      EXEcalcMULT             <= '0';
      EXEcalcMULTU            <= '0';
      EXEcalcDIV              <= '0';
      EXEcalcDIVU             <= '0';
      
      EXEhiUpdate             <= '0';
      EXEloUpdate             <= '0';
      
      EXElastreadCOP          <= '0';
      
      EXEgte_cmdEna           <= '0';
      EXEgte_cmdData          <= opcode1;
      
      EXEgte_writeAddr        <= gte_readAddr;
      EXEgte_writeData        <= value2;
      EXEgte_writeEna         <= '0';
      
      exceptionCode_3         <= x"0";
      
      EXEstalltype            <= EXESTALLTYPE_NONE;
      
      gte_readAddr            <= decode_gte_readAddr;
      gte_readEna             <= '0';
      
      if (executeStalltype = EXESTALLTYPE_GTE and gte_busy = '0' and gte_cmdEna = '0' and ce = '1') then
         gte_readEna         <= '1';
         gte_readAddr        <= execute_gte_readAddr;
      end if;

      if (exception(4 downto 2) = 0 and stall = 0) then
             
         case (to_integer(decodeOP)) is
         
            when 16#00# =>
               case (to_integer(decodeFunct)) is
         
                  when 16#00# => -- SLL
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value2 sll to_integer(decodeShamt);
                    
                  when 16#02# => -- SRL
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value2 srl to_integer(decodeShamt);  
                  
                  when 16#03# => -- SRA
                     EXEresultWriteEnable <= '1';              
                     EXEresultData        <= unsigned(shift_right(signed(value2),to_integer(decodeShamt)));            

                  when 16#04# => -- SLLV
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value2 sll to_integer(value1(4 downto 0));        

                  when 16#06# => -- SRLV
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value2 srl to_integer(value1(4 downto 0));     

                  when 16#07# => -- SRAV
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= unsigned(shift_right(signed(value2),to_integer(value1(4 downto 0))));                        
                    
                  when 16#08# => -- JR 
                     EXEBranchdelaySlot <= '1';
                     EXEBranchTaken     <= '1';               
                     PCbranch           <= value1;
                     if (value1(1 downto 0) > 0) then
                        exceptionNew3   <= '1';
                        exceptionCode_3 <= x"4";
                     else
                        branch <= '1';
                     end if;
                    
                  when 16#09# => -- JALR
                     EXEBranchdelaySlot   <= '1';
                     EXEBranchTaken       <= '1';               
                     PCbranch             <= value1;
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= PC;
                     EXEresultTarget      <= decodeRD;
                     if (value1(1 downto 0) > 0) then
                        exceptionNew3   <= '1';
                        exceptionCode_3 <= x"4";
                     else
                        branch <= '1';
                     end if;

                  when 16#0C# => -- SYSCALL
                     exceptionNew3   <= '1';
                     exceptionCode_3 <= x"8";
                     
                  when 16#0D# => -- BREAK
                     exceptionNew3   <= '1';
                     exceptionCode_3 <= x"9";

                  when 16#10# => -- MFHI
                     EXEresultWriteEnable <= '1';
                     if (hiloWait > 1) then
                        stallNew3    <= '1';
                        EXEstalltype <= EXESTALLTYPE_READHI;
                     else
                        EXEresultData <= hi;
                     end if;
                     
                  when 16#11# => -- MTHI
                     EXEhiUpdate <= '1';
                     
                  when 16#12# => -- MFLO
                     EXEresultWriteEnable <= '1';
                     if (hiloWait > 1) then
                        stallNew3    <= '1';
                        EXEstalltype <= EXESTALLTYPE_READLO;
                     else
                        EXEresultData <= lo;
                     end if;
                     
                  when 16#13# => -- MTLO
                     EXEloUpdate <= '1';

                  when 16#18# => -- MULT
                     EXEcalcMULT <= '1';
                     
                  when 16#19# => -- MULTU
                     EXEcalcMULTU <= '1';
                     
                  when 16#1A# => -- DIV
                     EXEcalcDIV <= '1';
                     
                  when 16#1B# => -- DIVU
                     EXEcalcDIVU <= '1';
                  
                  when 16#20# => -- ADD
                     calcResult    := value1 + value2; 
                     EXEresultData <= calcResult;               
                     if (((calcResult(31) xor value1(31)) and (calcResult(31) xor value2(31))) = '1') then
                        exceptionNew3   <= '1';
                        exceptionCode_3 <= x"C";
                     else
                        EXEresultWriteEnable <= '1';
                     end if;

                  when 16#21# => -- ADDU
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 + value2;  
                    
                  when 16#22# => -- SUB
                     calcResult    := value1 - value2; 
                     EXEresultData <= calcResult;               
                     if (((calcResult(31) xor value1(31)) and (value1(31) xor value2(31))) = '1') then
                        exceptionNew3   <= '1';
                        exceptionCode_3 <= x"C";
                     else
                        EXEresultWriteEnable <= '1';
                     end if;

                  when 16#23# => -- SUBU
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 - value2;

                  when 16#24# => -- AND
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 and value2;
                    
                  when 16#25# => -- OR
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 or value2;
                     
                  when 16#26# => -- XOR
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 xor value2;
                     
                  when 16#27# => -- NOR
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 nor value2;
                 
                  when 16#2A# => -- SLT
                     EXEresultWriteEnable <= '1';
                     if (signed(value1) < signed(value2)) then 
                        EXEresultData <= x"00000001";
                     else
                        EXEresultData <= x"00000000";
                     end if;  
                   
                  when 16#2B# => -- SLTI
                     EXEresultWriteEnable <= '1';
                     if (value1 < value2) then 
                        EXEresultData <= x"00000001";
                     else
                        EXEresultData <= x"00000000";
                     end if;   
                     
                  when others => 
                     exceptionNew3   <= '1';
                     exceptionCode_3 <= x"A";
                     
               end case;
               
            when 16#01# => -- B: BLTZ, BGEZ, BLTZAL, BGEZAL
               EXEBranchdelaySlot <= '1';
               if (decodeSource2(0) = '1') then
                  if (signed(value1) >= 0) then
                     EXEBranchTaken <= '1';               
                     branch         <= '1';
                  end if;
               else
                  if (signed(value1) < 0) then
                     EXEBranchTaken <= '1';               
                     branch         <= '1';
                  end if;
               end if;
               if (decodeSource2(4 downto 1) = "1000") then
                    EXEresultWriteEnable <= '1';
                    EXEresultData        <= PC;
                    EXEresultTarget      <= to_unsigned(31, 5);
               end if;
               PCbranch <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               
            when 16#02# => -- J
               EXEBranchdelaySlot <= '1';
               EXEBranchTaken     <= '1';               
               branch             <= '1';
               PCbranch           <= pcOld0(31 downto 28) & decodeJumpTarget & "00";
               
            when 16#03# => -- JAL
               EXEBranchdelaySlot   <= '1';
               EXEBranchTaken       <= '1';               
               branch               <= '1';
               EXEresultWriteEnable <= '1';
               EXEresultData        <= PC;
               EXEresultTarget      <= to_unsigned(31, 5);
               PCbranch             <= pcOld0(31 downto 28) & decodeJumpTarget & "00";
               
            when 16#04# => -- BEQ
               EXEBranchdelaySlot   <= '1';
               PCbranch             <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               if (value1 = value2) then
                  EXEBranchTaken    <= '1';               
                  branch            <= '1';
               end if;
            
            when 16#05# => -- BNE
               EXEBranchdelaySlot   <= '1';
               PCbranch             <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               if (value1 /= value2) then
                  EXEBranchTaken    <= '1';               
                  branch            <= '1';
               end if;
            
            when 16#06# => -- BLEZ
               EXEBranchdelaySlot   <= '1';
               PCbranch             <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               if (signed(value1) <= 0) then
                  EXEBranchTaken    <= '1';               
                  branch            <= '1';
               end if;
               
            when 16#07# => -- BGTZ
               EXEBranchdelaySlot   <= '1';
               PCbranch             <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               if (signed(value1) > 0) then
                  EXEBranchTaken    <= '1';               
                  branch            <= '1';
               end if;
            
            when 16#08# => -- ADDI
               calcResult    := value1 + unsigned(resize(signed(decodeImmData), 32)); 
               EXEresultData <= calcResult;               
               if (((calcResult(31) xor value1(31)) and (calcResult(31) xor decodeImmData(15))) = '1') then
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"C";
               else
                  EXEresultWriteEnable <= '1';
               end if;
            
            when 16#09# => -- ADDIU
               EXEresultData        <= value1 + unsigned(resize(signed(decodeImmData), 32));            
               EXEresultWriteEnable <= '1';
               
            when 16#0A# => -- SLTI
               EXEresultWriteEnable <= '1';
               if (signed(value1) < resize(signed(decodeImmData), 32)) then 
                  EXEresultData <= x"00000001";
               else
                  EXEresultData <= x"00000000";
               end if;
               
            when 16#0B# => -- SLTIU
               EXEresultWriteEnable <= '1';
               if (value1 < unsigned(resize(signed(decodeImmData), 32))) then 
                  EXEresultData <= x"00000001";
               else
                  EXEresultData <= x"00000000";
               end if;
               
            when 16#0C# => -- ANDI
               EXEresultWriteEnable <= '1';
               EXEresultData        <= x"0000" & (value1(15 downto 0) and decodeImmData);
               
            when 16#0D# => -- ORI
               EXEresultWriteEnable <= '1';
               EXEresultData        <= value1(31 downto 16) & (value1(15 downto 0) or decodeImmData);
               
            when 16#0E# => -- XORI
               EXEresultWriteEnable <= '1';
               EXEresultData        <= value1(31 downto 16) & (value1(15 downto 0) xor decodeImmData);
               
            when 16#0F# => -- LUI
               EXEresultWriteEnable <= '1';
               EXEresultData        <= decodeImmData & x"0000";
               
            when 16#10# => -- COP0
               if (cop0_SR(1) = '1' and cop0_SR(28) = '0') then
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"B";
               else
                  if (decodeSource1(4) = '1') then
                     case (to_integer(decodeImmData(6 downto 0))) is
                        when 1 | 2 | 4 | 8 =>
                           exceptionNew3   <= '1';
                           exceptionCode_3 <= x"A";

                        when 16 => -- Cop0Op - rfe
                           EXECOP0WriteEnable      <= '1';
                           EXECOP0WriteDestination <= to_unsigned(12, 5);
                           EXECOP0WriteValue       <= cop0_SR(31 downto 4) & cop0_SR(5 downto 2);

                        when others => report "should not happen" severity failure; 
                     end case;
                  else
                     case (to_integer(decodeSource1)) is
                     
                        when 0 => -- mfcn
                           EXEresultWriteEnable <= '1';
                           EXElastreadCOP       <= '1';
                           case (to_integer(decodeRD)) is
                              when 16#3# => EXEresultData <= cop0_BPC;
                              when 16#5# => EXEresultData <= cop0_BDA;
                              when 16#6# => EXEresultData <= cop0_JUMPDEST;
                              when 16#7# => EXEresultData <= cop0_DCIC;
                              when 16#8# => EXEresultData <= cop0_BADVADDR;
                              when 16#9# => EXEresultData <= cop0_BDAM;
                              when 16#B# => EXEresultData <= cop0_BPCM;
                              when 16#C# => EXEresultData <= cop0_SR;
                              when 16#D# => EXEresultData <= cop0_CAUSE;
                              when 16#E# => EXEresultData <= cop0_EPC;
                              when 16#F# => EXEresultData <= cop0_PRID;
                              when others => EXEresultData <= (others => '0');
                           end case;

                        when 4 => -- mtcn
                           exeCOP0WriteEnable      <= '1';
                           exeCOP0WriteDestination <= decodeRD;
                           exeCOP0WriteValue       <= value2;
                         
                        when others => report "should not happen" severity failure; 
                     end case;
                  end if;
               end if;
               
            when 16#11# => -- COP1 -> NOP 
               null; 
               
            when 16#12# => -- COP2
               if (cop0_SR(30) = '0') then -- COP2 disabled
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"B";
               else
                  if (decodeSource1(4) = '1') then
                     EXEgte_cmdEna <= '1';
                     if (gte_busy = '1' or execute_gte_cmdEna = '1') then
                        stallNew3    <= '1';
                        EXEstalltype <= EXESTALLTYPE_GTECMD;
                     end if;
                  else
                     case (decodeSource1(3 downto 0)) is
                        when x"0" => --mfcn
                           EXEresultWriteEnable <= '1';
                           EXEresultData        <= gte_readData;
                           EXElastreadCOP       <= '1';
                           if (gte_busy = '1' or gte_cmdEna = '1' or execute_gte_cmdEna = '1' or gte_writeEna = '1') then --gte_cmdEna not needed as will be busy on new request anyway?
                              stallNew3    <= '1';
                              EXEstalltype <= EXESTALLTYPE_GTE;
                           else
                              gte_readEna          <= ce;
                           end if;
                        
                        when x"2" => --cfcn
                           EXEresultWriteEnable <= '1';
                           EXEresultData        <= gte_readData;
                           EXElastreadCOP       <= '1';
                           if (gte_busy = '1' or gte_cmdEna = '1' or execute_gte_cmdEna = '1' or gte_writeEna = '1') then --gte_cmdEna not needed as will be busy on new request anyway?
                              stallNew3    <= '1';
                              EXEstalltype <= EXESTALLTYPE_GTE;
                           else
                              gte_readEna          <= ce;
                           end if;
                        
                        when x"4" => --mtcn
                           EXEgte_writeEna      <= '1';
                           if (gte_busy = '1' or execute_gte_cmdEna = '1') then
                              stallNew3    <= '1';
                              EXEstalltype <= EXESTALLTYPE_GTECMD;
                           end if;
                        
                        when x"6" => --cfcn
                           EXEgte_writeEna      <= '1';
                           if (gte_busy = '1' or execute_gte_cmdEna = '1') then
                              stallNew3    <= '1';
                              EXEstalltype <= EXESTALLTYPE_GTECMD;
                           end if;
                        
                        when others => null;
                     end case;
                  end if;
               end if;
               
            when 16#13# => -- COP3 -> NOP 
               null; 

            when 16#20# => -- LB
               EXELoadType   <= LOADTYPE_SBYTE;
               EXEReadEnable <= '1';
               
             when 16#21# => -- LH
               EXELoadType <= LOADTYPE_SWORD;
               if (calcMemAddr(0) = '1') then
                  exceptionNew3    <= '1';
                  exceptionCode_3  <= x"4";
                  EXEReadException <= '1';
               else
                  EXEReadEnable <= '1';
               end if;  

            when 16#22# => -- LWL
               EXELoadType   <= LOADTYPE_LEFT;
               EXEReadEnable <= '1';
               EXEresultData <= value2;
               
            when 16#23# => -- LW
               EXELoadType <= LOADTYPE_DWORD;
               if (calcMemAddr(1 downto 0) /= "00") then
                  exceptionNew3    <= '1';
                  exceptionCode_3  <= x"4";
                  EXEReadException <= '1';
               else
                  EXEReadEnable <= '1';
               end if;  

            when 16#24# => -- LBU
               EXELoadType <= LOADTYPE_BYTE;
               EXEReadEnable <= '1';

            when 16#25# => -- LHU
               EXELoadType <= LOADTYPE_WORD;
               if (calcMemAddr(0) = '1') then
                  exceptionNew3    <= '1';
                  exceptionCode_3  <= x"4";
                  EXEReadException <= '1';
               else
                  EXEReadEnable <= '1';
               end if; 
               
            when 16#26# => -- LWR
               EXELoadType   <= LOADTYPE_RIGHT;
               EXEReadEnable <= '1';
               EXEresultData <= value2;    

            when 16#28# => -- SB
               case (to_integer(calcMemAddr(1 downto 0))) is 
                  when 0 => EXEMemWriteMask <= "0001"; EXEMemWriteData <= value2; 
                  when 1 => EXEMemWriteMask <= "0010"; EXEMemWriteData <= value2(23 downto 0) & x"00";   
                  when 2 => EXEMemWriteMask <= "0100"; EXEMemWriteData <= value2(15 downto 0) & x"0000";   
                  when 3 => EXEMemWriteMask <= "1000"; EXEMemWriteData <= value2(7 downto 0) & x"000000";   
                  when others => null;
               end case;
               EXEMemWriteEnable <= '1';

            when 16#29# => -- SH
               if (calcMemAddr(1) = '1') then
                  EXEMemWriteData <= value2(15 downto 0) & x"0000";
                  EXEMemWriteMask <= "1100";
               else
                  EXEMemWriteData <= value2;
                  EXEMemWriteMask <= "0011";
               end if;
               if (calcMemAddr(0) = '1') then
                  exceptionNew3        <= '1';
                  exceptionCode_3      <= x"5";
                  EXEMemWriteException <= '1';
               else
                  EXEMemWriteEnable <= '1';
               end if;
               
            when 16#2A# => -- SWL
               case (to_integer(calcMemAddr(1 downto 0))) is 
                  when 0 => EXEMemWriteMask <= "0001"; EXEMemWriteData <= x"000000" & value2(31 downto 24);
                  when 1 => EXEMemWriteMask <= "0011"; EXEMemWriteData <= x"0000" & value2(31 downto 16);
                  when 2 => EXEMemWriteMask <= "0111"; EXEMemWriteData <= x"00" & value2(31 downto 8);
                  when 3 => EXEMemWriteMask <= "1111"; EXEMemWriteData <= value2;
                  when others => null;
               end case;
               EXEMemWriteEnable <= '1';   

            when 16#2B# => -- SW
               if (calcMemAddr(1 downto 0) /= "00") then
                  exceptionNew3        <= '1';
                  exceptionCode_3      <= x"5";
                  EXEMemWriteException <= '1';
               else
                  EXEMemWriteEnable <= '1';
               end if;
               
            when 16#2E# => -- SWR
               case (to_integer(calcMemAddr(1 downto 0))) is 
                  when 0 => EXEMemWriteMask <= "1111"; EXEMemWriteData <= value2;
                  when 1 => EXEMemWriteMask <= "1110"; EXEMemWriteData <= value2(23 downto 0) & x"00";
                  when 2 => EXEMemWriteMask <= "1100"; EXEMemWriteData <= value2(15 downto 0) & x"0000";
                  when 3 => EXEMemWriteMask <= "1000"; EXEMemWriteData <= value2( 7 downto 0) & x"000000";
                  when others => null;
               end case;
               EXEMemWriteEnable <= '1';    
            
            when 16#30# => -- LWC0 -> NOP 
               null;            

            when 16#31# => -- LWC1 -> NOP 
               null;    

            when 16#32# => -- LWC2
               if (cop0_SR(30) = '0') then -- COP2 disabled
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"B";
               else
                  EXEGTeReadEnable <= '1';
                  EXELoadType      <= LOADTYPE_DWORD;
                  EXEReadEnable    <= '1';
                  if (gte_busy = '1' or execute_gte_cmdEna = '1') then
                     stallNew3    <= '1';
                     EXEstalltype <= EXESTALLTYPE_GTECMD;
                  end if;
               end if;                        
               
            when 16#33# => -- LWC3 -> NOP 
               null;    
               
            when 16#38# => -- SWC0 -> NOP 
               null;    
               
            when 16#39# => -- SWC1 -> NOP 
               null; 
               
            when 16#3A# => -- SWC2
               if (cop0_SR(30) = '0') then -- COP2 disabled
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"B";
               else
                  EXEMemWriteEnable <= '1';
                  EXEMemWriteData   <= gte_readData;
                  if (gte_busy = '1' or execute_gte_cmdEna = '1' or gte_writeEna = '1') then
                     stallNew3    <= '1';
                     EXEstalltype <= EXESTALLTYPE_GTE;
                  else
                     gte_readEna  <= ce;
                  end if;
               end if; 
               
            when 16#3B# => -- SWC3 -> NOP 
               null; 
               
            when others => 
               exceptionNew3   <= '1';
               exceptionCode_3 <= x"A";
         
         end case;
             
      end if;
      
   end process;
   
   ss_out( 3)               <= std_logic_vector(cop0_BPC);                   
   ss_out( 4)               <= std_logic_vector(cop0_BDA);                   
   ss_out( 5)               <= std_logic_vector(cop0_JUMPDEST);              
   ss_out( 6)               <= std_logic_vector(cop0_DCIC);                  
   ss_out( 8)               <= std_logic_vector(cop0_BDAM);                  
   ss_out( 9)               <= std_logic_vector(cop0_BPCM);                  
   ss_out(10)               <= std_logic_vector(cop0_SR);                    
   ss_out(11)               <= std_logic_vector(cop0_CAUSE);                 
   ss_out(12)               <= std_logic_vector(cop0_EPC);                   
   ss_out(13)               <= std_logic_vector(cop0_PRID);  
   
   ss_out(16) <= std_logic_vector(opcode2);
   --ss_out(21) <= std_logic_vector(pcOld2);
   
   ss_out(24)(13)           <= blockLoadforward;           
    
   ss_out(41)(24)           <= executeException;          
   ss_out(41)(20)           <= resultWriteEnable;          
   ss_out(33)               <= std_logic_vector(resultData);                 
   ss_out(40)(4 downto 0)   <= std_logic_vector(resultTarget);               
   ss_out(41)(27)           <= executeBranchdelaySlot;     
   ss_out(41)(26)           <= executeBranchTaken;         
   ss_out(35)               <= std_logic_vector(executeMemWriteData);        
   ss_out(40)(19 downto 16) <= executeMemWriteMask;        
   ss_out(36)               <= std_logic_vector(executeMemWriteAddr);        
   ss_out(41)(23)           <= executeMemWriteEnable;      
   ss_out(41)(18 downto 16) <= std_logic_vector(to_unsigned(CPU_LOADTYPE'POS(executeLoadType), 3));       
   ss_out(34)               <= std_logic_vector(executeReadAddress);        
   ss_out(41)(21)           <= executeReadEnable;          
   ss_out(41)(25)           <= executeCOP0WriteEnable;     
   ss_out(40)(28 downto 24) <= std_logic_vector(executeCOP0WriteDestination);
   ss_out(37)               <= std_logic_vector(executeCOP0WriteValue);      
                
   ss_out(1)                <= std_logic_vector(hi);                         
   ss_out(2)                <= std_logic_vector(lo);                         

   ss_out(41)(22)           <= executeGTEReadEnable;       
   ss_out(40)(12 downto 8)  <= std_logic_vector(executeGTETarget);           

   ss_out(59)(5 downto 0)   <= std_logic_vector(execute_gte_writeAddr);      
   ss_out(57)               <= std_logic_vector(execute_gte_writeData);      
   ss_out(59)(8)            <= execute_gte_writeEna;       
                     
   ss_out(58)               <= std_logic_vector(execute_gte_cmdData);        
   ss_out(59)(9)            <= execute_gte_cmdEna;   
   
   ss_out(59)(10)           <= execute_lastreadCOP;         
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         if (reset = '1') then
         
            stall3                        <= '0';
            
            cop0_BPC                      <= unsigned(ss_in(3));
            cop0_BDA                      <= unsigned(ss_in(4));
            cop0_JUMPDEST                 <= unsigned(ss_in(5));
            cop0_DCIC                     <= unsigned(ss_in(6));
            cop0_BDAM                     <= unsigned(ss_in(8));
            cop0_BPCM                     <= unsigned(ss_in(9));
            cop0_SR                       <= unsigned(ss_in(10));
            cop0_CAUSE                    <= unsigned(ss_in(11));
            cop0_EPC                      <= unsigned(ss_in(12));
            cop0_PRID                     <= unsigned(ss_in(13)); -- x"00000002";
                       
            --pcOld2                        <= unsigned(ss_in(21));
            opcode2                       <= unsigned(ss_in(16));
                        
            blockLoadforward              <= ss_in(24)(13);
                  
            executeException              <= ss_in(41)(24);
            resultWriteEnable             <= ss_in(41)(20);
            resultData                    <= unsigned(ss_in(33));
            resultTarget                  <= unsigned(ss_in(40)(4 downto 0));
            executeBranchdelaySlot        <= ss_in(41)(27);
            executeBranchTaken            <= ss_in(41)(26);
            executeMemWriteData           <= unsigned(ss_in(35));
            executeMemWriteMask           <= ss_in(40)(19 downto 16);
            executeMemWriteAddr           <= unsigned(ss_in(36));
            executeMemWriteEnable         <= ss_in(41)(23);
            executeLoadType               <= CPU_LOADTYPE'VAL(to_integer(unsigned(ss_in(41)(18 downto 16))));
            executeReadAddress            <= unsigned(ss_in(34));
            executeReadEnable             <= ss_in(41)(21);
            executeCOP0WriteEnable        <= ss_in(41)(25);
            executeCOP0WriteDestination   <= unsigned(ss_in(40)(28 downto 24));
            executeCOP0WriteValue         <= unsigned(ss_in(37));
            hiloWait                      <= 0;
            
            hi                            <= unsigned(ss_in(1));
            lo                            <= unsigned(ss_in(2));
            
            executeStalltype              <= EXESTALLTYPE_NONE;
            
            executeGTEReadEnable          <= ss_in(41)(22);
            executeGTETarget              <= unsigned(ss_in(40)(12 downto 8));
            
            execute_gte_writeAddr         <= unsigned(ss_in(59)(5 downto 0));
            execute_gte_writeData         <= unsigned(ss_in(57));
            execute_gte_writeEna          <= ss_in(59)(8);
                                   
            execute_gte_cmdData           <= unsigned(ss_in(58));
            execute_gte_cmdEna            <= ss_in(59)(9);
            
            execute_lastreadCOP           <= ss_in(59)(10);
            
         elsif (ce = '1') then
            
            -- mul/div calc/wait
            if (hiloWait > 0) then
               hiloWait <= hiloWait - 1;
               if (hiloWait = 1) then
                  case (executeStalltype) is
                     when EXESTALLTYPE_READHI => resultData <= hi; stall3 <= '0'; executeStalltype <= EXESTALLTYPE_NONE;
                     when EXESTALLTYPE_READLO => resultData <= lo; stall3 <= '0'; executeStalltype <= EXESTALLTYPE_NONE;
                     when others => null;
                  end case;
               end if;
            end if;
            
            mulResultS <= signed(mul1) * signed(mul2);
            mulResultU <= mul1 * mul2;
            
            if (hiloWait = 2) then
               case (hilocalc) is
                  when HILOCALC_MULT  => hi <=   unsigned(mulResultS(63 downto 32));  lo <=    unsigned(mulResultS(31 downto 0));
                  when HILOCALC_MULTU => hi <=            mulResultU(63 downto 32);   lo <=             mulResultU(31 downto 0);
                  when HILOCALC_DIV   => hi <=  unsigned(DIVremainder(31 downto  0)); lo <=   unsigned(DIVquotient(31 downto 0));
                  when HILOCALC_DIVU  => hi <=  unsigned(DIVremainder(31 downto  0)); lo <=   unsigned(DIVquotient(31 downto 0));
                  when HILOCALC_DIV0  => hi <=           DIV0remainder;               lo <=            DIV0quotient;
               end case;
            end if;
            
            -- GTE
            if (executeStalltype = EXESTALLTYPE_GTE and gte_readEna = '1') then
               resultData          <= gte_readData;
               executeMemWriteData <= gte_readData;
               stall3              <= '0';
               executeStalltype    <= EXESTALLTYPE_NONE;
            end if;
            
            if (executeStalltype = EXESTALLTYPE_GTECMD and gte_busy = '0') then
               stall3              <= '0';
               executeStalltype    <= EXESTALLTYPE_NONE;
            end if;
               
            if (stall = 0) then
            
               if (exception(4 downto 2) > 0) then
               
                  executeException              <= '1';
                                                
                  stall3                        <= '0';
                     
                  resultWriteEnable             <= '0';
                  executeReadEnable             <= '0';
                  executeMemWriteEnable         <= '0';
                  executeGTEReadEnable          <= '0';
                  executeCOP0WriteEnable        <= '0';
                  
                  executeStalltype              <= EXESTALLTYPE_NONE;
                        
               else     
               
-- synthesis translate_off
                  pcOld2                        <= pcOld1;
-- synthesis translate_on
                     
                  executeException              <= decodeException;
                  opcode2                       <= opcode1;
                        
                  stall3                        <= stallNew3;
                        
                  -- from calculation     
                  resultWriteEnable             <= EXEresultWriteEnable;
                        
                  resultData                    <= EXEresultData;    
                  resultTarget                  <= EXEresultTarget;
                        
                  executeBranchdelaySlot        <= EXEBranchdelaySlot;
                  executeBranchTaken            <= EXEBranchTaken;       
      
                  executeMemWriteData           <= EXEMemWriteData;             
                  executeMemWriteMask           <= EXEMemWriteMask;             
                  executeMemWriteAddr           <= EXEMemAddr(31 downto 2) & "00";             
                  executeMemWriteEnable         <= EXEMemWriteEnable;  

                  executeLoadType               <= EXELoadType;   
                  executeReadAddress            <= EXEMemAddr;
                  executeReadEnable             <= EXEReadEnable; 
                  
                  executeGTEReadEnable          <= EXEGTeReadEnable;
                  executeGTETarget              <= decodeSource2;

                  executeCOP0WriteEnable        <= EXECOP0WriteEnable;     
                  executeCOP0WriteDestination   <= EXECOP0WriteDestination;
                  executeCOP0WriteValue         <= EXECOP0WriteValue; 

                  executeStalltype              <= EXEstalltype; 

                  execute_gte_writeAddr         <= EXEgte_writeAddr;
                  execute_gte_writeData         <= EXEgte_writeData;
                  execute_gte_writeEna          <= EXEgte_writeEna;

                  execute_gte_cmdData           <= EXEgte_cmdData;
                  execute_gte_cmdEna            <= EXEgte_cmdEna;  

                  execute_gte_readAddr          <= decode_gte_readAddr;  
                  execute_lastreadCOP           <= EXElastreadCOP;              

                  if (EXECOP0WriteEnable = '1') then
                     case (to_integer(EXECOP0WriteDestination)) is
                        when 16#3# => cop0_BPC   <= EXECOP0WriteValue;
                        when 16#5# => cop0_BDA   <= EXECOP0WriteValue;
                        when 16#7# => cop0_DCIC  <= EXECOP0WriteValue and x"FF80F03F";
                        when 16#9# => cop0_BDAM  <= EXECOP0WriteValue;
                        when 16#B# => cop0_BPCM  <= EXECOP0WriteValue;
                        when 16#C# => cop0_SR    <= EXECOP0WriteValue and x"F27FFF3F";
                        when 16#D# => cop0_CAUSE <= EXECOP0WriteValue and x"00000300";
                        when others => null;
                     end case;
                  end if;
                  
                  if (executeException = '1') then
                     cop0_SR        <= exception_SR;
                     cop0_CAUSE     <= exception_CAUSE;
                     cop0_EPC       <= exception_EPC;  
                     cop0_JUMPDEST  <= exception_JMP;  
                  end if;
                  
                  cop0_CAUSE(10) <= irqRequest;

                  blockLoadforward <= '0';
                  if (executeReadEnable = '1' and EXEReadEnable = '1' and EXEGTeReadEnable = '0' and resultTarget = EXEresultTarget) then
                     blockLoadforward <= '1';
                  end if;                 
                  
                  -- new mul/div
                  if (EXEcalcMULT = '1') then
                     hilocalc <= HILOCALC_MULT;
                     mul1     <= value1;
                     mul2     <= value2;
                     if    (value1(31 downto 11) = 0 or value1(31 downto 11) = 16#1FFFFF#) then hiloWait <= 7;
                     elsif (value1(31 downto 20) = 0 or value1(31 downto 20) = 16#FFF#)    then hiloWait <= 10;
                     else  hiloWait <= 14;
                     end if;
                  end if;
                  
                  if (EXEcalcMULTU = '1') then
                     hilocalc <= HILOCALC_MULTU;
                     mul1     <= value1;
                     mul2     <= value2;
                     if    (value1(31 downto 11) = 0) then hiloWait <= 7;
                     elsif (value1(31 downto 20) = 0) then hiloWait <= 10;
                     else  hiloWait <= 14;
                     end if;
                  end if;
                  
                  if (EXEcalcDIV = '1') then
                     hiloWait    <= 37;
                     if (value2 = 0) then
                        hilocalc      <= HILOCALC_DIV0;
                        DIV0remainder <= value1;
                        if (signed(value1) >= 0) then
                           DIV0quotient <= (others => '1');
                        else
                           DIV0quotient <= x"00000001";
                        end if;
                     elsif (value1 = x"80000000" and value2 = x"FFFFFFFF") then
                        hilocalc      <= HILOCALC_DIV0;
                        DIV0quotient  <= x"80000000";
                        DIV0remainder <= (others => '0');
                     else
                        hilocalc    <= HILOCALC_DIV;
                        --DIVstart    <= '1';
                        --DIVdividend <= resize(signed(value1), 33);
                        --DIVdivisor  <= resize(signed(value2), 33);
                     end if;
                  end if;
                  
                  if (EXEcalcDIVU = '1') then
                     hiloWait    <= 37;
                     if (value2 = 0) then
                        hilocalc      <= HILOCALC_DIV0;
                        DIV0remainder <= value1;
                        DIV0quotient  <= (others => '1');
                     else
                        hilocalc    <= HILOCALC_DIVU;
                        --DIVstart    <= '1';
                        --DIVdividend <= '0' & signed(value1);
                        --DIVdivisor  <= '0' & signed(value2);
                     end if;
                  end if;
                  
                  if (EXEhiUpdate = '1') then hi <= value1; end if;
                  if (EXEloUpdate = '1') then lo <= value1; end if;
                  
               end if;
               
               
            end if;

         end if;
         
      end if;
   end process;
   
   DIVstart    <= '1' when (reset = '0' and ce = '1' and stall = 0 and exception(4 downto 2) = 0 and (EXEcalcDIV = '1' or EXEcalcDIVU = '1')) else '0';
   DIVdividend <= resize(signed(value1), 33) when (EXEcalcDIV = '1') else '0' & signed(value1);
   DIVdivisor  <= resize(signed(value2), 33) when (EXEcalcDIV = '1') else '0' & signed(value2);
   
   
--##############################################################
--############################### stage 4
--##############################################################
   
   
   -- scratchpad ###############################################
   scratchpad_address_a <= std_logic_vector(SS_Adr(7 downto 0)) when (SS_wren_SCP = '1' or SS_rden_SCP = '1') else std_logic_vector(executeMemWriteAddr(9 downto 2));
   scratchpad_data_a    <= SS_DataWrite                         when (SS_wren_SCP = '1') else std_logic_vector(executeMemWriteData);
   
   scratchpad_address_b <= std_logic_vector(executeReadAddress(9 downto 2));
   
   gscratchpad: for i in 0 to 3 generate
   begin
      icache: entity work.dpram
      generic map ( addr_width => 8, data_width => 8)
      port map
      (
         clock_a     => clk1x,
         clken_a     => ce or SS_wren_SCP or SS_rden_SCP,
         address_a   => scratchpad_address_a,
         data_a      => scratchpad_data_a((8*i) + 7 downto (8*i)),
         wren_a      => scratchpad_wren_a(i),
         q_a         => scratchpad_q_a((8*i) + 7 downto (8*i)),
         
         clock_b     => clk2x,
         address_b   => scratchpad_address_b,
         data_b      => x"00",
         wren_b      => '0',
         q_b         => scratchpad_q_b((8*i) + 7 downto (8*i))
      );
   end generate; 
   
   scratchpad_dataread <= unsigned(scratchpad_q_b);
   
   
   -- datacache ###############################################
   dcache_write_enable <= '1' when (ram_done = '1' and mem4_pending = '1' and writebackReadAddress(28 downto 0) < 16#800000#) else 
                          '1' when (mem4_request = '1' and mem4_rnw = '0') else 
                          '1' when (dma_cache_write = '1') else
                          '0';
                          
   dcache_write_clear  <=  '1' when (mem4_request = '1' and mem4_rnw = '0' and executeMemWriteMask /= "1111") else '0';
                          
   dcache_write_addr   <= dma_cache_Adr(20 downto 2)                         when (dma_cache_write = '1') else
                          std_logic_vector(executeMemWriteAddr(20 downto 2)) when (mem4_request = '1' and mem4_rnw = '0') else 
                          std_logic_vector(writebackReadAddress(20 downto 2));

   dcache_write_data   <= dma_cache_data  when (dma_cache_write = '1') else
                          ram_dataRead    when (ram_done = '1' and mem4_pending = '1') else
                          mem4_dataWrite;

   dcache_read_enable  <= ce when (stall = 0 and executeReadEnable = '1' and executeReadAddress(28 downto 0) < 16#800000#) else '0';
   
   dcache_read_addr    <= std_logic_vector(executeReadAddress(20 downto 2));

   idatacache : entity work.datacache
   generic map
   (
      SIZE              => 16384,
      SIZEBASEBITS      => 19,
      BITWIDTH          => 32
   )
   port map
   (
      clk1x             => clk1x,
      clk2x             => clk2x,
      reset             => reset,
      halfrate          => TURBO_CACHE50,
                        
      read_enable       => dcache_read_enable,  -- only used for calculating cache hit ratio
      read_addr         => dcache_read_addr,   
      read_hit          => dcache_read_hit,   
      read_data         => dcache_read_data,   

      write_enable      => dcache_write_enable,
      write_clear       => dcache_write_clear,
      write_addr        => dcache_write_addr,  
      write_data        => dcache_write_data 
   );
   
   -- stage 4 processes ########################################
   
   spad_cache_dataread <= scratchpad_dataread when ((executeReadAddress(31 downto 29) = 0 or executeReadAddress(31 downto 29) = 4) and executeReadAddress(28 downto 10) = 16#7E000#) else
                          unsigned(dcache_read_data);
   
   process (stall, exception, executeMemWriteEnable, executeMemWriteAddr, executeMemWriteData, cop0_SR, CACHECONTROL, stall4, executeReadEnable, executeReadAddress, executeLoadType, executeMemWriteMask, 
            SS_wren_SCP, SS_rden_SCP, mem_fifofull, executeCOP0WriteEnable, executeCOP0WriteDestination, executeCOP0WriteValue, dcache_read_hit, TURBO_CACHE, writebackGTEReadEnable,
            mem_done, memoryMuxStage4, mem4_pending, lateReadReqDone, exceptionNew, EXEReadEnable, EXEMemWriteEnable)
      variable skipmem : std_logic;
   begin
   
      mem4_request   <= '0';
      stallNew4      <= stall4;
      
      WBCACHECONTROL <= CACHECONTROL;
      
      mem4_address   <= executeMemWriteAddr;
      mem4_rnw       <= '1';
      mem4_dataWrite <= std_logic_vector(executeMemWriteData);
      mem4_reqsize   <= "10";
      
      WBinvalidateCacheEna  <= '0';
      WBinvalidateCacheLine <= executeMemWriteAddr(11 downto 4);
      
      scratchpad_wren_a    <= "0000";
      
      -- ############
      -- stall handling for data load pipeline
      -- ############
      if (mem4_pending = '1') then
         -- unstalling possible after read request has been sent, but only if next command is no read/write and data is not going to GTE
         if (lateReadReqDone = '1' and executeReadEnable = '0' and writebackGTEReadEnable = '0' and executeMemWriteEnable = '0') then 
            stallNew4 <= '0';
         end if;
         
         -- stall when exception happens next
         if (exceptionNew /= 0) then
            stallNew4 <= '1';
         end if;
         
         -- stall when next action would be a read/write request
         if (EXEReadEnable = '1' or EXEMemWriteEnable = '1') then
            stallNew4 <= '1';
         end if;
         
         -- stall when GTE would be accessed ?
         --if (EXEgte_writeEna = '1' or EXEgte_cmdEna = '1') then
         --   stallNew4 <= '1';
         --end if;
         
         -- must stall for 1 cycle when data is received to have a spot in register write
         if (mem_done = '1' and memoryMuxStage4 = '1' and writebackGTEReadEnable = '0') then 
            stallNew4   <= '1';
         end if;
      end if;
      
      -- ############
      -- Load/Store
      -- ############
      
      if (exception(4 downto 3) = 0 and stall = 0) then
      
         if (executeMemWriteEnable = '1') then
            skipmem := '0';
         
            case (to_integer(unsigned(executeMemWriteAddr(31 downto 29)))) is
            
               when 0 | 4 => -- cached
                  if (cop0_SR(16) = '1') then -- cache isolation
                     skipmem               := '1';
                     WBinvalidateCacheEna  <= '1';
                  end if;
                  
                  if (executeMemWriteAddr(28 downto 10) = 16#7E000#) then -- scratchpad
                     skipmem := '1';
                     scratchpad_wren_a <= executeMemWriteMask;
                  end if;
                  
               when 6 | 7 => -- KSEG2
                  skipmem := '1';
                  if (executeMemWriteAddr = x"FFFE0130") then
                     WBCACHECONTROL <= executeMemWriteData;
                  end if;
               
               when others => null;
               
            end case;
            
            if (skipmem = '0') then
               mem4_request   <= '1';
               mem4_address   <= executeMemWriteAddr;
               mem4_rnw       <= '0';
               mem4_dataWrite <= std_logic_vector(executeMemWriteData);
               stallNew4      <= mem_fifofull;
            end if;
         
         end if;
         
         if (executeReadEnable = '1') then

            case (executeLoadType) is
               when LOADTYPE_SBYTE => mem4_reqsize <= "00";
               when LOADTYPE_SWORD => mem4_reqsize <= "01";
               when LOADTYPE_LEFT  => mem4_reqsize <= "10"; 
               when LOADTYPE_DWORD => mem4_reqsize <= "10";
               when LOADTYPE_BYTE  => mem4_reqsize <= "00"; 
               when LOADTYPE_WORD  => mem4_reqsize <= "01"; 
               when LOADTYPE_RIGHT => mem4_reqsize <= "10";
            end case;

            if ((executeReadAddress(31 downto 29) = 0 or executeReadAddress(31 downto 29) = 4) and executeReadAddress(28 downto 10) = 16#7E000#) then
               --report "scratchpad access" severity failure;
            elsif (TURBO_CACHE = '1' and executeReadAddress(28 downto 0) < 16#800000# and dcache_read_hit = '1') then
               -- cache hit
            elsif (executeReadAddress = x"FFFE0130") then
               -- cachecontrol
            else 
               mem4_request   <= '1';
               mem4_address   <= executeReadAddress;
               if (executeLoadType = LOADTYPE_LEFT or executeLoadType = LOADTYPE_RIGHT) then 
                  mem4_address(1 downto 0) <= "00";
               end if;
               mem4_rnw       <= '1';
               stallNew4      <= '1';
            end if;
         
         end if;
         
      end if;
      
      -- savestate scratchpad handling
      if (SS_wren_SCP = '1') then
         scratchpad_wren_a     <= "1111";
      end if;
      
      if (SS_rden_SCP = '1') then
         scratchpad_wren_a <= "0000";
      end if;
      
   end process;
   
   --ss_out(22)               <= std_logic_vector(pcOld3);                     
   --ss_out(17)               <= std_logic_vector(opcode3);                                     
                                                 
   ss_out(56)               <= std_logic_vector(CACHECONTROL);               
                                             
   ss_out(47)(4 downto 0)   <= std_logic_vector(writebackTarget);            
   ss_out(42)               <= std_logic_vector(writebackData);              
   ss_out(47)(24)           <= writebackWriteEnable;       

   ss_out(47)(26)           <= writebackException;         
                    
   ss_out(47)(30)           <= writebackGTEReadEnable;     
   ss_out(48)(5 downto 0)   <= std_logic_vector(WBgte_writeAddr);          
   
   process (clk1x)
      variable dataReadData : unsigned(31 downto 0);
      variable oldData      : unsigned(31 downto 0);
   begin
      if (rising_edge(clk1x)) then
      
         if (ce_system = '1') then
            gte_writeEna  <= '0';
            gte_cmdEna    <= '0';
         end if;
      
         if (reset = '1') then
         
            stall4                           <= '0';
                              
            --pcOld3                           <= unsigned(ss_in(22));
            --opcode3                          <= unsigned(ss_in(17));
                              
            CACHECONTROL                     <= unsigned(ss_in(56));
                        
            writebackTarget                  <= unsigned(ss_in(47)(4 downto 0));
            writebackData                    <= unsigned(ss_in(42));
            writebackWriteEnable             <= ss_in(47)(24);
         
            writebackInvalidateCacheEna      <= '0'; -- todo: only used in BIOS?
            
            writebackException               <= ss_in(47)(26);
            
            writebackGTEReadEnable           <= ss_in(47)(30);
            WBgte_writeAddr                  <= unsigned(ss_in(48)(5 downto 0));
            
            gte_writeEna                     <= '0';
            gte_cmdEna                       <= '0';
            
            lateReadWrite                    <= '0';
            lateReadBypass                   <= '0';
            lateReadReqDone                  <= '0';
            
         elsif (ce = '1') then
         
            stall4         <= stallNew4;
            dataReadData   := unsigned(mem_dataRead);
            oldData        := writebackData;
            
            writebackInvalidateCacheEna  <= WBinvalidateCacheEna; 
            writebackInvalidateCacheLine <= WBinvalidateCacheLine;   
            
            if (lateReadBypass = '1' and stall4 = '0') then
               lateReadRam <= '0';
            end if;
            
            lateReadReqDone <= '0';
            if (mem4_request = '1' and mem4_rnw = '1') then
               lateReadReqDone <= '1';

               -- need to compensate for timing in original design on back to back reads:
               -- this is due to unclear reason why the original design is slower here than it could be
               if (lateReadBypass = '1') then
                  -- one additional wait cycle if target of first read is to be used after second read
                  if ((decodeReqSource1 = '1' and decodeSource1 = lateReadTarget) or (decodeReqSource2 = '1' and decodeSource2 = lateReadTarget)) then
                     lateReadStall <= not TURBO;
                  end if;
                  -- one additional wait cycle if target of both reads is the same and goes to ram
                  if (resultTarget = lateReadTarget and executeReadAddress(28 downto 0) < 16#800000# and lateReadRam = '1') then
                     lateReadStall <= not TURBO;
                  end if;
               end if;
               if (executeReadAddress(28 downto 0) < 16#800000#) then
                  lateReadRam <= '1';
               end if;
            end if;
            
            if (resultWriteEnable = '1' and mem4_pending = '1' and resultTarget = lateReadTarget) then
               lateReadWriteAfterWrite <= '1';
            end if;
            
            
            if (stall = 0) then
            
               lateReadBypass <= '0';

               if (exception(4 downto 3) > 0) then
               
                  writebackException           <= '1'; 
                  
               else
-- synthesis translate_off
                  pcOld3                       <= pcOld2;
                  opcode3                      <= opcode2;
-- synthesis translate_on
               
                  writebackTarget              <= resultTarget;
                  writebackData                <= resultData;
                  
                  writebackException           <= executeException;
                           
                  CACHECONTROL                 <= WBCACHECONTROL;
                  
                  writebackGTEReadEnable       <= executeGTEReadEnable;
                  WBgte_writeAddr              <= '0' & executeGTETarget;
                  
                  oldData := resultData;
                  if (lateReadTarget = resultTarget and lateReadBypass = '1') then
                     oldData := lateReadData;
                  elsif (writebackTarget = resultTarget and writebackWriteEnable = '1') then
                     oldData := writebackData;
                  end if;
                  
                  writebackWriteEnable <= '0';
                  if (executeReadEnable = '1') then
                     if (((executeReadAddress(31 downto 29) = 0 or executeReadAddress(31 downto 29) = 4) and executeReadAddress(28 downto 10) = 16#7E000#) or -- scratchpad read
                        (TURBO_CACHE = '1' and executeReadAddress(28 downto 0) < 16#800000# and dcache_read_hit = '1')) then -- data cache read
                        if (executeGTEReadEnable = '1') then
                           gte_writeAddr <= '0' & executeGTETarget;
                           gte_writeData <= spad_cache_dataread;
                           gte_writeEna  <= '1';
                        else
                           writebackWriteEnable <= '1';

                           case (executeLoadType) is
                              when LOADTYPE_SBYTE => 
                                 case (executeReadAddress(1 downto 0)) is 
                                    when "00" => writebackData <= unsigned(resize(signed(spad_cache_dataread( 7 downto  0)), 32));
                                    when "01" => writebackData <= unsigned(resize(signed(spad_cache_dataread(15 downto  8)), 32));
                                    when "10" => writebackData <= unsigned(resize(signed(spad_cache_dataread(23 downto 16)), 32));
                                    when "11" => writebackData <= unsigned(resize(signed(spad_cache_dataread(31 downto 24)), 32));
                                    when others => null;
                                 end case;  
                                    
                              when LOADTYPE_SWORD => 
                                 if (executeReadAddress(1) = '0') then
                                    writebackData <= unsigned(resize(signed(spad_cache_dataread(15 downto 0)), 32));
                                 else
                                    writebackData <= unsigned(resize(signed(spad_cache_dataread(31 downto 16)), 32));
                                 end if;
                                    
                              when LOADTYPE_LEFT =>
                                 case (to_integer(executeReadAddress(1 downto 0))) is
                                    when 0 => writebackData <= spad_cache_dataread( 7 downto 0) & oldData(23 downto 0);
                                    when 1 => writebackData <= spad_cache_dataread(15 downto 0) & oldData(15 downto 0);
                                    when 2 => writebackData <= spad_cache_dataread(23 downto 0) & oldData( 7 downto 0); 
                                    when 3 => writebackData <= spad_cache_dataread;
                                    when others => null;
                                 end case;
                                    
                              when LOADTYPE_DWORD => writebackData <= spad_cache_dataread;
                              
                              when LOADTYPE_BYTE  =>
                                 case (executeReadAddress(1 downto 0)) is 
                                    when "00" => writebackData <= x"000000" & spad_cache_dataread( 7 downto  0);
                                    when "01" => writebackData <= x"000000" & spad_cache_dataread(15 downto  8);
                                    when "10" => writebackData <= x"000000" & spad_cache_dataread(23 downto 16);
                                    when "11" => writebackData <= x"000000" & spad_cache_dataread(31 downto 24);
                                    when others => null;
                                 end case;  
                              
                              when LOADTYPE_WORD  => 
                                 if (executeReadAddress(1) = '0') then
                                    writebackData <= x"0000" & spad_cache_dataread(15 downto 0);
                                 else
                                    writebackData <= x"0000" & spad_cache_dataread(31 downto 16);
                                 end if;
                              
                              when LOADTYPE_RIGHT =>
                                 case (to_integer(executeReadAddress(1 downto 0))) is
                                    when 0 => writebackData <= spad_cache_dataread;
                                    when 1 => writebackData <= oldData(31 downto 24) & spad_cache_dataread(31 downto  8);
                                    when 2 => writebackData <= oldData(31 downto 16) & spad_cache_dataread(31 downto 16);
                                    when 3 => writebackData <= oldData(31 downto  8) & spad_cache_dataread(31 downto 24);
                                    when others => null;
                                 end case;
                           end case;
                        end if;
                     elsif (executeReadAddress = x"FFFE0130") then
                        writebackWriteEnable <= '1';
                        writebackData        <= CACHECONTROL;
                     else
                        writebackLoadType       <= executeLoadType;
                        writebackReadAddress    <= executeReadAddress;
                        lateReadTarget          <= resultTarget;
                        lateReadOldData         <= oldData;
                        lateReadWriteAfterWrite <= '0';
                     end if;
                  else
                     writebackWriteEnable <= resultWriteEnable;
                  end if;
                  
                  if (execute_gte_writeEna = '1') then
                     gte_writeAddr <= execute_gte_writeAddr;
                     gte_writeData <= execute_gte_writeData;
                     gte_writeEna  <= '1';
                  end if;
                  
                  if (execute_gte_cmdEna = '1') then
                     gte_cmdData <= execute_gte_cmdData;
                     gte_cmdEna  <= '1';
                  end if;
                  
                  
               end if;
               
            else

               if (mem_fifofull = '0' and mem4_pending = '0') then
                  lateReadStall <= '0';
                  if (lateReadStall = '0') then
                     stall4 <= '0';
                  end if;
               end if;
               
               lateReadWrite <= '0';
               
               if (lateReadWrite = '1') then
                  lateReadBypass <= '1';
               end if;
               
            end if;
            
            if (mem_done = '1' and memoryMuxStage4 = '1') then
               if (writebackGTEReadEnable = '1') then
                  gte_writeAddr <= WBgte_writeAddr;
                  gte_writeData <= dataReadData;
                  gte_writeEna  <= '1';
               else
                  if (lateReadTarget > 0 and lateReadWriteAfterWrite = '0') then
                     if (resultWriteEnable = '0' or resultTarget /= lateReadTarget) then -- write after write in same cycle -> ignore
                        lateReadWrite <= '1';
                     else
                        lateReadRam   <= '0';
                     end if;
                  end if;

                  case (writebackLoadType) is
                     
                     when LOADTYPE_SBYTE => lateReadData <= unsigned(resize(signed(dataReadData(7 downto 0)), 32));
                     when LOADTYPE_SWORD => lateReadData <= unsigned(resize(signed(dataReadData(15 downto 0)), 32));
                     when LOADTYPE_LEFT =>
                        case (to_integer(writebackReadAddress(1 downto 0))) is
                           when 0 => lateReadData <= dataReadData( 7 downto 0) & lateReadOldData(23 downto 0);
                           when 1 => lateReadData <= dataReadData(15 downto 0) & lateReadOldData(15 downto 0);
                           when 2 => lateReadData <= dataReadData(23 downto 0) & lateReadOldData( 7 downto 0); 
                           when 3 => lateReadData <= dataReadData;
                           when others => null;
                        end case;
                           
                     when LOADTYPE_DWORD => lateReadData <= dataReadData;
                     when LOADTYPE_BYTE  => lateReadData <= x"000000" & dataReadData(7 downto 0);
                     when LOADTYPE_WORD  => lateReadData <= x"0000" & dataReadData(15 downto 0);
                     when LOADTYPE_RIGHT =>
                        case (to_integer(writebackReadAddress(1 downto 0))) is
                           when 0 => lateReadData <= dataReadData;
                           when 1 => lateReadData <= lateReadOldData(31 downto 24) & dataReadData(31 downto  8);
                           when 2 => lateReadData <= lateReadOldData(31 downto 16) & dataReadData(31 downto 16);
                           when 3 => lateReadData <= lateReadOldData(31 downto  8) & dataReadData(31 downto 24);
                           when others => null;
                        end case;
                        
                  end case;
               end if;   
            end if;
            
            
   
         end if;
         
         if (SS_wren_SCP = '1') then
            writebackInvalidateCacheEna  <= '1';
            writebackInvalidateCacheLine <= SS_Adr(7 downto 0);
         end if;
         
      end if;
   end process;
   
   --ss_out(23)              <= std_logic_vector(pcOld4);
   --ss_out(18)              <= std_logic_vector(opcode4);
   
   ss_out(50)(12 downto 8) <= std_logic_vector(writeDoneTarget);
   ss_out(49)              <= std_logic_vector(writeDoneData);
   ss_out(50)(16)          <= writeDoneWriteEnable;
   
--##############################################################
--############################### stage 5
--##############################################################
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
-- synthesis translate_off
         cpu_done <= '0';
         
         debugTmr <= debugTmr + 1;
-- synthesis translate_on
      
         if (reset = '1') then
            
            --pcOld4               <= unsigned(ss_in(23));
            --opcode4              <= unsigned(ss_in(18));
            
            writeDoneTarget      <= unsigned(ss_in(50)(12 downto 8));
            writeDoneData        <= unsigned(ss_in(49));
            writeDoneWriteEnable <= ss_in(50)(16);
            
-- synthesis translate_off
            debugCnt             <= (others => '0');
            debugSum             <= (others => '0');
            debugTmr             <= (others => '0');
-- synthesis translate_on
         
         elsif (ce = '1') then
            
            if (stall = 0) then
            
-- synthesis translate_off
               pcOld4               <= pcOld3;
               opcode4              <= opcode3;
-- synthesis translate_on
            
               writeDoneTarget      <= writebackTarget;     
               writeDoneData        <= writebackData;       
               writeDoneWriteEnable <= writebackWriteEnable;
               
               -- export
               if (writebackWriteEnable = '1' and writebackException = '0') then 
                  if (writebackTarget > 0) then
-- synthesis translate_off
                     regs(to_integer(writebackTarget)) <= writebackData;
                     debugSum <= debugSum + writebackData;
-- synthesis translate_on
                  end if;
               end if;
               
-- synthesis translate_off
               debugCnt          <= debugCnt+ 1;

               cpu_done          <= '1';
               cpu_export.pc     <= pcOld4;
               cpu_export.opcode <= opcode4;
               cpu_export.cause  <= cop0_CAUSE;
               for i in 0 to 31 loop
                  cpu_export.regs(i) <= regs(i);
               end loop;
               
               if (debugCnt(31) = '1' and debugSum(31) = '1' and debugTmr(31) = '1' and writebackTarget = 0) then
                  writeDoneWriteEnable <= '0';
               end if;
-- synthesis translate_on
               
            end if;
            
-- synthesis translate_off
            if (lateReadBypass = '1') then
               regs(to_integer(lateReadTarget)) <= lateReadData;
            end if;
-- synthesis translate_on
   
         end if;
         
         -- export
-- synthesis translate_off
         if (ss_regs_load = '1') then
            regs(to_integer(ss_regs_addr)) <= unsigned(ss_regs_data);
         end if; 
-- synthesis translate_on
         
      end if;
   end process;
   
--##############################################################
--############################### exception handling
--##############################################################

   ss_out(24)(9 downto 5)  <= std_logic_vector(exception);      

   ss_out(7)               <= std_logic_vector(cop0_BADVADDR);  

   ss_out(51)              <= std_logic_vector(exception_SR);   
   ss_out(52)              <= std_logic_vector(exception_CAUSE);
   ss_out(53)              <= std_logic_vector(exception_EPC);  
   ss_out(54)              <= std_logic_vector(exception_JMP);  

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (reset = '1') then
         
            exception            <= unsigned(ss_in(24)(9 downto 5));
         
            cop0_BADVADDR        <= unsigned(ss_in(7));
            
            exception_SR         <= unsigned(ss_in(51));
            exception_CAUSE      <= unsigned(ss_in(52));
            exception_EPC        <= unsigned(ss_in(53));
            exception_JMP        <= unsigned(ss_in(54));

         elsif (ce = '1') then
            
            if (stall = 0) then
         
               exception <= exceptionNew;
               if (exceptionNew1 = '1') then    -- PC out of bounds
                  exceptionCode     <= x"6";
                  exceptionInstr    <= opcode2(27 downto 26);
                  exception_PC      <= PCnext;
                  exception_branch  <= executeBranchTaken;
                  exception_brslot  <= executeBranchdelaySlot;
               elsif (exceptionNew5 = '1') then -- interrupt
                  exceptionCode     <= x"0";
                  exceptionInstr    <= opcode1(27 downto 26);
                  exception_PC      <= pcOld1;
                  exception_branch  <= executeBranchTaken;
                  exception_brslot  <= executeBranchdelaySlot;
               else                             -- execute stage
                  exceptionCode     <= exceptionCode_3;
                  exceptionInstr    <= opcode1(27 downto 26);
                  if (EXEBranchTaken = '1') then
                     exception_PC      <= PCbranch;
                     exception_branch  <= '0';
                     exception_brslot  <= '0';
                     if (exceptionNew3 = '1') then
                        cop0_BADVADDR     <= PCbranch;
                     end if;
                  else
                     exception_PC      <= PCold1;
                     exception_branch  <= executeBranchTaken;
                     exception_brslot  <= executeBranchdelaySlot;
                     if (EXEMemWriteException = '1' or EXEReadException = '1') then
                        cop0_BADVADDR  <= EXEMemAddr;
                     end if;
                  end if;
               end if;
               exception_JMPnext <= PCold0;
               
               if (exception > 0) then
                  exception_SR    <= cop0_SR(31 downto 6) & cop0_SR(3 downto 0) & "00";
                  exception_CAUSE <= cop0_CAUSE;
                  exception_CAUSE(5 downto 2)   <= exceptionCode;
                  exception_CAUSE(29 downto 28) <= exceptionInstr; 
                  exception_CAUSE(30) <= exception_branch;
                  exception_CAUSE(31) <= exception_brslot;
                  if (exception_brslot = '1') then
                     exception_EPC <= exception_PC - 4;
                     exception_JMP <= exception_JMPnext;
                  else
                     exception_EPC <= exception_PC;
                  end if;
               end if;
               
            end if;
   
         end if;
      end if;
   end process;
   
--##############################################################
--############################### submodules
--##############################################################
   
   idivider : entity work.divider
   port map
   (
      clk       => clk1x,      
      start     => DIVstart,
      done      => open,      
      busy      => open,
      dividend  => DIVdividend, 
      divisor   => DIVdivisor,  
      quotient  => DIVquotient, 
      remainder => DIVremainder
   );
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         ss_regs_load <= '0';
      
         if (SS_reset = '1') then
         
            for i in 0 to 56 loop
               ss_in(i) <= (others => '0');
            end loop;
            
            ss_in(0)  <= x"BFC00000"; -- PC
            ss_in(13) <= x"00000002"; -- cop0_PRID
            
            ss_regs_loading <= '1';
            ss_regs_addr    <= (others => '0');
            ss_regs_data    <= (others => '0');
            
         elsif (SS_wren_CPU = '1' and SS_Adr < 96) then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
            
         elsif (SS_wren_CPU = '1' and SS_Adr >= 96 and SS_Adr < 128) then
            ss_regs_load <= '1';
            ss_regs_addr <= resize(SS_Adr - 96, 5);
            ss_regs_data <= SS_DataWrite;
         end if;
         
         if (ss_regs_loading = '1') then
            ss_regs_load <= '1';
            ss_regs_addr <= ss_regs_addr + 1;
            if (ss_regs_addr = 31) then
               ss_regs_loading <= '0';
            end if;
         end if;
      
         -- also check this?
         -- cop0_SR(10 downto 8) and cop0_CAUSE(10 downto 8)) /= "000"
         SS_idle <= '0';
         if (hiloWait = 0 and blockIRQ = '0' and (irqRequest = '0' or cop0_SR(0) = '0') and mem_done = '0' and lateReadWrite = '0' and lateReadBypass = '0') then
            SS_idle <= '1';
         end if;
      
         regsSS_rden <= '0';
         if (SS_rden_CPU = '1' and SS_Adr >= 96 and SS_Adr < 128) then
            regsSS_address_b <= std_logic_vector(resize(SS_Adr - 96, 5));
            regsSS_rden      <= '1';
         end if;
         
         if (regsSS_rden = '1') then
            SS_DataRead_CPU <= regsSS_q_b;
         elsif (SS_rden_CPU = '1' and SS_Adr < 96) then
            SS_DataRead_CPU <= ss_out(to_integer(SS_Adr));
         end if;
      
         ss_scp_rden_1 <= SS_rden_SCP;
         if (ss_scp_rden_1 = '1') then
            SS_DataRead_SCP <= scratchpad_q_a;
         end if;
      
      end if;
   end process;
   
--##############################################################
--############################### debug
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         error  <= '0';
         error2 <= '0';
      
         if (reset = '1') then
         
            debugStallcounter <= (others => '0');
            debug300exception <= '0';
            
-- synthesis translate_off
            stallcountNo      <= 0;
            stallcount1       <= 0;
            stallcount3       <= 0;
            stallcount4       <= 0;
            stallcountDMA     <= 0;
-- synthesis translate_on
      
         elsif (ce = '1') then
         
            if (stall = 0) then
               debugStallcounter <= (others => '0');
            else  
               debugStallcounter <= debugStallcounter + 1;
            end if;
            
            debug300exception <= '0';
            if (mem_request = '1' and mem_isData = '1' and mem_rnw = '1' and mem_addressData = x"00000300") then
               debug300exception <= '1';
            end if;
            
            if (debug300exception = '1') then
               error        <= '1';
            end if;            
            
            if (debugStallcounter(9) = '1') then
               error2       <= '1';
            end if;
            
-- synthesis translate_off
            
            if (stallcountNo = 0 and stallcount4 = 0 and stallcount3 = 0 and stallcount1 = 0 and stallcountDMA = 0) then
               stallcountNo <= 0;
            end if;
            
            -- performance counters
            if (stall = 0) then
               stallcountNo <= stallcountNo + 1;
            elsif (stall4 = '1') then
               stallcount4 <= stallcount4 + 1;
            elsif (stall3 = '1') then
               stallcount3 <= stallcount3 + 1;
            elsif (stall1 = '1') then
               stallcount1 <= stallcount1 + 1;
            end if;
            
         else
            
            stallcountDMA <= stallcountDMA + 1;
            
-- synthesis translate_on
            
         end if;
         
      end if;
   end process;
   
   

end architecture;





