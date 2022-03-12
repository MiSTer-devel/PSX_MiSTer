library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;

entity spu is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      SPUon                : in  std_logic;
      useSDRAM             : in  std_logic;
      REPRODUCIBLESPUIRQ   : in  std_logic;
      REPRODUCIBLESPUDMA   : in  std_logic;
      REVERBOFF            : in  std_logic;
      
      cpuPaused            : in  std_logic;
      
      spu_tick             : out std_logic := '0';
      cd_left              : in  signed(15 downto 0);
      cd_right             : in  signed(15 downto 0);
      
      irqOut               : out std_logic := '0';
      
      sound_timeout        : out std_logic := '0';
      
      sound_out_left       : out std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right      : out std_logic_vector(15 downto 0) := (others => '0');
      
      bus_addr             : in  unsigned(9 downto 0); 
      bus_dataWrite        : in  std_logic_vector(15 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(15 downto 0);
      
      spu_dmaRequest       : out std_logic;
      dma_read             : in  std_logic;
      dma_readdata         : out std_logic_vector(15 downto 0);     
      dma_write            : in  std_logic;
      dma_writedata        : in  std_logic_vector(15 downto 0);
      
      -- SDRAM interface        
      sdram_dataWrite      : out std_logic_vector(31 downto 0);
      sdram_Adr            : out std_logic_vector(18 downto 0);
      sdram_be             : out std_logic_vector(3 downto 0);
      sdram_rnw            : out std_logic;
      sdram_ena            : out std_logic;
      sdram_dataRead       : in  std_logic_vector(31 downto 0);
      sdram_done           : in  std_logic;
      
      -- DDR3 interface
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
      
      -- savestates
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(8 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0);
      SS_idle              : out std_logic;
      
      SS_RAM_dataWrite     : in  std_logic_vector(15 downto 0);
      SS_RAM_Adr           : in  std_logic_vector(18 downto 0);
      SS_RAM_request       : in  std_logic;
      SS_RAM_rnw           : in  std_logic;
      SS_RAM_dataRead      : out std_logic_vector(15 downto 0);
      SS_RAM_done          : out std_logic
   );
end entity;

architecture arch of spu is

   function clamp16(value_in: signed) return signed is
      variable result: signed(15 downto 0);
   begin
 
      if (value_in < -32768) then result := x"8000";
      elsif (value_in > 32767) then result := x"7FFF";
      else result := value_in(15 downto 0);
      end if;
      
      return result;  
   end;
   
   -- voiceregs
   signal RamVoice_addrA      : unsigned(7 downto 0) := (others => '0');
   signal RamVoice_dataA      : std_logic_vector(15 downto 0) := (others => '0');
   signal RamVoice_write      : std_logic := '0';     
   
   type tvoiceregs_addrB is array(0 to 1) of unsigned(7 downto 0);
   signal RamVoice_addrB      : tvoiceregs_addrB;
   
   type tvoiceregs_dataB is array(0 to 1) of std_logic_vector(15 downto 0);
   signal RamVoice_dataB     : tvoiceregs_dataB; 
  
   -- adpcm ram
   type tadpcm_addr is array(0 to 3) of unsigned(7 downto 0);
   type tadpcm_data is array(0 to 3) of std_logic_vector(15 downto 0);
   
   signal adpcm_ram_address_a : unsigned(7 downto 0) := (others => '0'); 
   signal adpcm_ram_data_a    : tadpcm_data := (others => (others => '0'));  
   signal adpcm_ram_wren_a    : std_logic_vector(3 downto 0) := (others => '0'); 
   signal adpcm_ram_address_b : tadpcm_addr := (others => (others => '0')); 
   signal adpcm_ram_q_b       : tadpcm_data; 

   -- voice volume
   signal RamVoiceVolumes_addrA      : unsigned(5 downto 0) := (others => '0');
   signal RamVoiceVolumes_dataA      : std_logic_vector(15 downto 0) := (others => '0');
   signal RamVoiceVolumes_write      : std_logic := '0';     
   
   type tvoiceVolumes_addrB is array(0 to 1) of unsigned(5 downto 0);
   signal RamVoiceVolumes_addrB      : tvoiceVolumes_addrB;
   
   type tvoiceVolumes_dataB is array(0 to 1) of std_logic_vector(15 downto 0);
   signal RamVoiceVolumes_dataB      : tvoiceVolumes_dataB; 
   
   -- envelope counter ram
   signal EnvCounterRam_addrA : unsigned(5 downto 0) := (others => '0');
   signal EnvCounterRam_addrB : unsigned(5 downto 0) := (others => '0');
   signal EnvCounterRam_dataA : std_logic_vector(24 downto 0) := (others => '0');
   signal EnvCounterRam_dataB : std_logic_vector(24 downto 0) := (others => '0');
   signal EnvCounterRam_write : std_logic := '0';     
   
   -- Regs                          
	signal VOLUME_LEFT         : std_logic_vector(15 downto 0);  -- 0x1F801D80
	signal VOLUME_RIGHT        : std_logic_vector(15 downto 0);  -- 0x1F801D82
                              
	signal KEYON               : std_logic_vector(31 downto 0);  -- 0x1F801D88
	signal KEYOFF              : std_logic_vector(31 downto 0);  -- 0x1F801D8C
	signal PITCHMODENA         : std_logic_vector(31 downto 0);  -- 0x1F801D90
	signal NOISEMODE           : std_logic_vector(31 downto 0);  -- 0x1F801D94
	signal REVERBON            : std_logic_vector(31 downto 0);  -- 0x1F801D98
	signal ENDX                : std_logic_vector(31 downto 0);  -- 0x1F801D9C
                              
	signal IRQ_ADDR            : std_logic_vector(15 downto 0);  -- 0x1F801DA4
   
	signal TRANSFERADDR        : std_logic_vector(15 downto 0);  -- 0x1F801DA6
                              
	signal CNT                 : std_logic_vector(15 downto 0);  -- 0x1F801DAA
	signal TRANSFER_CNT        : std_logic_vector(15 downto 0);  -- 0x1F801DAC
	signal STAT                : std_logic_vector(15 downto 0);  -- 0x1F801DAE
                              
	signal CDAUDIO_VOL_L       : std_logic_vector(15 downto 0);  -- 0x1F801DB0	
	signal CDAUDIO_VOL_R       : std_logic_vector(15 downto 0);  -- 0x1F801DB2	
	signal EXT_VOL_L           : std_logic_vector(15 downto 0);  -- 0x1F801DB4	
	signal EXT_VOL_R           : std_logic_vector(15 downto 0);  -- 0x1F801DB6	
	signal CURVOL_L            : std_logic_vector(15 downto 0);  -- 0x1F801DB8	
	signal CURVOL_R            : std_logic_vector(15 downto 0);  -- 0x1F801DBA	
   
	signal REVERB_vLOUT        : std_logic_vector(15 downto 0);  -- 0x1F801D84
	signal REVERB_vROUT        : std_logic_vector(15 downto 0);  -- 0x1F801D86
	signal REVERB_mBASE        : std_logic_vector(15 downto 0);  -- 0x1F801DA2
	signal REVERB_dAPF1        : std_logic_vector(15 downto 0);  -- 0x1F801DC0
	signal REVERB_dAPF2        : std_logic_vector(15 downto 0);  -- 0x1F801DC2
	signal REVERB_vIIR         : std_logic_vector(15 downto 0);  -- 0x1F801DC4
	signal REVERB_vCOMB1       : std_logic_vector(15 downto 0);  -- 0x1F801DC6
	signal REVERB_vCOMB2       : std_logic_vector(15 downto 0);  -- 0x1F801DC8
	signal REVERB_vCOMB3       : std_logic_vector(15 downto 0);  -- 0x1F801DCA
	signal REVERB_vCOMB4       : std_logic_vector(15 downto 0);  -- 0x1F801DCC
	signal REVERB_vWALL        : std_logic_vector(15 downto 0);  -- 0x1F801DCE
	signal REVERB_vAPF1        : std_logic_vector(15 downto 0);  -- 0x1F801DD0
	signal REVERB_vAPF2        : std_logic_vector(15 downto 0);  -- 0x1F801DD2
	signal REVERB_mLSAME       : std_logic_vector(15 downto 0);  -- 0x1F801DD4
	signal REVERB_mRSAME       : std_logic_vector(15 downto 0);  -- 0x1F801DD6
	signal REVERB_mLCOMB1      : std_logic_vector(15 downto 0);  -- 0x1F801DD8
	signal REVERB_mRCOMB1      : std_logic_vector(15 downto 0);  -- 0x1F801DDA
	signal REVERB_mLCOMB2      : std_logic_vector(15 downto 0);  -- 0x1F801DDC
	signal REVERB_mRCOMB2      : std_logic_vector(15 downto 0);  -- 0x1F801DDE
	signal REVERB_dLSAME       : std_logic_vector(15 downto 0);  -- 0x1F801DE0
	signal REVERB_dRSAME       : std_logic_vector(15 downto 0);  -- 0x1F801DE2
	signal REVERB_mLDIFF       : std_logic_vector(15 downto 0);  -- 0x1F801DE4
	signal REVERB_mRDIFF       : std_logic_vector(15 downto 0);  -- 0x1F801DE6
	signal REVERB_mLCOMB3      : std_logic_vector(15 downto 0);  -- 0x1F801DE8
	signal REVERB_mRCOMB3      : std_logic_vector(15 downto 0);  -- 0x1F801DEA
	signal REVERB_mLCOMB4      : std_logic_vector(15 downto 0);  -- 0x1F801DEC
	signal REVERB_mRCOMB4      : std_logic_vector(15 downto 0);  -- 0x1F801DEE
	signal REVERB_dLDIFF       : std_logic_vector(15 downto 0);  -- 0x1F801DF0
	signal REVERB_dRDIFF       : std_logic_vector(15 downto 0);  -- 0x1F801DF2
	signal REVERB_mLAPF1       : std_logic_vector(15 downto 0);  -- 0x1F801DF4
	signal REVERB_mRAPF1       : std_logic_vector(15 downto 0);  -- 0x1F801DF6
	signal REVERB_mLAPF2       : std_logic_vector(15 downto 0);  -- 0x1F801DF8
	signal REVERB_mRAPF2       : std_logic_vector(15 downto 0);  -- 0x1F801DFA
	signal REVERB_vLIN         : std_logic_vector(15 downto 0);  -- 0x1F801DFC
	signal REVERB_vRIN         : std_logic_vector(15 downto 0);  -- 0x1F801DFE
   
   -- fifoIn
   signal FifoIn_reset        : std_logic := '0';
   signal FifoIn_Din          : std_logic_vector(15 downto 0) := (others => '0');
   signal FifoIn_Wr           : std_logic := '0'; 
   signal FifoIn_Full         : std_logic; 
   signal FifoIn_Dout         : std_logic_vector(15 downto 0);
   signal FifoIn_Rd           : std_logic := '0';
   signal FifoIn_Empty        : std_logic;
   
   -- fifoOut
   signal FifoOut_reset       : std_logic := '0';
   signal FifoOut_Din         : std_logic_vector(15 downto 0) := (others => '0');
   signal FifoOut_Wr          : std_logic := '0'; 
   signal FifoOut_NearFull    : std_logic; 
   signal FifoOut_Dout        : std_logic_vector(15 downto 0);
   signal FifoOut_Rd          : std_logic := '0';
   signal FifoOut_Empty       : std_logic;
   
   signal FifoOut_Cnt         : integer range 0 to 32;
   
   -- Data transfer
   signal ramTransferAddr     : unsigned(18 downto 0);
   
   -- interrupt
   signal IRQ9                : std_logic;
   signal irqSaved            : std_logic;
   
   -- processing
   signal busy                : std_logic := '0';
   signal capturePosition     : unsigned(9 downto 0) := (others => '0');
   signal sampleticks         : unsigned(9 downto 0) := (others => '0');
   signal stashedSamples      : integer range 0 to 15 := 0;
   
   -- ram
   signal ram_dataWrite       : std_logic_vector(15 downto 0) := (others => '0');
   signal ram_Adr             : std_logic_vector(18 downto 0) := (others => '0');
   signal ram_request         : std_logic := '0';
   signal ram_rnw             : std_logic := '0';
   signal ram_dataRead        : std_logic_vector(15 downto 0);
   signal ram_done            : std_logic;
   
   signal ram_isTransfer      : std_logic := '0';
   signal ram_isVoice         : std_logic := '0';
   signal ram_isReverb        : std_logic := '0';
   signal ram_ReverbIndex     : integer range 0 to 9;
   
   -- statemachine
   type tState is
   (
      IDLE,
      
      VOICE_START,
      VOICE_READHEADER,
      VOICE_EVALHEADER,
      VOICE_EVALSAMPLE,
      VOICE_DECODESAMPLE,
      VOICE_PICKSAMPLE,
      VOICE_APPLYADSR,
      VOICE_APPLYVOLUME,
      VOICE_CHECKEND,
      VOICE_CHECKKEY,
      VOICE_END,
      
      RAM_READ,
      RAM_WRITE,
      RAM_WAIT,
      
      REVERB_READ1,
      REVERB_PROCOUT,
      REVERB_WRITE1,
      REVERB_READ2,
      REVERB_PROCIN,
      REVERB_WRITE2,
      REVERB_END,
      
      CAPTURE0,
      CAPTURE1,
      CAPTURE2,
      CAPTURE3
   );
   signal state : tState := IDLE;
   
   signal index        : integer range 0 to 23;
   signal voiceCounter : integer range 0 to 31;
   
   constant ADSRPHASE_OFF     : unsigned(2 downto 0) := "000";
   constant ADSRPHASE_ATTACK  : unsigned(2 downto 0) := "001";
   constant ADSRPHASE_DECAY   : unsigned(2 downto 0) := "010";
   constant ADSRPHASE_SUSTAIN : unsigned(2 downto 0) := "011";
   constant ADSRPHASE_RELEASE : unsigned(2 downto 0) := "100";
   constant ADSR_OFF         : integer := 0;
   constant ADSR_ATTACK      : integer := 1;
   constant ADSR_DECAY       : integer := 2;
   constant ADSR_SUSTAIN     : integer := 3;
   constant ADSR_RELEASE     : integer := 4;
   type voiceRecord is record
      currentAddr      : unsigned(15 downto 0);
      adpcmLast0       : signed(15 downto 0);
      adpcmLast1       : signed(15 downto 0);
      adpcmSamplePos   : unsigned(19 downto 0);
      adpcmDecodePtr   : unsigned(5 downto 0);
      adsrphase        : unsigned(2 downto 0);
      adsrTicks        : unsigned(23 downto 0);
   end record;
   
   signal voice        : voiceRecord := ((others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'));
   
   signal voice_lastVolume  : signed(15 downto 0);
   signal voice_lastVolume1 : signed(15 downto 0);
   signal voice_lastVolume3 : signed(15 downto 0);
   
   signal voice_adsrWrite   : std_logic_vector(23 downto 0) := (others => '0');
   
   -- voicerecordram
   signal RamVoiceRecord_addrA : unsigned(4 downto 0) := (others => '0');
   signal RamVoiceRecord_dataA : std_logic_vector(100 downto 0) := (others => '0');
   signal RamVoiceRecord_write : std_logic := '0';     
   
   type tvoicerecords_addrB is array(0 to 1) of unsigned(4 downto 0);
   signal RamVoiceRecord_addrB : tvoicerecords_addrB;
   
   type tvoicerecords_dataB is array(0 to 1) of std_logic_vector(100 downto 0);
   signal RamVoiceRecord_dataB : tvoicerecords_dataB; 
   
   --type tvoicearray is array(0 to 23) of voiceRecord;
   --signal voiceArray : tvoicearray := (others => ((others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0')));
   
   -- voice intermediate
   signal adpcmShift     : unsigned(3 downto 0);
   signal adpcmFilter    : unsigned(2 downto 0);
   signal loopEnd        : std_logic;
   signal loopRepeat     : std_logic;
   signal updateRepeat   : std_logic;
   signal sampleIndex    : unsigned(5 downto 0);
   signal adpcmData      : std_logic_vector(15 downto 0);
   signal decodeCnt      : integer range 0 to 3;
   signal filterPos      : integer range -128 to 127;
   signal filterNeg      : integer range -128 to 127;
   
   signal gauss1         : signed(15 downto 0);
   signal gauss2         : signed(15 downto 0);
   signal gauss3         : signed(15 downto 0);
   signal gauss4         : signed(15 downto 0);
   
   type tfilterArray is array(0 to 4) of integer range -128 to 127;
   constant filtertablePos : tfilterArray := ( 0, 60, 115, 98, 122 );
	constant filtertableNeg : tfilterArray := ( 0, 0, -52, -55, -60 );
   
   type tadpcmSamples is array(0 to 3) of signed(15 downto 0);
   --type tadpcmSamples is array(0 to 23, 0 to 30) of signed(15 downto 0);
  -- signal adpcmSamples : tadpcmSamples := (others => (others => (others => '0')));
   signal adpcmSamples : tadpcmSamples := (others => (others => '0'));
   
   signal sample         : signed(15 downto 0);
   signal step           : unsigned(15 downto 0);
   signal volumeSetting  : unsigned(15 downto 0);
   signal volumeSettingR : unsigned(15 downto 0);   
   signal adsrSetting    : unsigned(31 downto 0);
   signal adsrVolume     : signed(15 downto 0);
   signal adsrVolumeNew  : signed(15 downto 0);
   
   signal volume         : signed(16 downto 0);  
   signal volLeft        : signed(15 downto 0);  
   signal volRight       : signed(15 downto 0);  
   signal chanLeft       : signed(17 downto 0);  
   signal chanRight      : signed(17 downto 0);  
   
   signal soundleft      : signed(23 downto 0) := (others => '0');  
   signal soundright     : signed(23 downto 0) := (others => '0');     
    
   -- envelope
   type tenvelopeState is
   (
      ENV_IDLE,
      ENV_START,
      ENV_CALC,
      ENV_WRITE
   );
   signal envelopeState      : tenvelopeState := ENV_IDLE;
   signal envelopeVoice      : std_logic := '0'; 
   signal envelopeRight      : std_logic := '0'; 
   signal envelope_startnext : std_logic := '0'; 
   signal envelopeIndex      : integer range 0 to 49;
   signal envVolume          : signed(15 downto 0);
   signal envTicks           : unsigned(23 downto 0);
   signal envTicksNew        : std_logic := '0'; 
   signal env_step           : signed(15 downto 0);
   signal envVolLeft         : signed(15 downto 0);  
   signal envVolRight        : signed(15 downto 0); 
   
   -- adsr
   type tadsr_rate   is array(0 to 4) of unsigned(6 downto 0);
   type tadsr_ticks  is array(0 to 4) of unsigned(23 downto 0);
   type tadsr_steps  is array(0 to 4) of signed(15 downto 0);
   type tadsr_target is array(0 to 4) of unsigned(14 downto 0);
   
   signal adsr_dec      : std_logic_vector(0 to 4);
   signal adsr_exp      : std_logic_vector(0 to 4);
   signal adsr_rate     : tadsr_rate;
   signal adsr_ticks    : tadsr_ticks;
   signal adsr_step     : tadsr_steps;
   signal adsr_target   : tadsr_target;
   
   signal reset_adsr    : std_logic := '0';
   
   -- reverb
   signal reverbRight            : std_logic := '0';
   signal reverbCurrentAddress   : unsigned(17 downto 0);
   
   signal reverbsumleft          : signed(23 downto 0) := (others => '0');  
   signal reverbsumright         : signed(23 downto 0) := (others => '0');  
   signal reverb_sample          : signed(23 downto 0);
   
   signal reverb_reqAddr         : unsigned(15 downto 0);
   signal reverb_reqAddr2        : unsigned(17 downto 0);
   signal reverbAddAddr          : unsigned(18 downto 0);
   signal reverb_calcAddr        : unsigned(18 downto 0);
   
   signal reverb_count           : integer range 0 to 13;
   
   signal REVERB_mSAME           : unsigned(15 downto 0);
	signal REVERB_mCOMB1          : unsigned(15 downto 0);
	signal REVERB_mCOMB2          : unsigned(15 downto 0);
	signal REVERB_dSAME           : unsigned(15 downto 0);
	signal REVERB_mDIFF           : unsigned(15 downto 0);
	signal REVERB_mCOMB3          : unsigned(15 downto 0);
	signal REVERB_mCOMB4          : unsigned(15 downto 0);
	signal REVERB_dDIFF           : unsigned(15 downto 0);
	signal REVERB_mAPF1           : unsigned(15 downto 0);
	signal REVERB_mAPF2           : unsigned(15 downto 0);
	signal REVERB_vIN             : signed(15 downto 0);
   
   signal reverbReadval1         : signed(15 downto 0);
   signal reverbReadval2         : signed(15 downto 0);
   signal reverbReadval3         : signed(15 downto 0);
   signal reverbReadval4         : signed(15 downto 0);
   signal reverbReadval5         : signed(15 downto 0);
   signal reverbReadval6         : signed(15 downto 0);
   
   signal IIR_INPUT_B            : signed(15 downto 0);
   signal IIR_A                  : signed(15 downto 0);
   signal IIR_B                  : signed(15 downto 0);
   
   signal reverb_acc             : signed(19 downto 0);
   signal apf1neg                : signed(15 downto 0);
   signal apf2neg                : signed(15 downto 0);
   signal MDA                    : signed(15 downto 0);
   signal MDB                    : signed(15 downto 0);
   
   signal reverbLastLeft         : signed(15 downto 0);
   signal reverbLastRight        : signed(15 downto 0);
   
   -- noise
   signal noiseLevel             : unsigned(15 downto 0);
   signal noiseCnt               : unsigned(31 downto 0);
   signal noiseCheck             : unsigned(31 downto 0);

   -- cd processing
   signal cdProcStep             : integer range 0 to 4 := 4;
   signal cd_next_left           : signed(16 downto 0);
   signal cd_next_right          : signed(16 downto 0);

   -- end processing
   signal endProcStep            : integer range 0 to 4 := 4;
   
   signal soundmulresult14       : signed(25 downto 0);
   signal soundmulresult14_1     : signed(25 downto 0);
   signal soundmulresult15       : signed(24 downto 0);
   signal soundmul1              : signed(23 downto 0);
   signal soundmul2              : signed(15 downto 0);

   -- reproducible timing
   signal writeDMAReady          : std_logic;
   signal rep_done               : std_logic := '1';
   signal rep_counter            : integer range 0 to 4095;

   -- savestates
   type t_ssarray is array(0 to 63) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));
   signal ss_out : t_ssarray := (others => (others => '0'));
      
   signal ss_voice_loading : std_logic := '0';
      
   -- debug_out
   type outtype is record
      datatype  : integer range 0 to 255;
      addr      : unsigned(15 downto 0);
      data      : unsigned(15 downto 0);
   end record;
   type tdebugout_buf is array(0 to 1023) of outtype;
  
begin 

   ififoIn: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 128,
      DATAWIDTH        => 16,
      NEARFULLDISTANCE => 32
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoIn_reset,   
                
      Din      => FifoIn_Din,     
      Wr       => FifoIn_Wr,      
      Full     => FifoIn_Full,    
      NearFull => open,

      Dout     => FifoIn_Dout,    
      Rd       => FifoIn_Rd,      
      Empty    => FifoIn_Empty   
   );
   
   ififoOut: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 16,
      NEARFULLDISTANCE => 32
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoOut_reset,   
                
      Din      => FifoOut_Din,     
      Wr       => FifoOut_Wr,      
      Full     => open,    
      NearFull => FifoOut_NearFull,

      Dout     => FifoOut_Dout,    
      Rd       => FifoOut_Rd,      
      Empty    => FifoOut_Empty   
   );
   
   FifoOut_Rd   <= dma_read     when (FifoOut_Empty = '0') else '0';
   dma_readdata <= FifoOut_Dout when (FifoOut_Empty = '0') else (others => '0');
   
   writeDMAReady <= rep_done when (REPRODUCIBLESPUDMA = '1') else FifoIn_Empty;
   
   STAT(15) <= '0'; -- unused
   STAT(14) <= '0'; -- unused
   STAT(13) <= '0'; -- unused
   STAT(12) <= '0'; -- unused
   STAT(11) <= capturePosition(9); -- Writing to First/Second half of Capture Buffers (0=First, 1=Second)
   STAT(10) <= busy; -- Data Transfer Busy Flag
   STAT( 9) <= '1' when (CNT(5 downto 4) = "10" and writeDMAReady    = '1') else '0'; -- Data Transfer DMA Write Request   -- todo no$ has 9 as read, duckstation 9 as write?
   STAT( 8) <= '1' when (CNT(5 downto 4) = "11" and FifoOut_NearFull = '1') else '0'; -- Data Transfer DMA Read Request    -- todo no$ has 8 as write, duckstation 8 as read?
   STAT( 7) <= STAT(8) or STAT(9); -- Data Transfer DMA Read/Write Request ;seems to be same as SPUCNT.Bit5
   STAT( 6) <= IRQ9;
   STAT(5 downto 0) <= CNT(5 downto 0);

   spu_dmaRequest <= STAT(7);
   
   
   ispu_gauss : entity work.spu_gauss
   port map
   (
      clk1x          => clk1x,        
      interpolIndex  => voice.adpcmSamplePos(11 downto 4),
      gauss1         => gauss1,       
      gauss2         => gauss2,       
      gauss3         => gauss3,       
      gauss4         => gauss4       
   );
   
-- VOICEREGS  
 
   gVOICEREGS : for i in 0 to 1 generate
   begin
      itagramVOICEREGS : entity mem.RamMLAB
      GENERIC MAP 
      (
         width         => 16,
         widthad       => 8,
         width_byteena => 1
      )
      PORT MAP (
         inclock    => clk1x,
         wren       => RamVoice_write,
         data       => RamVoice_dataA,
         wraddress  => std_logic_vector(RamVoice_addrA),
         rdaddress  => std_logic_vector(RamVoice_addrB(i)),
         q          => RamVoice_dataB(i)
      );
   end generate;
   
   RamVoice_addrB(0) <= bus_addr(8 downto 1);
   
   RamVoice_addrB(1) <= (SS_Adr(7 downto 0) - 64)         when (SS_rden = '1')            else 
                        to_unsigned(((index * 8) + 4), 8) when (state = VOICE_START)      else -- read ADSR Attack / Decay / Sustain / Release
                        to_unsigned(((index * 8) + 5), 8) when (state = VOICE_READHEADER) else -- read ADSR Attack / Decay / Sustain / Release
                        to_unsigned(((index * 8) + 0), 8) when (state = VOICE_EVALHEADER) else -- read Volume Left  
                        to_unsigned(((index * 8) + 1), 8) when (state = VOICE_EVALSAMPLE) else -- read Volume Right
                        to_unsigned(((index * 8) + 6), 8) when (state = VOICE_PICKSAMPLE) else -- read ADSR Current Volume
                        to_unsigned(((index * 8) + 2), 8) when (state = VOICE_APPLYADSR)  else -- read ADPCM Sample Rate
                        to_unsigned(((index * 8) + 3), 8) when (state = VOICE_CHECKKEY)   else -- read ADPCM Start Address
                        to_unsigned(((index * 8) + 7), 8) when (state = VOICE_CHECKEND)   else -- read ADPCM Repeat Address
                        (others => '0');
                        
-- VOICEVOLUMES
 
   gVOICEVOLUMES : for i in 0 to 1 generate
   begin
      itagramVOICEVOLUMES : entity mem.RamMLAB
      GENERIC MAP 
      (
         width         => 16,
         widthad       => 6,
         width_byteena => 1
      )
      PORT MAP (
         inclock    => clk1x,
         wren       => RamVoiceVolumes_write,
         data       => RamVoiceVolumes_dataA,
         wraddress  => std_logic_vector(RamVoiceVolumes_addrA),
         rdaddress  => std_logic_vector(RamVoiceVolumes_addrB(i)),
         q          => RamVoiceVolumes_dataB(i)
      );
   end generate;
   
   RamVoiceVolumes_addrB(0) <= bus_addr(6 downto 1);
   
   RamVoiceVolumes_addrB(1) <= SS_Adr(5 downto 0)                when (SS_rden = '1')            else 
                               to_unsigned(((index * 2) + 0), 6) when (state = VOICE_START)      else -- left value
                               to_unsigned(((index * 2) + 1), 6);                                     -- right value
     
-- VOICERECORDS
 
   gVOICERECORDS : for i in 0 to 1 generate
   begin
      itagramVOICECORDS : entity mem.RamMLAB
      GENERIC MAP 
      (
         width         => 101,
         widthad       => 5,
         width_byteena => 1
      )
      PORT MAP (
         inclock    => clk1x,
         wren       => RamVoiceRecord_write,
         data       => RamVoiceRecord_dataA,
         wraddress  => std_logic_vector(RamVoiceRecord_addrA),
         rdaddress  => std_logic_vector(RamVoiceRecord_addrB(i)),
         q          => RamVoiceRecord_dataB(i)
      );
   end generate;
   
   RamVoiceRecord_addrB(0)  <= to_unsigned(index, 5);
   
   RamVoiceRecord_addrB(1)  <= SS_Adr(6 downto 2);
     
-- adpcmSamples
   gram_adpcmSamples: for i in 0 to 3 generate
   begin
      iram_adpcmSamples: entity mem.dpram
      generic map (addr_width => 8, data_width => 16)
      port map
      (
         clock_a     => clk1x,
         address_a   => std_logic_vector(adpcm_ram_address_a),
         data_a      => adpcm_ram_data_a(i),
         wren_a      => adpcm_ram_wren_a(i),
         
         clock_b     => clk1x,
         address_b   => std_logic_vector(adpcm_ram_address_b(i)),
         data_b      => x"0000",
         wren_b      => '0',
         q_b         => adpcm_ram_q_b(i)
      );
   end generate; 
   
-- envelopecounters  
 
   iEnvCounterRam : entity mem.RamMLAB
   GENERIC MAP 
   (
      width         => 25,
      widthad       => 6,
      width_byteena => 1
   )
   PORT MAP (
      inclock    => clk1x,
      wren       => EnvCounterRam_write,
      data       => EnvCounterRam_dataA,
      wraddress  => std_logic_vector(EnvCounterRam_addrA),
      rdaddress  => std_logic_vector(EnvCounterRam_addrB),
      q          => EnvCounterRam_dataB
   );
   
   EnvCounterRam_addrB <= (SS_Adr(5 downto 0)) when (SS_rden = '1') else to_unsigned(envelopeIndex, 6);
     
-- savestates
     
   ss_out(1)( 9 downto 0)   <= std_logic_vector(sampleticks);    
   ss_out(2)( 9 downto 0)   <= std_logic_vector(capturePosition);
   ss_out(3)(18 downto 0)   <= std_logic_vector(ramTransferAddr);   
   ss_out(4)(17 downto 0)   <= std_logic_vector(reverbCurrentAddress);
   ss_out(4)(31)            <= reverbRight;
   ss_out(5)(15 downto 0)   <= std_logic_vector(noiseLevel);
   ss_out(6)(31 downto 0)   <= std_logic_vector(noiseCnt);

   ss_out(32)               <= KEYON;          
   ss_out(33)               <= KEYOFF;         
   ss_out(34)               <= PITCHMODENA;    
   ss_out(35)               <= NOISEMODE;      
   ss_out(36)               <= REVERBON;       
   ss_out(37)               <= ENDX;           
      
   ss_out(38)(15 downto 0)  <= VOLUME_LEFT;    
   ss_out(38)(31 downto 16) <= VOLUME_RIGHT;   
   ss_out(39)(15 downto 0)  <= TRANSFERADDR;   
   ss_out(39)(31 downto 16) <= CNT;		      
   ss_out(40)(15 downto 0)  <= TRANSFER_CNT;   
   ss_out(40)(31 downto 16) <= STAT;   
   ss_out(41)(15 downto 0)  <= CDAUDIO_VOL_L;  
   ss_out(41)(31 downto 16) <= CDAUDIO_VOL_R;  
   ss_out(42)(15 downto 0)  <= EXT_VOL_L;	   
   ss_out(42)(31 downto 16) <= EXT_VOL_R;	   
   ss_out(43)(15 downto 0)  <= CURVOL_L;	      
   ss_out(43)(31 downto 16) <= CURVOL_R;	      
   ss_out(44)(15 downto 0)  <= IRQ_ADDR;	      
   ss_out(44)(31 downto 16) <= REVERB_vLOUT  ;	      
   ss_out(45)(15 downto 0)  <= REVERB_vROUT  ;	      
   ss_out(45)(31 downto 16) <= REVERB_mBASE  ;	      
   ss_out(46)(15 downto 0)  <= REVERB_dAPF1  ;	      
   ss_out(46)(31 downto 16) <= REVERB_dAPF2  ;	      
   ss_out(47)(15 downto 0)  <= REVERB_vIIR   ;	      
   ss_out(47)(31 downto 16) <= REVERB_vCOMB1 ;	      
   ss_out(48)(15 downto 0)  <= REVERB_vCOMB2 ;	      
   ss_out(48)(31 downto 16) <= REVERB_vCOMB3 ;	      
   ss_out(49)(15 downto 0)  <= REVERB_vCOMB4 ;	      
   ss_out(49)(31 downto 16) <= REVERB_vWALL  ;	      
   ss_out(50)(15 downto 0)  <= REVERB_vAPF1  ;	      
   ss_out(50)(31 downto 16) <= REVERB_vAPF2  ;	      
   ss_out(51)(15 downto 0)  <= REVERB_mLSAME ;	      
   ss_out(51)(31 downto 16) <= REVERB_mRSAME ;	      
   ss_out(52)(15 downto 0)  <= REVERB_mLCOMB1;	      
   ss_out(52)(31 downto 16) <= REVERB_mRCOMB1;	      
   ss_out(53)(15 downto 0)  <= REVERB_mLCOMB2;	      
   ss_out(53)(31 downto 16) <= REVERB_mRCOMB2;	      
   ss_out(54)(15 downto 0)  <= REVERB_dLSAME ;	      
   ss_out(54)(31 downto 16) <= REVERB_dRSAME ;	      
   ss_out(55)(15 downto 0)  <= REVERB_mLDIFF ;	      
   ss_out(55)(31 downto 16) <= REVERB_mRDIFF ;	      
   ss_out(56)(15 downto 0)  <= REVERB_mLCOMB3;	      
   ss_out(56)(31 downto 16) <= REVERB_mRCOMB3;	      
   ss_out(57)(15 downto 0)  <= REVERB_mLCOMB4;	      
   ss_out(57)(31 downto 16) <= REVERB_mRCOMB4;	      
   ss_out(58)(15 downto 0)  <= REVERB_dLDIFF ;	      
   ss_out(58)(31 downto 16) <= REVERB_dRDIFF ;	      
   ss_out(59)(15 downto 0)  <= REVERB_mLAPF1 ;	      
   ss_out(59)(31 downto 16) <= REVERB_mRAPF1 ;	      
   ss_out(60)(15 downto 0)  <= REVERB_mLAPF2 ;	      
   ss_out(60)(31 downto 16) <= REVERB_mRAPF2 ;	      
   ss_out(61)(15 downto 0)  <= REVERB_vLIN   ;	      
   ss_out(61)(31 downto 16) <= REVERB_vRIN   ;	          

-- cpu interface + processing
   process(clk1x)
      variable env_calcticks       : unsigned(23 downto 0);
      variable env_rate            : unsigned(6 downto 0);
      variable env_calcstep        : signed(16 downto 0);
      variable env_rateshift       : integer range 0 to 11;
      variable envVolumeSum        : signed(17 downto 0);
      variable adsr_rateshift      : integer range 0 to 11;
      variable adsr_index          : integer range 0 to 4;
      variable adsr_stepcalc       : signed(16 downto 0);
      variable adsr_volumeCalc     : signed(16 downto 0);
      variable adsrVolumeSum       : signed(17 downto 0);
      variable adpcm_decode_0      : signed(15 downto 0);
      variable adpcm_decode_1      : signed(17 downto 0);
      variable adpcm_decode_2      : signed(17 downto 0);
      variable adpcm_decode_sum    : signed(19 downto 0);
      variable adpcm_decode_result : signed(15 downto 0);
      variable adpcm_decode_target : integer range 0 to 3;
      variable interpol1           : signed(30 downto 0);
      variable interpol2           : signed(30 downto 0);
      variable interpol3           : signed(30 downto 0);
      variable interpol4           : signed(30 downto 0);
      variable soundmulresult      : signed(39 downto 0);
   begin
      if (rising_edge(clk1x)) then
            
         FifoIn_Wr               <= '0';
         FifoIn_Rd               <= '0';
         FifoIn_reset            <= '0';
         
         FifoOut_Wr              <= '0';
         FifoOut_reset           <= '0';
               
         RamVoice_write          <= '0';
         RamVoiceVolumes_write   <= '0';
         RamVoiceRecord_write    <= '0';
            
         adpcm_ram_wren_a        <= (others => '0');
               
         EnvCounterRam_write     <= '0';
               
         ram_request             <= '0';
         ram_isTransfer          <= '0';
         ram_isVoice             <= '0';
         ram_isReverb            <= '0';
            
         sound_timeout           <= '0';
         
         if (SS_reset = '1') then
            ss_voice_loading <= '1';
            RamVoice_write <= '1';
            RamVoice_dataA <= x"0000";
            RamVoice_addrA <= (others => '0');
         end if;
         
         if (ss_voice_loading = '1') then
            RamVoice_write <= '1';
            RamVoice_addrA <= RamVoice_addrA + 1;
            if (RamVoice_addrA = 191) then
               ss_voice_loading <= '0';
            end if;
            if (RamVoice_addrA < 48) then
               RamVoiceVolumes_write <= '1';
               RamVoiceVolumes_dataA <= (others => '0');
               RamVoiceVolumes_addrA <= RamVoice_addrA(5 downto 0);
            end if;
            if (RamVoice_addrA < 50) then
               EnvCounterRam_write <= '1';
               EnvCounterRam_addrA <= RamVoice_addrA(5 downto 0);
               EnvCounterRam_dataA <= (others => '0'); 
            end if;
            if (RamVoice_addrA < 24) then
               RamVoiceRecord_write <= '1';
               RamVoiceRecord_dataA <= (others => '0');
               RamVoiceRecord_addrA <= RamVoice_addrA(4 downto 0);
            end if;
            adpcm_ram_address_a    <= RamVoice_addrA;
            adpcm_ram_data_a       <= (others => (others => '0'));
            adpcm_ram_wren_a       <= "1111";
         end if;
      
         if (reset = '1') then
            
            state                <= IDLE;
            irqOut               <= '0';
            irqSaved             <= '0';
            stashedSamples       <= 0;
            
            FifoOut_Cnt          <= 0;
               
            sound_out_left       <= (others => '0');
            sound_out_right      <= (others => '0');
            
            reverbLastLeft       <= (others => '0');
            reverbLastRight      <= (others => '0');
            
            cd_next_left         <= (others => '0');
            cd_next_right        <= (others => '0');
               
            sampleticks          <= (others => '0'); --unsigned(ss_in(1)(9 downto 0));
            capturePosition      <= unsigned(ss_in(2)(9 downto 0));
            ramTransferAddr      <= unsigned(ss_in(3)(18 downto 0));
            reverbCurrentAddress <= unsigned(ss_in(4)(17 downto 0));
            reverbRight          <= ss_in(4)(31);
            noiseLevel           <= unsigned(ss_in(5)(15 downto 0));
            noiseCnt             <= unsigned(ss_in(6)(31 downto 0));
            
            IRQ9                 <= ss_in(40)(22);
               
            KEYON                <= ss_in(32);
            KEYOFF               <= ss_in(33);
            PITCHMODENA          <= ss_in(34);
            NOISEMODE            <= ss_in(35);
            REVERBON             <= ss_in(36);
            ENDX                 <= ss_in(37);
                  
            VOLUME_LEFT          <= ss_in(38)(15 downto 0);
            VOLUME_RIGHT         <= ss_in(38)(31 downto 16);
            TRANSFERADDR         <= ss_in(39)(15 downto 0);
            CNT		            <= ss_in(39)(31 downto 16);
            TRANSFER_CNT         <= ss_in(40)(15 downto 0);
            CDAUDIO_VOL_L        <= ss_in(41)(15 downto 0);
            CDAUDIO_VOL_R        <= ss_in(41)(31 downto 16);
            EXT_VOL_L	         <= ss_in(42)(15 downto 0);
            EXT_VOL_R	         <= ss_in(42)(31 downto 16);
            CURVOL_L	            <= ss_in(43)(15 downto 0);
            CURVOL_R	            <= ss_in(43)(31 downto 16);
            IRQ_ADDR             <= ss_in(44)(15 downto 0);
            REVERB_vLOUT         <= ss_in(44)(31 downto 16);
            REVERB_vROUT         <= ss_in(45)(15 downto 0);
            REVERB_mBASE         <= ss_in(45)(31 downto 16);
            REVERB_dAPF1         <= ss_in(46)(15 downto 0);
            REVERB_dAPF2         <= ss_in(46)(31 downto 16);
            REVERB_vIIR          <= ss_in(47)(15 downto 0);
            REVERB_vCOMB1        <= ss_in(47)(31 downto 16);
            REVERB_vCOMB2        <= ss_in(48)(15 downto 0);
            REVERB_vCOMB3        <= ss_in(48)(31 downto 16);
            REVERB_vCOMB4        <= ss_in(49)(15 downto 0);
            REVERB_vWALL         <= ss_in(49)(31 downto 16);
            REVERB_vAPF1         <= ss_in(50)(15 downto 0);
            REVERB_vAPF2         <= ss_in(50)(31 downto 16);
            REVERB_mLSAME        <= ss_in(51)(15 downto 0);
            REVERB_mRSAME        <= ss_in(51)(31 downto 16);
            REVERB_mLCOMB1       <= ss_in(52)(15 downto 0);
            REVERB_mRCOMB1       <= ss_in(52)(31 downto 16);
            REVERB_mLCOMB2       <= ss_in(53)(15 downto 0);
            REVERB_mRCOMB2       <= ss_in(53)(31 downto 16);
            REVERB_dLSAME        <= ss_in(54)(15 downto 0);
            REVERB_dRSAME        <= ss_in(54)(31 downto 16);
            REVERB_mLDIFF        <= ss_in(55)(15 downto 0);
            REVERB_mRDIFF        <= ss_in(55)(31 downto 16);
            REVERB_mLCOMB3       <= ss_in(56)(15 downto 0);
            REVERB_mRCOMB3       <= ss_in(56)(31 downto 16);
            REVERB_mLCOMB4       <= ss_in(57)(15 downto 0);
            REVERB_mRCOMB4       <= ss_in(57)(31 downto 16);
            REVERB_dLDIFF        <= ss_in(58)(15 downto 0);
            REVERB_dRDIFF        <= ss_in(58)(31 downto 16);
            REVERB_mLAPF1        <= ss_in(59)(15 downto 0);
            REVERB_mRAPF1        <= ss_in(59)(31 downto 16);
            REVERB_mLAPF2        <= ss_in(60)(15 downto 0);
            REVERB_mRAPF2        <= ss_in(60)(31 downto 16);
            REVERB_vLIN          <= ss_in(61)(15 downto 0);
            REVERB_vRIN          <= ss_in(61)(31 downto 16);
            
         elsif (SS_wren = '1') then
            
            if (SS_Adr >= 64 and SS_Adr < 256) then
               RamVoice_write <= '1';
               RamVoice_dataA <= SS_DataWrite(15 downto 0);
               RamVoice_addrA <= SS_Adr(7 downto 0) - 64;
            end if;
            
            if (SS_Adr >= 256 and SS_Adr < 304) then
               RamVoiceVolumes_write <= '1';
               RamVoiceVolumes_dataA <= SS_DataWrite(15 downto 0);
               RamVoiceVolumes_addrA <= SS_Adr(5 downto 0);
            end if;
            
            if (SS_Adr >= 320 and SS_Adr < 370) then
               EnvCounterRam_write <= '1';
               EnvCounterRam_addrA <= SS_Adr(5 downto 0);
               EnvCounterRam_dataA <= SS_DataWrite(24 downto 0);
            end if;
            
            if (SS_Adr >= 384 and SS_Adr < 480) then
               RamVoiceRecord_addrA <= SS_Adr(6 downto 2);
               case (SS_Adr(1 downto 0)) is
                  when "00" =>
                     RamVoiceRecord_dataA(15 downto  0) <= SS_DataWrite(15 downto  0); --voice.currentAddr
                  
                  when "01" =>
                     RamVoiceRecord_dataA(31 downto 16) <= SS_DataWrite(15 downto  0); -- voice.adpcmLast0
                     RamVoiceRecord_dataA(47 downto 32) <= SS_DataWrite(31 downto 16); -- voice.adpcmLast1
                  
                  when "10" =>
                     RamVoiceRecord_dataA(67 downto 48) <= SS_DataWrite(19 downto  0); -- voice.adpcmSamplePos
                     RamVoiceRecord_dataA(73 downto 68) <= SS_DataWrite(25 downto 20); -- voice.adpcmDecodePtr
                     RamVoiceRecord_dataA(76 downto 74) <= SS_DataWrite(28 downto 26); -- voice.adsrphase
                     
                  when "11" =>
                     RamVoiceRecord_dataA(100 downto 77) <= SS_DataWrite(23 downto 0); -- voice.adsrTicks
                     RamVoiceRecord_write <= '1';
                  
                  when others =>
               end case;
            end if;
            
         elsif (ce = '1') then
         
            irqOut <= '0';
            
            envelope_startnext <= '0';
            
            if (ram_request = '1' and cnt(15) = '1' and cnt(6) = '1' and (IRQ_ADDR = ram_Adr(18 downto 3)) and irq9 = '0') then
               if (REPRODUCIBLESPUIRQ = '1') then
                  irqSaved <= '1';
               else
                  IRQ9 <= '1';
                  irqOut <= '1';
               end if;
            end if;
         
            if (bus_write = '1') then
               
               if (bus_addr < 16#180#) then
                  RamVoice_write <= '1';
                  RamVoice_dataA <= bus_dataWrite;
                  RamVoice_addrA <= bus_addr(8 downto 1);

                  case (bus_addr(3 downto 0)) is
                     when x"8" | x"A" => voice_adsrWrite(to_integer(bus_addr(8 downto 4))) <= '1';
                     when others => null;
                  end case;
                  
               else
                  case (to_integer(bus_addr)) is
                     when 16#180# => VOLUME_LEFT               <= bus_dataWrite;
                     when 16#182# => VOLUME_RIGHT              <= bus_dataWrite;
                  
                     when 16#188# => KEYON(15 downto 0)        <= bus_dataWrite;
                     when 16#18A# => KEYON(31 downto 16)       <= bus_dataWrite;
                     when 16#18C# => KEYOFF(15 downto 0)       <= bus_dataWrite;
                     when 16#18E# => KEYOFF(31 downto 16)      <= bus_dataWrite;
                     when 16#190# => PITCHMODENA(15 downto 0)  <= bus_dataWrite;
                     when 16#192# => PITCHMODENA(31 downto 16) <= bus_dataWrite;
                     when 16#194# => NOISEMODE(15 downto 0)    <= bus_dataWrite;
                     when 16#196# => NOISEMODE(31 downto 16)   <= bus_dataWrite;
                     when 16#198# => REVERBON(15 downto 0)     <= bus_dataWrite;
                     when 16#19A# => REVERBON(31 downto 16)    <= bus_dataWrite;
                     
                     when 16#1A4# => IRQ_ADDR                  <= bus_dataWrite;
                                     
                     when 16#1A6# => 
                        TRANSFERADDR     <= bus_dataWrite;
                        ramTransferAddr  <= unsigned(bus_dataWrite) & "000";
                     
                     when 16#1A8# =>
                        if (FifoIn_Full = '0') then
                           FifoIn_Wr  <= '1';
                           FifoIn_Din <= bus_dataWrite;
                        end if;
                                                             
                     when 16#1AA# => 
                        if ((CNT(5 downto 4) /= bus_dataWrite(5 downto 4)) and bus_dataWrite(5 downto 4) = "00") then
                           if (CNT(5 downto 4) = "11") then -- read
                              FifoOut_reset <= '1';
                           else -- write
                              FifoIn_reset <= '1';
                           end if;
                        end if;

                        -- todo if enable turned off changed -> mute
                        CNT <= bus_dataWrite;
                        
                        if (bus_dataWrite(6) = '0') then
                           IRQ9 <= '0';
                        end if;
                        
                     when 16#1AC# => TRANSFER_CNT              <= bus_dataWrite;
                                     
                     when 16#1B0# => CDAUDIO_VOL_L             <= bus_dataWrite;
                     when 16#1B2# => CDAUDIO_VOL_R             <= bus_dataWrite;
                     when 16#1B4# => EXT_VOL_L                 <= bus_dataWrite;
                     when 16#1B6# => EXT_VOL_R                 <= bus_dataWrite;
                     
                     when 16#184# => REVERB_vLOUT              <= bus_dataWrite;
                     when 16#186# => REVERB_vROUT              <= bus_dataWrite;
                     when 16#1A2# => REVERB_mBASE              <= bus_dataWrite; reverbCurrentAddress <= unsigned(bus_dataWrite) & "00";
                     when 16#1C0# => REVERB_dAPF1              <= bus_dataWrite;
                     when 16#1C2# => REVERB_dAPF2              <= bus_dataWrite;
                     when 16#1C4# => REVERB_vIIR               <= bus_dataWrite;
                     when 16#1C6# => REVERB_vCOMB1             <= bus_dataWrite;
                     when 16#1C8# => REVERB_vCOMB2             <= bus_dataWrite;
                     when 16#1CA# => REVERB_vCOMB3             <= bus_dataWrite;
                     when 16#1CC# => REVERB_vCOMB4             <= bus_dataWrite;
                     when 16#1CE# => REVERB_vWALL              <= bus_dataWrite;
                     when 16#1D0# => REVERB_vAPF1              <= bus_dataWrite;
                     when 16#1D2# => REVERB_vAPF2              <= bus_dataWrite;
                     when 16#1D4# => REVERB_mLSAME             <= bus_dataWrite;
                     when 16#1D6# => REVERB_mRSAME             <= bus_dataWrite;
                     when 16#1D8# => REVERB_mLCOMB1            <= bus_dataWrite;
                     when 16#1DA# => REVERB_mRCOMB1            <= bus_dataWrite;
                     when 16#1DC# => REVERB_mLCOMB2            <= bus_dataWrite;
                     when 16#1DE# => REVERB_mRCOMB2            <= bus_dataWrite;
                     when 16#1E0# => REVERB_dLSAME             <= bus_dataWrite;
                     when 16#1E2# => REVERB_dRSAME             <= bus_dataWrite;
                     when 16#1E4# => REVERB_mLDIFF             <= bus_dataWrite;
                     when 16#1E6# => REVERB_mRDIFF             <= bus_dataWrite;
                     when 16#1E8# => REVERB_mLCOMB3            <= bus_dataWrite;
                     when 16#1EA# => REVERB_mRCOMB3            <= bus_dataWrite;
                     when 16#1EC# => REVERB_mLCOMB4            <= bus_dataWrite;
                     when 16#1EE# => REVERB_mRCOMB4            <= bus_dataWrite;
                     when 16#1F0# => REVERB_dLDIFF             <= bus_dataWrite;
                     when 16#1F2# => REVERB_dRDIFF             <= bus_dataWrite;
                     when 16#1F4# => REVERB_mLAPF1             <= bus_dataWrite;
                     when 16#1F6# => REVERB_mRAPF1             <= bus_dataWrite;
                     when 16#1F8# => REVERB_mLAPF2             <= bus_dataWrite;
                     when 16#1FA# => REVERB_mRAPF2             <= bus_dataWrite;
                     when 16#1FC# => REVERB_vLIN               <= bus_dataWrite;
                     when 16#1FE# => REVERB_vRIN               <= bus_dataWrite;
                     
                     when others => null;
                  end case;
               end if;
            
            end if; -- end bus write
         
            if (bus_read = '1') then
               bus_dataRead <= (others => '1');
               if (bus_addr < 16#180#) then
                  bus_dataRead <= RamVoice_dataB(0);   
               elsif (bus_addr >= 16#200# and bus_addr < 16#260#) then
                  bus_dataRead <= RamVoiceVolumes_dataB(0);
               else
                  case (to_integer(bus_addr)) is
                     when 16#180# => bus_dataRead <= VOLUME_LEFT;
                     when 16#182# => bus_dataRead <= VOLUME_RIGHT;
                  
                     when 16#188# => bus_dataRead <= KEYON(15 downto 0);
                     when 16#18A# => bus_dataRead <= KEYON(31 downto 16);
                     when 16#18C# => bus_dataRead <= KEYOFF(15 downto 0);
                     when 16#18E# => bus_dataRead <= KEYOFF(31 downto 16);
                     when 16#190# => bus_dataRead <= PITCHMODENA(15 downto 0);
                     when 16#192# => bus_dataRead <= PITCHMODENA(31 downto 16);
                     when 16#194# => bus_dataRead <= NOISEMODE(15 downto 0);
                     when 16#196# => bus_dataRead <= NOISEMODE(31 downto 16);
                     when 16#198# => bus_dataRead <= REVERBON(15 downto 0);
                     when 16#19A# => bus_dataRead <= REVERBON(31 downto 16);
                     when 16#19C# => bus_dataRead <= ENDX(15 downto 0);
                     when 16#19E# => bus_dataRead <= ENDX(31 downto 16);
                  
                     when 16#1A4# => bus_dataRead <= IRQ_ADDR;
                     
                     when 16#1A6# => bus_dataRead <= TRANSFERADDR;
                
                     when 16#1AA# => bus_dataRead <= CNT;
                     when 16#1AC# => bus_dataRead <= TRANSFER_CNT;
                     when 16#1AE# => bus_dataRead <= STAT;
                   
                     when 16#1B0# => bus_dataRead <= CDAUDIO_VOL_L;
                     when 16#1B2# => bus_dataRead <= CDAUDIO_VOL_R;
                     when 16#1B4# => bus_dataRead <= EXT_VOL_L;
                     when 16#1B6# => bus_dataRead <= EXT_VOL_R;
                     when 16#1B8# => bus_dataRead <= CURVOL_L;
                     when 16#1BA# => bus_dataRead <= CURVOL_R;
                     
                     when 16#184# => bus_dataRead <= REVERB_vLOUT;  
                     when 16#186# => bus_dataRead <= REVERB_vROUT;  
                     when 16#1A2# => bus_dataRead <= REVERB_mBASE;  
                     when 16#1C0# => bus_dataRead <= REVERB_dAPF1;  
                     when 16#1C2# => bus_dataRead <= REVERB_dAPF2;  
                     when 16#1C4# => bus_dataRead <= REVERB_vIIR;   
                     when 16#1C6# => bus_dataRead <= REVERB_vCOMB1; 
                     when 16#1C8# => bus_dataRead <= REVERB_vCOMB2; 
                     when 16#1CA# => bus_dataRead <= REVERB_vCOMB3; 
                     when 16#1CC# => bus_dataRead <= REVERB_vCOMB4; 
                     when 16#1CE# => bus_dataRead <= REVERB_vWALL;  
                     when 16#1D0# => bus_dataRead <= REVERB_vAPF1;  
                     when 16#1D2# => bus_dataRead <= REVERB_vAPF2;  
                     when 16#1D4# => bus_dataRead <= REVERB_mLSAME; 
                     when 16#1D6# => bus_dataRead <= REVERB_mRSAME; 
                     when 16#1D8# => bus_dataRead <= REVERB_mLCOMB1;
                     when 16#1DA# => bus_dataRead <= REVERB_mRCOMB1;
                     when 16#1DC# => bus_dataRead <= REVERB_mLCOMB2;
                     when 16#1DE# => bus_dataRead <= REVERB_mRCOMB2;
                     when 16#1E0# => bus_dataRead <= REVERB_dLSAME; 
                     when 16#1E2# => bus_dataRead <= REVERB_dRSAME; 
                     when 16#1E4# => bus_dataRead <= REVERB_mLDIFF; 
                     when 16#1E6# => bus_dataRead <= REVERB_mRDIFF; 
                     when 16#1E8# => bus_dataRead <= REVERB_mLCOMB3;
                     when 16#1EA# => bus_dataRead <= REVERB_mRCOMB3;
                     when 16#1EC# => bus_dataRead <= REVERB_mLCOMB4;
                     when 16#1EE# => bus_dataRead <= REVERB_mRCOMB4;
                     when 16#1F0# => bus_dataRead <= REVERB_dLDIFF; 
                     when 16#1F2# => bus_dataRead <= REVERB_dRDIFF; 
                     when 16#1F4# => bus_dataRead <= REVERB_mLAPF1; 
                     when 16#1F6# => bus_dataRead <= REVERB_mRAPF1; 
                     when 16#1F8# => bus_dataRead <= REVERB_mLAPF2; 
                     when 16#1FA# => bus_dataRead <= REVERB_mRAPF2; 
                     when 16#1FC# => bus_dataRead <= REVERB_vLIN;   
                     when 16#1FE# => bus_dataRead <= REVERB_vRIN;   
                        
                     when others => null;
                  end case;
               end if;
            end if;
            
            -- envelope
            env_calcticks := (to_unsigned(1, 24) sll to_integer(env_rate(6 downto 2)) - 11);
            env_rate      := unsigned(volumeSetting(6 downto 0));
            
            case (envelopeState) is
            
               when ENV_IDLE =>
                  null;
               
               when ENV_START =>
                  if (volumeSetting(15) = '0') then
                     envelopeState <= ENV_WRITE;
                     envVolume     <= signed(volumeSetting(14 downto 0) & '0');
                     envTicksNew   <= '1';
                  else
                     if (envelopeVoice = '1') then
                        if (envelopeRight = '1') then
                           envVolume <= envVolRight;
                        else
                           envVolume <= envVolLeft;
                        end if;
                     else
                        if (envelopeRight = '1') then
                           CURVOL_R <= std_logic_vector(envVolume);
                        else
                           CURVOL_L <= std_logic_vector(envVolume);
                        end if;
                     end if;
                     
                     envTicks        <= unsigned(EnvCounterRam_dataB(23 downto 0)); 
                     envTicksNew     <= EnvCounterRam_dataB(24);
                  
                     envelopeState <= ENV_CALC;
                     
                     if (EnvCounterRam_dataB(24) = '1') then
                        envTicks    <= env_calcticks;
                        envTicksNew <= '0';
                     end if;
                     
                     env_rateshift := 0;
                     if (env_rate(6 downto 2) <= 11) then
                        env_rateshift := (11 - to_integer(env_rate(6 downto 2)));
                     end if;
                     
                     if (env_rate < 48) then
                        if (volumeSetting(13) = '1') then 
                           env_step <=  shift_left(to_signed(-8, 16) + to_integer(env_rate(1 downto 0)), env_rateshift);
                        else 
                           env_step <=  shift_left(to_signed( 7, 16) - to_integer(env_rate(1 downto 0)), env_rateshift);
                        end if;
                     else
                        if (volumeSetting(13) = '1') then 
                           env_step <= (to_signed(-8, 16) + to_integer(env_rate(1 downto 0)));
                        else 
                           env_step <= (to_signed( 7, 16) - to_integer(env_rate(1 downto 0)));
                        end if;
                     end if;
                  end if;
                  
               when ENV_CALC =>
                  envelopeState <= ENV_WRITE;
                  if (envTicks < 2) then
                     env_calcstep := resize(env_step, 17);
                     envTicks     <= env_calcticks;
                     if (volumeSetting(14) = '1') then 
                        if (volumeSetting(13) = '1') then 
                           env_calcstep := resize(shift_right(env_calcstep * envVolume, 15), 17);
                        else
                           if (envVolume >= 16#6000#) then
                              if (env_rate < 40) then
                                 env_calcstep := shift_right(env_calcstep, 2);
                              elsif (env_rate >= 44) then
                                 envTicks <= "00" & env_calcticks(23 downto 2);
                              else
                                 env_calcstep := shift_right(env_calcstep, 1);
                                 envTicks     <= "0" & env_calcticks(23 downto 1);
                              end if;
                           end if;
                        
                        end if;
                     end if;
                     
                     envVolumeSum := resize(envVolume, 18) + resize(env_calcstep, 18);
                     
                     if (envVolumeSum < 0) then
                        envVolume <= (others => '0');
                     elsif (envVolumeSum > 16#7FFF#) then 
                        envVolume <= x"7FFF";
                     else 
                        envVolume <= resize(envVolumeSum, 16);
                     end if;
                  else
                     envTicks <= envTicks - 1;
                  end if;
                  
               when ENV_WRITE =>
                  if (envelopeVoice = '1') then
                     RamVoiceVolumes_write <= '1';
                     RamVoiceVolumes_dataA <= std_logic_vector(envVolume);
                     RamVoiceVolumes_addrA <= to_unsigned(envelopeIndex, 6);
                  else
                     if (envelopeRight = '1') then
                        CURVOL_R <= std_logic_vector(envVolume);
                     else
                        CURVOL_L <= std_logic_vector(envVolume);
                     end if;
                  end if;
                  
                  EnvCounterRam_write <= '1';
                  EnvCounterRam_addrA <= to_unsigned(envelopeIndex, 6);
                  EnvCounterRam_dataA <= envTicksNew & std_logic_vector(envTicks);
                     
                  if (envelopeIndex < 47) then
                     envelopeIndex  <= envelopeIndex + 1;
                  end if;
                  if (envelopeRight = '1') then
                     envelopeState   <= ENV_IDLE;
                  else
                     volumeSetting   <= volumeSettingR;
                     envelopeState   <= ENV_START;
                     envelopeRight   <= '1';
                  end if;
                  
            end case;
            
            -- adsr
            for i in 0 to 4 loop
               if (adsr_rate(i) >= 48) then
                  adsr_ticks(i) <= (to_unsigned(1, 24) sll to_integer(adsr_rate(i)(6 downto 2)) - 11);
               else 
                  adsr_ticks(i) <= to_unsigned(1, 24);
               end if;
               
               adsr_rateshift := 0;
               if (adsr_rate(i)(6 downto 2) <= 11) then
                  adsr_rateshift := (11 - to_integer(adsr_rate(i)(6 downto 2)));
               end if;
               
               if (adsr_rate(i) < 48) then
                  if (adsr_dec(i) = '1') then 
                     adsr_step(i) <= shift_left(to_signed(-8, 16) + to_integer(adsr_rate(i)(1 downto 0)), adsr_rateshift);
                  else 
                     adsr_step(i) <= shift_left(to_signed( 7, 16) - to_integer(adsr_rate(i)(1 downto 0)), adsr_rateshift);
                  end if;
               else
                  if (adsr_dec(i) = '1') then 
                     adsr_step(i) <= (to_signed(-8, 16) + to_integer(adsr_rate(i)(1 downto 0)));
                  else 
                     adsr_step(i) <= (to_signed( 7, 16) - to_integer(adsr_rate(i)(1 downto 0)));
                  end if;
               end if;
            end loop;
            
            adsr_target(ADSR_OFF    ) <= (others => '0');
            adsr_target(ADSR_ATTACK ) <= (others => '1');
            if (adsrSetting(3 downto 0) = "1111") then
               adsr_target(ADSR_DECAY) <= (others => '1');
            else
               adsr_target(ADSR_DECAY) <= (adsrSetting(3 downto 0) + 1) & "00000000000";
            end if;
            adsr_target(ADSR_SUSTAIN) <= (others => '0');
            adsr_target(ADSR_RELEASE) <= (others => '0');
            
            -- processing
            spu_tick <= '0';
            if (sampleticks < 767) then
               sampleticks <= sampleticks + 1;
            else
               sampleticks <= (others => '0');
               spu_tick    <= '1';
               if (irqSaved = '1') then
                  irqSaved <= '0';
                  IRQ9     <= '1';
                  irqOut   <= '1';
               end if;
            end if;
            
            noiseCheck <= shift_right(to_unsigned(16#8000#, 16), to_integer(unsigned(cnt(13 downto 10)))) & x"0000";
            
            if (sampleticks = 0 and state /= IDLE) then
               if (stashedSamples < 15) then
                  stashedSamples    <= stashedSamples + 1;
               else
                  sound_timeout <= '1';
               end if;
            end if;
            
            if (voiceCounter < 31) then
               voiceCounter <= voiceCounter + 1;
            end if;

            case (state) is
            
               when IDLE =>
                  if (sampleticks = 0 or stashedSamples > 0) then
                     state          <= VOICE_START;
                     index          <= 0;
                     envelopeIndex  <= 0;
                     envelopeVoice  <= '1';
                     
                     soundleft      <= (others => '0');
                     soundright     <= (others => '0');
                     reverbsumleft  <= (others => '0');
                     reverbsumright <= (others => '0');
                     
                     cdProcStep     <= 0;
                     if (cnt(0) = '1') then
                        soundleft      <= resize(cd_next_left, 24);
                        soundright     <= resize(cd_next_right,24);
                        if (cnt(2) = '1') then
                           reverbsumleft  <= resize(cd_next_left, 24);
                           reverbsumright <= resize(cd_next_right,24);
                        end if;
                     end if;
                     
                     if (stashedSamples > 0 and sampleticks /= 0) then
                        stashedSamples <= stashedSamples - 1;
                     end if;
                  end if;
               
               -- VOICE
               when VOICE_START =>
                  if (bus_write = '0') then
                     state         <= VOICE_READHEADER;
                     voiceCounter  <= 0;
                     
                     volLeft       <= signed(RamVoiceVolumes_dataB(1));
                     envVolLeft    <= signed(RamVoiceVolumes_dataB(1));
                     chanLeft      <= (others => '0');
                     chanRight     <= (others => '0');
                     adsrSetting(15 downto 0) <= unsigned(RamVoice_dataB(1));
                     
                     --voice         <= voiceArray(index);
                     voice.currentAddr    <= unsigned(RamVoiceRecord_dataB(0)( 15 downto   0));
                     voice.adpcmLast0     <=   signed(RamVoiceRecord_dataB(0)( 31 downto  16));
                     voice.adpcmLast1     <=   signed(RamVoiceRecord_dataB(0)( 47 downto  32));
                     voice.adpcmSamplePos <= unsigned(RamVoiceRecord_dataB(0)( 67 downto  48));
                     voice.adpcmDecodePtr <= unsigned(RamVoiceRecord_dataB(0)( 73 downto  68));
                     voice.adsrphase      <= unsigned(RamVoiceRecord_dataB(0)( 76 downto  74));
                     voice.adsrTicks      <= unsigned(RamVoiceRecord_dataB(0)(100 downto  77));
                        
                     reset_adsr <= '0';
                     if (voice_adsrWrite(index) = '1') then
                        voice_adsrWrite(index) <= '0'; 
                        reset_adsr             <= '1';
                     end if;
                  end if;
                     
               when VOICE_READHEADER =>
                  state           <= VOICE_EVALHEADER;
                  ram_request     <= '1';
                  ram_isVoice     <= '1';
                  ram_rnw         <= '1';
                  ram_Adr         <= std_logic_vector(voice.currentAddr) & "000";
                  sampleIndex     <= voice.adpcmSamplePos(17 downto 12);
                  volRight        <= signed(RamVoiceVolumes_dataB(1));
                  envVolRight     <= signed(RamVoiceVolumes_dataB(1));
   
                  adsrSetting(31 downto 16) <= unsigned(RamVoice_dataB(1));
                  
                  if (voice.adpcmSamplePos(13 downto 12) > 0) then adpcm_ram_address_b(0) <= to_unsigned(index, 5) & (voice.adpcmSamplePos(16 downto 14) + 1); 
                  else                                             adpcm_ram_address_b(0) <= to_unsigned(index, 5) & voice.adpcmSamplePos(16 downto 14); end if;
                  
                  if (voice.adpcmSamplePos(13 downto 12) > 1) then adpcm_ram_address_b(1) <= to_unsigned(index, 5) & (voice.adpcmSamplePos(16 downto 14) + 1); 
                  else                                             adpcm_ram_address_b(1) <= to_unsigned(index, 5) & voice.adpcmSamplePos(16 downto 14); end if;
                  
                  if (voice.adpcmSamplePos(13 downto 12) > 2) then adpcm_ram_address_b(2) <= to_unsigned(index, 5) & (voice.adpcmSamplePos(16 downto 14) + 1); 
                  else                                             adpcm_ram_address_b(2) <= to_unsigned(index, 5) & voice.adpcmSamplePos(16 downto 14); end if;
                  
                  adpcm_ram_address_b(3) <= to_unsigned(index, 5) & voice.adpcmSamplePos(16 downto 14);
                  
               when VOICE_EVALHEADER =>
                  if (ram_done = '1') then
                     if (unsigned(ram_dataRead(3 downto 0)) > 12) then
                        adpcmShift <= to_unsigned(9, 4);
                     else
                        adpcmShift <= unsigned(ram_dataRead(3 downto 0));
                     end if;
                     if (unsigned(ram_dataRead(6 downto 4)) > 4) then
                        adpcmFilter <= to_unsigned(4, 3);
                     else
                        adpcmFilter <= unsigned(ram_dataRead(6 downto 4));
                     end if;
                     loopEnd      <= ram_dataRead(8);
                     loopRepeat   <= ram_dataRead(9);
                     updateRepeat <= '0';
                     if (ram_dataRead(10) = '1' and voice.adpcmDecodePtr = 0) then -- write ADPCM Repeat Address
                        updateRepeat <= '1';
                     end if;
                     volumeSetting      <= unsigned(RamVoice_dataB(1));
                     envelope_startnext <= '1';
                     envelopeRight      <= '0';
                     envelopeState      <= ENV_START; 
                     
                     state           <= VOICE_EVALSAMPLE;
                     ram_request     <= '1';
                     ram_isVoice     <= '1';
                     ram_rnw         <= '1';
                     ram_Adr         <= std_logic_vector((voice.currentAddr & "000" ) + (voice.adpcmDecodePtr(5 downto 2) & '0') + 2);
                     
                     case (to_integer(sampleIndex(1 downto 0))) is
                        when 0 => adpcmSamples(0) <= signed(adpcm_ram_q_b(0)); adpcmSamples(1) <= signed(adpcm_ram_q_b(1)); adpcmSamples(2) <= signed(adpcm_ram_q_b(2)); adpcmSamples(3) <= signed(adpcm_ram_q_b(3));
                        when 1 => adpcmSamples(0) <= signed(adpcm_ram_q_b(1)); adpcmSamples(1) <= signed(adpcm_ram_q_b(2)); adpcmSamples(2) <= signed(adpcm_ram_q_b(3)); adpcmSamples(3) <= signed(adpcm_ram_q_b(0));
                        when 2 => adpcmSamples(0) <= signed(adpcm_ram_q_b(2)); adpcmSamples(1) <= signed(adpcm_ram_q_b(3)); adpcmSamples(2) <= signed(adpcm_ram_q_b(0)); adpcmSamples(3) <= signed(adpcm_ram_q_b(1));
                        when 3 => adpcmSamples(0) <= signed(adpcm_ram_q_b(3)); adpcmSamples(1) <= signed(adpcm_ram_q_b(0)); adpcmSamples(2) <= signed(adpcm_ram_q_b(1)); adpcmSamples(3) <= signed(adpcm_ram_q_b(2));
                        when others => null;
                     end case;
                  
                  end if;
                  
               when VOICE_EVALSAMPLE =>
                  if (ram_done = '1') then
                     if (voice.adpcmDecodePtr <= sampleIndex) then
                        state  <= VOICE_DECODESAMPLE;
                     else
                        state  <= VOICE_PICKSAMPLE;
                     end if;
                     adpcmData <= ram_dataRead;
                     decodeCnt <= 0;
                     filterPos <= filtertablePos(to_integer(adpcmFilter));
                     filterNeg <= filtertableNeg(to_integer(adpcmFilter));
                  end if;
                  
                  if (envelope_startnext = '1') then
                     volumeSettingR     <= unsigned(RamVoice_dataB(1));
                  end if;
                  
                  if (reset_adsr = '1') then
                     case (voice.adsrphase) is
                        when ADSRPHASE_OFF     => voice.adsrTicks <= adsr_ticks(ADSR_OFF);
                        when ADSRPHASE_ATTACK  => voice.adsrTicks <= adsr_ticks(ADSR_ATTACK);
                        when ADSRPHASE_DECAY   => voice.adsrTicks <= adsr_ticks(ADSR_DECAY);
                        when ADSRPHASE_SUSTAIN => voice.adsrTicks <= adsr_ticks(ADSR_SUSTAIN);
                        when ADSRPHASE_RELEASE => voice.adsrTicks <= adsr_ticks(ADSR_RELEASE);
                        when others => null;
                     end case;
                  end if;
               
               when VOICE_DECODESAMPLE =>
                  if (decodeCnt < 3) then
                     decodeCnt <= decodeCnt + 1;
                  else
                     state <= VOICE_PICKSAMPLE;
                  end if;
                  
                  case (decodeCnt) is
                     when 0      => adpcm_decode_0 := shift_right(signed(adpcmData( 3 downto  0)) & x"000", to_integer(adpcmShift));
                     when 1      => adpcm_decode_0 := shift_right(signed(adpcmData( 7 downto  4)) & x"000", to_integer(adpcmShift));
                     when 2      => adpcm_decode_0 := shift_right(signed(adpcmData(11 downto  8)) & x"000", to_integer(adpcmShift));
                     when others => adpcm_decode_0 := shift_right(signed(adpcmData(15 downto 12)) & x"000", to_integer(adpcmShift));
                  end case;
                  
                  adpcm_decode_1 := resize(shift_right(voice.adpcmLast0 * filterPos, 6), 18);
                  adpcm_decode_2 := resize(shift_right(voice.adpcmLast1 * filterNeg, 6), 18);
                  
                  adpcm_decode_sum := resize(adpcm_decode_0, 20) + resize(adpcm_decode_1, 20) + resize(adpcm_decode_2, 20);
                  if (adpcm_decode_sum < -32768) then adpcm_decode_result := x"8000";
                  elsif (adpcm_decode_sum > 32767) then adpcm_decode_result := x"7FFF";
                  else adpcm_decode_result := adpcm_decode_sum(15 downto 0);
                  end if;
                  
                  voice.adpcmLast1 <= voice.adpcmLast0;
                  voice.adpcmLast0 <= adpcm_decode_result;
                  
                  --adpcmSamples(index, to_integer(voice.adpcmDecodePtr) + 3) <= adpcm_decode_result;
                  if (decodeCnt = 0) then
                     adpcm_ram_address_a                     <= to_unsigned(index, 5) & (voice.adpcmDecodePtr(4 downto 2));
                  else
                     adpcm_ram_address_a                     <= to_unsigned(index, 5) & ((voice.adpcmDecodePtr(4 downto 2)) + 1);
                  end if;
                  adpcm_ram_data_a((decodeCnt + 3) mod 4) <= std_logic_vector(adpcm_decode_result);
                  adpcm_ram_wren_a((decodeCnt + 3) mod 4) <= '1';
                  
                  if ((sampleIndex(1 downto 0) = 0 and decodeCnt < 1) or (sampleIndex(1 downto 0) = 1 and decodeCnt < 2) or (sampleIndex(1 downto 0) = 2 and decodeCnt < 3) or (sampleIndex(1 downto 0) = 3)) then
                     adpcm_decode_target := (decodeCnt + (3 - to_integer(sampleIndex(1 downto 0))));
                     adpcmSamples(adpcm_decode_target) <= adpcm_decode_result;
                  end if;
                  
                  voice.adpcmDecodePtr <= voice.adpcmDecodePtr + 1;
               
               when VOICE_PICKSAMPLE =>
                  state      <= VOICE_APPLYADSR;
                  adsrVolume <= signed(RamVoice_dataB(1));
                  
                  --interpol1  := resize(gauss(255 - to_integer(interpolIndex)) * adpcmSamples(index, to_integer(sampleIndex) + 0), 31); 
                  --interpol2  := resize(gauss(511 - to_integer(interpolIndex)) * adpcmSamples(index, to_integer(sampleIndex) + 1), 31); 
                  --interpol3  := resize(gauss(256 + to_integer(interpolIndex)) * adpcmSamples(index, to_integer(sampleIndex) + 2), 31); 
                  --interpol4  := resize(gauss(  0 + to_integer(interpolIndex)) * adpcmSamples(index, to_integer(sampleIndex) + 3), 31); 
                  interpol1  := resize(gauss1 * adpcmSamples(0), 31); 
                  interpol2  := resize(gauss2 * adpcmSamples(1), 31); 
                  interpol3  := resize(gauss3 * adpcmSamples(2), 31); 
                  interpol4  := resize(gauss4 * adpcmSamples(3), 31); 
                  
                  sample     <= resize(shift_right(interpol1 + interpol2 + interpol3 + interpol4, 15), 16);
                  --sample     <= adpcmSamples(index, to_integer(sampleIndex) + 3);
                  
                  if (NOISEMODE(index) = '1') then
                     sample <= signed(noiseLevel);
                  end if;
               
               when VOICE_APPLYADSR =>
                  state                <= VOICE_APPLYVOLUME;
                  adsr_volumeCalc      := resize(shift_right(sample * adsrVolume, 15), 17);
                  volume               <= adsr_volumeCalc;
                  if (adsr_volumeCalc < -32768) then voice_lastVolume <= x"8000";
                  elsif (adsr_volumeCalc > 32767) then voice_lastVolume <= x"7FFF";
                  else voice_lastVolume <= adsr_volumeCalc(15 downto 0);
                  end if;
                  
                  step       <= unsigned(RamVoice_dataB(1));
                  if (index > 0 and PITCHMODENA(index) = '1') then
                     step <= resize(shift_right(unsigned(RamVoice_dataB(1)) * unsigned(voice_lastVolume + x"8000"), 15), 16);
                  end if;
                  
                  for i in 0 to 3 loop
                     adpcm_ram_address_b(i) <= to_unsigned(index, 5) & "111" ; -- prepare read of last samples for copy back
                  end loop;
                  
                  -- adsr new volume
                  adsrVolumeNew <= adsrVolume;
                  if (voice.adsrphase /= ADSRPHASE_OFF) then
                     if (voice.adsrTicks < 2) then
                        
                        voice.adsrTicks <= adsr_ticks(to_integer(voice.adsrphase));
                        
                        adsr_index    := to_integer(voice.adsrphase);
                        adsr_stepcalc := resize(adsr_step(adsr_index), 17);
                        if (adsr_exp(adsr_index) = '1') then
                           if (adsr_dec(adsr_index) = '1') then
                              adsr_stepcalc := resize(shift_right(adsr_stepcalc * adsrVolume, 15), 17);
                           else
                              if (adsrVolume >= 16#6000#) then
                                 if (adsr_rate(adsr_index) < 40) then
                                    adsr_stepcalc := shift_right(adsr_stepcalc, 2);
                                 elsif (adsr_rate(adsr_index) >= 44) then
                                    voice.adsrTicks <= "00" & adsr_ticks(to_integer(voice.adsrphase))(23 downto 2);
                                 else
                                    adsr_stepcalc   := shift_right(adsr_stepcalc, 1);
                                    voice.adsrTicks <= "0" & adsr_ticks(to_integer(voice.adsrphase))(23 downto 1);
                                 end if;
                              end if;
                           end if;
                        end if;
                        
                        adsrVolumeSum := resize(adsrVolume, 18) + resize(adsr_stepcalc, 18);
                        
                        if (adsrVolumeSum < 0) then
                           adsrVolumeNew <= (others => '0');
                        elsif (adsrVolumeSum > 16#7FFF#) then 
                           adsrVolumeNew <= x"7FFF";
                        else 
                           adsrVolumeNew <= resize(adsrVolumeSum, 16);
                        end if;
                        
                     else
                        voice.adsrTicks <= voice.adsrTicks - 1;
                     end if;
                  end if;
                  
               when VOICE_APPLYVOLUME =>
                  if (bus_write = '0') then
                     state      <= VOICE_CHECKEND;
                     
                     chanLeft  <= resize(shift_right(volume *  volLeft, 15), 18);
                     chanRight <= resize(shift_right(volume * volRight, 15), 18);
                     
                     if (step < 16#3FFF#) then
                        voice.adpcmSamplePos <= voice.adpcmSamplePos + step;
                     else
                        voice.adpcmSamplePos <= voice.adpcmSamplePos + 16#3FFF#;
                     end if;
                     
                     -- adsr phase switch
                     if (voice.adsrphase /= ADSRPHASE_OFF and voice.adsrphase /= ADSRPHASE_SUSTAIN) then
                        adsr_index    := to_integer(voice.adsrphase);
                        if ((adsr_dec(adsr_index) = '1' and to_integer(adsrVolumeNew) <= to_integer(adsr_target(adsr_index))) or (adsr_dec(adsr_index) = '0' and to_integer(adsrVolumeNew) >= to_integer(adsr_target(adsr_index)))) then
                           case (voice.adsrphase) is
                              when ADSRPHASE_ATTACK  => voice.adsrphase <= ADSRPHASE_DECAY;   voice.adsrTicks <= adsr_ticks(ADSR_DECAY);
                              when ADSRPHASE_DECAY   => voice.adsrphase <= ADSRPHASE_SUSTAIN; voice.adsrTicks <= adsr_ticks(ADSR_SUSTAIN);
                              when ADSRPHASE_RELEASE => voice.adsrphase <= ADSRPHASE_OFF;     voice.adsrTicks <= adsr_ticks(ADSR_OFF);
                              when others => null;
                           end case;
                        end if;
                     end if;
                     
                     -- writeback repeat address
                     if (updateRepeat = '1') then
                        RamVoice_write <= '1';
                        RamVoice_dataA <= std_logic_vector(voice.currentAddr);
                        RamVoice_addrA <= to_unsigned((index * 8) + 7, 8); 
                     end if;
                     
                  end if;
                  
               when VOICE_CHECKEND =>
                  if (bus_write = '0') then
                     state            <= VOICE_CHECKKEY;
                     
                     -- writeback current ADSR volume
                     RamVoice_write <= '1';
                     RamVoice_dataA <= std_logic_vector(adsrVolumeNew);
                     RamVoice_addrA <= to_unsigned((index * 8) + 6, 8); 
                     
                     if (voice.adpcmSamplePos(19 downto 12) >= 28) then
                        voice.adpcmSamplePos  <= voice.adpcmSamplePos - 114688; -- (28 << 12)
                        voice.AdpcmDecodePtr  <= (others => '0');
                        --adpcmSamples(index,0) <= adpcmSamples(index,28);
                        --adpcmSamples(index,1) <= adpcmSamples(index,29);
                        --adpcmSamples(index,2) <= adpcmSamples(index,30);
                        adpcm_ram_address_a    <= to_unsigned(index, 5) & "000";
                        adpcm_ram_data_a       <= adpcm_ram_q_b;
                        adpcm_ram_wren_a       <= "0111";
                        if (loopEnd = '1') then
                           ENDX(index)           <= '1';
                           voice.currentAddr     <= unsigned(RamVoice_dataB(1));
                           if (loopRepeat = '0') then
                              voice.adsrphase <= ADSRPHASE_OFF;
                              RamVoice_dataA  <= (others => '0');
                           end if;
                        else
                           voice.currentAddr <= voice.currentAddr + 2;
                        end if;
                     end if;
                     
                     -- spu off
                     --if (cnt(15) = '0') then
                     --   RamVoice_dataA  <= (others => '0');
                     --end if;
                     
                  end if;
                  
               when VOICE_CHECKKEY =>
                  state <= VOICE_END;
               
                  if (KEYON(index) = '1') then
                     KEYON(index)           <= '0';
                     ENDX(index)            <= '0';
                     voice_adsrWrite(index) <= '0'; 
                     voice.adpcmDecodePtr   <= (others => '0');
                     voice.currentAddr      <= unsigned(RamVoice_dataB(1));
                     voice.adsrphase        <= ADSRPHASE_ATTACK;
                     voice.adpcmSamplePos   <= (others => '0');
                     voice.adpcmLast0       <= (others => '0');
                     voice.adpcmLast1       <= (others => '0');
                     voice.adsrTicks        <= adsr_ticks(ADSR_ATTACK);
                     --adpcmSamples(index,0)  <= (others => '0');
                     --adpcmSamples(index,1)  <= (others => '0');
                     --adpcmSamples(index,2)  <= (others => '0');
                     adpcm_ram_address_a    <= to_unsigned(index, 5) & "000";
                     adpcm_ram_data_a       <= (others => (others => '0'));
                     adpcm_ram_wren_a       <= "0111";
                  end if;   
                  
                  if (KEYOFF(index) = '1') then
                     KEYOFF(index) <= '0';
                     if (voice.adsrphase /= ADSRPHASE_OFF and voice.adsrphase /= ADSR_RELEASE) then
                        voice.adsrphase <= ADSRPHASE_RELEASE;
                        voice.adsrTicks <= adsr_ticks(ADSR_RELEASE);
                     end if;
                  end if;   
                  
                  -- spu off
                  --if (cnt(15) = '0') then
                  --   voice.adsrphase <= ADSRPHASE_OFF;
                  --end if;
                  
               when VOICE_END =>
                  soundleft  <= soundleft  + resize(chanLeft , 24);
                  soundright <= soundright + resize(chanRight, 24);
                  if (REVERBON(index) = '1') then
                     reverbsumleft  <= reverbsumleft  + resize(chanLeft , 24);
                     reverbsumright <= reverbsumright + resize(chanRight, 24);
                  end if;
                  
                  if (index = 1) then voice_lastVolume1 <= voice_lastVolume; end if;
                  if (index = 3) then voice_lastVolume3 <= voice_lastVolume; end if;
                  
                  if (CNT(5 downto 4) = "11" and FifoOut_NearFull = '0') then
                     state           <= RAM_READ;
                     ram_request     <= '1';
                     ram_isTransfer  <= '1';
                     ram_rnw         <= '1';
                     ram_Adr         <= std_logic_vector(ramTransferAddr);
                     ramTransferAddr <= ramTransferAddr + 2;
                  elsif ((CNT(5 downto 4) = "01" or CNT(5 downto 4) = "10") and FifoIn_Empty = '0') then
                     state           <= RAM_WRITE;
                     ram_request     <= '1';
                     ram_isTransfer  <= '1';
                     ram_rnw         <= '0';
                     ram_Adr         <= std_logic_vector(ramTransferAddr);
                     ram_dataWrite   <= FifoIn_Dout;
                     FifoIn_Rd       <= '1';
                     ramTransferAddr <= ramTransferAddr + 2;
                  else
                     state <= RAM_WAIT;
                  end if;
                  
                  --voiceArray(index) <= voice;
                  RamVoiceRecord_write <= '1';
                  RamVoiceRecord_addrA <= to_unsigned(index, 5);
                  RamVoiceRecord_dataA( 15 downto   0) <= std_logic_vector(voice.currentAddr);
                  RamVoiceRecord_dataA( 31 downto  16) <= std_logic_vector(voice.adpcmLast0);
                  RamVoiceRecord_dataA( 47 downto  32) <= std_logic_vector(voice.adpcmLast1);
                  RamVoiceRecord_dataA( 67 downto  48) <= std_logic_vector(voice.adpcmSamplePos);
                  RamVoiceRecord_dataA( 73 downto  68) <= std_logic_vector(voice.adpcmDecodePtr);
                  RamVoiceRecord_dataA( 76 downto  74) <= std_logic_vector(voice.adsrphase);
                  RamVoiceRecord_dataA(100 downto  77) <= std_logic_vector(voice.adsrTicks);

               -- DATA TRANSFER   
               when RAM_READ =>
                  if (ram_done = '1') then
                     state       <= RAM_WAIT;
                     FifoOut_Din <= ram_dataRead;
                     FifoOut_Wr  <= '1';
                     FifoOut_Cnt <= FifoOut_Cnt + 1;
                  end if;
               
               when RAM_WRITE =>
                  if (ram_done = '1') then
                     state <= RAM_WAIT;
                  end if;
                  
               when RAM_WAIT =>
                  if (index = 23 and cnt(14) = '0') then
                     soundleft  <= (others => '0');
                     soundright <= (others => '0');
                  end if;
               
                  if (voiceCounter >= 23 or useSDRAM = '0') then
                     if (index = 23) then
                        if (cnt(7) = '1' and REVERBOFF = '0') then
                           ram_ReverbIndex <= 0;
                           state           <= REVERB_READ1;
                        else
                           ram_ReverbIndex <= 6;
                           state           <= REVERB_READ2;
                        end if;
                        reverb_count <= 0;
                     else
                        state <= VOICE_START;
                        index <= index + 1;
                     end if;
                  end if;

               -- REVERB
               when REVERB_READ1 =>
                  if (reverb_count = 0 or ram_done = '1') then
                     reverb_count <= reverb_count + 1;
                     if (reverb_count < 4) then
                        ram_request    <= '1';
                        ram_isReverb   <= '1';
                        ram_rnw        <= '1';
                        ram_Adr        <= std_logic_vector(reverb_calcAddr);
                     end if;
                     case (reverb_count) is
                        when 1 => reverbReadval1 <= signed(ram_dataRead); 
                        when 2 => reverbReadval2 <= signed(ram_dataRead);
                        when 3 => reverbReadval3 <= signed(ram_dataRead);
                        when 4 => reverbReadval4 <= signed(ram_dataRead); state <= REVERB_PROCOUT; reverb_count <= 0;
                        when others => null;                     
                     end case;
                  end if;
                  if (ram_done = '1') then
                     ram_ReverbIndex <= ram_ReverbIndex + 1;
                  end if;
               
               when REVERB_PROCOUT =>
                  reverb_count <= reverb_count + 1;
                  case (reverb_count) is
                     when 0 => 
                        -- wallmult = (value1 * PSXRegs.SPU_REVERB_vWALL) >> 14;
                        soundmul1 <= resize(reverbReadval1, 24); 
                        soundmul2 <= signed(REVERB_vWALL);  
                        
                     when 1 =>
                        -- volmult = (sample * REVERB_vIN) >> 14;
                        soundmul1 <= reverb_sample;              
                        soundmul2 <= signed(REVERB_vIN);  
                        
                     when 2 => 
                        -- wallmult = (value2 * PSXRegs.SPU_REVERB_vWALL) >> 14;     
                        soundmul1 <= resize(reverbReadval2, 24); 
                        soundmul2 <= signed(REVERB_vWALL);                     
                        
                     when 3 =>
                        --IIR_INPUT_A = clamp16((wallmult + volmult) >> 1);
                        -- IIRmultNew = (IIR_INPUT_A * PSXRegs.SPU_REVERB_vIIR) >> 14;                     
                        soundmul1 <= resize(clamp16(shift_right(soundmulresult14 + soundmulresult14_1, 1)), 24);
                        soundmul2 <= signed(REVERB_vIIR);
                     
                     when 4 =>
                        --IIR_INPUT_B = clamp16((wallmult + volmult) >> 1);
                        IIR_INPUT_B <= clamp16(shift_right(soundmulresult14 + soundmulresult14_1, 1));
                        --IIRMultOld = IIASM(PSXRegs.SPU_REVERB_vIIR, value3) >> 14;
                        soundmul2 <= reverbReadval3;
                        if (signed(REVERB_vIIR) = -32768) then
                           if (reverbReadval3 = -32768) then
                              soundmul1 <= (others => '0');
                           else
                              soundmul1 <= to_signed(-65536, 24);
                           end if;
                        else
                           soundmul1 <= to_signed(32768, 24) - resize(signed(REVERB_vIIR), 24);
                        end if;
                        
                     when 5 =>
                        -- IIRmultNew = (IIR_INPUT_B * PSXRegs.SPU_REVERB_vIIR) >> 14;#
                        soundmul1 <= resize(IIR_INPUT_B, 24);
                        soundmul2 <= signed(REVERB_vIIR);
                        
                     when 6 =>
                        -- IIR_A = clamp16((IIRmultNew + IIRMultOld) >> 1);
                        IIR_A <= clamp16(shift_right(soundmulresult14 + soundmulresult14_1, 1));
                        -- IIRMultOld = IIASM(PSXRegs.SPU_REVERB_vIIR, value4) >> 14;
                        soundmul2 <= reverbReadval4;
                        if (signed(REVERB_vIIR) = -32768) then
                           if (reverbReadval4 = -32768) then
                              soundmul1 <= (others => '0');
                           else
                              soundmul1 <= to_signed(-65536, 24);
                           end if;
                        else
                           soundmul1 <= to_signed(32768, 24) - resize(signed(REVERB_vIIR), 24);
                        end if;
                        
                     when 7 => null;
                     
                     when 8 => 
                        -- IIR_B = clamp16((IIRmultNew + IIRMultOld) >> 1);
                        IIR_B <= clamp16(shift_right(soundmulresult14 + soundmulresult14_1, 1));
                     
                        state <= REVERB_WRITE1; 
                        reverb_count <= 0;
                     when others => null;                     
                  end case;
               
               when REVERB_WRITE1 =>
                  if (reverb_count = 0 or ram_done = '1') then
                     reverb_count <= reverb_count + 1;
                     if (reverb_count < 2) then
                        ram_request    <= '1';
                        ram_isReverb   <= '1';
                        ram_rnw        <= '0';
                        ram_Adr        <= std_logic_vector(reverb_calcAddr);
                     end if;
                     case (reverb_count) is
                        when 0 => ram_dataWrite <= std_logic_vector(IIR_A); 
                        when 1 => ram_dataWrite <= std_logic_vector(IIR_B); 
                        when 2 => state <= REVERB_READ2; reverb_count <= 0; ram_ReverbIndex <= 4;
                        when others => null;                     
                     end case;
                  end if;
               
               when REVERB_READ2 =>
                  if (reverb_count = 0 or ram_done = '1') then
                     reverb_count <= reverb_count + 1;
                     if (reverb_count < 6) then
                        ram_request    <= '1';
                        ram_isReverb   <= '1';
                        ram_rnw        <= '1';
                        ram_Adr        <= std_logic_vector(reverb_calcAddr);
                     end if;
                     case (reverb_count) is
                        when 1 => reverbReadval1 <= signed(ram_dataRead); 
                        when 2 => reverbReadval2 <= signed(ram_dataRead);
                        when 3 => reverbReadval3 <= signed(ram_dataRead);
                        when 4 => reverbReadval4 <= signed(ram_dataRead);
                        when 5 => reverbReadval5 <= signed(ram_dataRead);
                        when 6 => reverbReadval6 <= signed(ram_dataRead); state <= REVERB_PROCIN; reverb_count <= 0;
                        when others => null;                     
                     end case;
                  end if;
                  
                  if (ram_done = '1' and ram_ReverbIndex < 9) then
                     ram_ReverbIndex <= ram_ReverbIndex + 1;
                  end if;
                               
                  -- start envelope calculation
                  if (reverb_count = 0) then 
                     envelopeVoice  <= '0';
                     volumeSetting  <= unsigned(VOLUME_LEFT);
                     volumeSettingR <= unsigned(VOLUME_RIGHT);
                     envelopeRight  <= '0';
                     envelopeState  <= ENV_START; 
                  end if;
               
               when REVERB_PROCIN =>
                  reverb_count <= reverb_count + 1;
                  case (reverb_count) is
                     when 0 => 
                        -- acc_mul1 = (valueOut1 * PSXRegs.SPU_REVERB_vCOMB1) >> 14;
                        soundmul1 <= resize(reverbReadval1, 24); 
                        soundmul2 <= signed(REVERB_vCOMB1);  
                        
                     when 1 => 
                        -- acc_mul2 = (valueOut1 * PSXRegs.SPU_REVERB_vCOMB1) >> 14;
                        soundmul1 <= resize(reverbReadval2, 24); 
                        soundmul2 <= signed(REVERB_vCOMB2);  
                        
                     when 2 => 
                        reverb_acc <= resize(soundmulresult14, 20);
                        -- acc_mul3 = (valueOut1 * PSXRegs.SPU_REVERB_vCOMB1) >> 14;
                        soundmul1 <= resize(reverbReadval3, 24); 
                        soundmul2 <= signed(REVERB_vCOMB3);  
                        
                     when 3 => 
                        reverb_acc <= reverb_acc + resize(soundmulresult14, 20);
                        -- acc_mul4 = (valueOut1 * PSXRegs.SPU_REVERB_vCOMB1) >> 14;
                        soundmul1 <= resize(reverbReadval4, 24); 
                        soundmul2 <= signed(REVERB_vCOMB4);  

                     when 4 =>
                        reverb_acc <= reverb_acc + resize(soundmulresult14, 20);
                        -- apf1negMul = (valueOut5 * apf1neg) >> 14;
                        soundmul1 <= resize(reverbReadval5, 24); 
                        soundmul2 <= signed(apf1neg);  
                     
                     when 5 => 
                        reverb_acc <= reverb_acc + resize(soundmulresult14, 20);
                     
                     when 6 =>
                        -- MDA = clamp16((ACC + apf1negMul) >> 1);
                        MDA <= clamp16(shift_right(reverb_acc + soundmulresult14, 1));
                        -- apf2negMul = (valueOut6 * apf2neg) >> 14;
                        soundmul1 <= resize(reverbReadval6, 24); 
                        soundmul2 <= signed(apf2neg);  
                        
                     when 7 =>
                        -- apf1posMul = (MDA * PSXRegs.SPU_REVERB_vAPF1) >> 14;
                        soundmul1 <= resize(MDA, 24); 
                        soundmul2 <= signed(REVERB_vAPF1);  
                        
                     when 8 => null;
                     
                     when 9 =>
                        -- MDB = clamp16(valueOut5 + ((apf1posMul + apf2negMul) >> 1));
                        MDB <= clamp16(resize(reverbReadval5, 26) + shift_right(soundmulresult14 + soundmulresult14_1, 1));

                     when 10 =>
                        -- apf2posMul = (MDB * PSXRegs.SPU_REVERB_vAPF2) >> 15;
                        soundmul1 <= resize(MDB, 24); 
                        soundmul2 <= signed(REVERB_vAPF2); 

                     when 11 => null;

                     when 12 =>
                        -- IVB = clamp16(valueOut6 + apf2posMul);
                        if (reverbRight = '1') then
                           reverbLastRight <= clamp16(resize(reverbReadval6, 25) + soundmulresult15);
                        else
                           reverbLastLeft  <= clamp16(resize(reverbReadval6, 25) + soundmulresult15);
                        end if;
                        
                        reverb_count <= 0;
                        if (cnt(7) = '1' and REVERBOFF = '0') then
                           state <= REVERB_WRITE2;
                        else
                           state <= REVERB_END;
                        end if;
                        
                     when others => null;                     
                  end case;
               
               when REVERB_WRITE2 =>
                  if (reverb_count = 0 or ram_done = '1') then
                     reverb_count <= reverb_count + 1;
                     if (reverb_count < 2) then
                        ram_request    <= '1';
                        ram_isReverb   <= '1';
                        ram_rnw        <= '0';
                        ram_Adr        <= std_logic_vector(reverb_calcAddr);
                     end if;
                     case (reverb_count) is
                        when 0 => ram_dataWrite <= std_logic_vector(MDA); 
                        when 1 => ram_dataWrite <= std_logic_vector(MDB); 
                        when 2 => state <= REVERB_END; reverb_count <= 0;
                        when others => null;                     
                     end case;
                  end if;
                  
               when REVERB_END =>
                  reverb_count <= reverb_count + 1;
                  case (reverb_count) is
                     when 0 => 
                        -- left = (reverbLastLeft * PSXRegs.SPU_REVERB_vLOUT) >> 15;
                        soundmul1 <= resize(reverbLastLeft, 24); 
                        soundmul2 <= signed(REVERB_vLOUT); 
                        
                     when 1 =>
                        -- right = (reverbLastRight * PSXRegs.SPU_REVERB_vROUT) >> 15;
                        soundmul1 <= resize(reverbLastRight, 24); 
                        soundmul2 <= signed(REVERB_vROUT); 
                        
                     when 2 =>
                        if (REVERBOFF = '0') then
                           soundleft <= soundleft + resize(soundmulresult15, 24);
                        end if;
                     
                     when 3 =>
                        if (REVERBOFF = '0') then
                           soundright  <= soundright + resize(soundmulresult15, 24);
                        end if;
                        state       <= CAPTURE0;
                        endProcStep <= 0;
                        reverbRight <= not reverbRight;
                        if (reverbRight = '1') then
                           if (reverbCurrentAddress = 16#3FFFF#) then
                              reverbCurrentAddress <= unsigned(REVERB_mBASE) & "00";
                           else
                              reverbCurrentAddress <= reverbCurrentAddress + 1;
                           end if;
                        end if;
                     
                     when others => null; 
                     
                  end case;

               -- CAPTURE
               when CAPTURE0 =>
                  state <= CAPTURE1;
                  ram_request   <= '1';
                  ram_rnw       <= '0';
                  ram_Adr       <= "0000000" & "00" & std_logic_vector(capturePosition);
                  ram_dataWrite <= std_logic_vector(cd_left);  
                  
               when CAPTURE1 =>
                  state <= CAPTURE2;
                  ram_request   <= '1';
                  ram_rnw       <= '0';
                  ram_Adr       <= "0000000" & "01" & std_logic_vector(capturePosition);
                  ram_dataWrite <= std_logic_vector(cd_right); 
                  
                  -- noise
                  case (CNT(9 downto 8)) is
                     when "01" => noiseCnt <= noiseCnt + 84;
                     when "10" => noiseCnt <= noiseCnt + 140;
                     when "11" => noiseCnt <= noiseCnt + 180;
                     when others => null;
                  end case;
               
               when CAPTURE2 =>
                  state <= CAPTURE3;
                  ram_request   <= '1';
                  ram_rnw       <= '0';
                  ram_Adr       <= "0000000" & "10" & std_logic_vector(capturePosition);
                  ram_dataWrite <= std_logic_vector(voice_lastVolume1);  

                  -- noise
                  if (noiseCnt(15 downto 0) >= 210) then
                     noiseCnt <= noiseCnt + 16#20000# - 210;
                  else
                     noiseCnt <= noiseCnt + 16#10000#;
                  end if;                  
               
               when CAPTURE3 =>
                  capturePosition <= capturePosition + 2;
                  state           <= IDLE;
               
                  ram_request   <= '1';
                  ram_rnw       <= '0';
                  ram_Adr       <= "0000000" & "11" & std_logic_vector(capturePosition);
                  ram_dataWrite <= std_logic_vector(voice_lastVolume3); 
                  
                  -- updateNoise
                  --CNT(13 downto 8) <= std_logic_vector(unsigned(CNT(13 downto 8)) + 1); -- autotest, never synthesize!
                  
                  if (noiseCnt >= noiseCheck) then
                     noiseCnt   <= noiseCnt and (noiseCheck - 1);
                     noiseLevel <= noiseLevel(14 downto 0) & (noiseLevel(15) xor noiseLevel(12) xor noiseLevel(11) xor noiseLevel(10) xor '1');
                  end if;
                  
            end case;

            busy <= '0';
            if (CNT(5 downto 4) = "10" and FifoIn_Empty = '0') then
               busy <= '1';
            end if;
            if (CNT(5 downto 4) = "11" and FifoOut_NearFull = '0') then
               busy <= '1';
            end if;
            
            -- cd sound processing
            case (cdProcStep) is
               when 0 =>
                  soundmul1 <= resize(cd_left, 24);
                  soundmul2 <= signed(CDAUDIO_VOL_L);
                  
               when 1 =>
                  soundmul1 <= resize(cd_right, 24);
                  soundmul2 <= signed(CDAUDIO_VOL_R); 
                  
               when 2 =>
                  cd_next_left <= resize(soundmulresult15, 17);
               
               when 3 =>
                  cd_next_right <= resize(soundmulresult15, 17);
               
               when others => null;
            end case;
            if (cdProcStep < 4) then
               cdProcStep <= cdProcStep + 1;
            end if; 
            
            -- sound end processing
            case (endProcStep) is
               when 0 =>
                  soundmul1 <= soundleft;
                  soundmul2 <= signed(CURVOL_L);
                  
               when 1 =>
                  soundmul1 <= soundright;
                  soundmul2 <= signed(CURVOL_R); 
                  
               when 2 =>
                  if (soundmulresult15 < -32768) then sound_out_left <= x"8000";
                  elsif (soundmulresult15 > 32767) then sound_out_left <= x"7FFF";
                  else sound_out_left <= std_logic_vector(soundmulresult15(15 downto 0));
                  end if;
               
               when 3 =>
                  if (soundmulresult15 < -32768) then sound_out_right <= x"8000";
                  elsif (soundmulresult15 > 32767) then sound_out_right <= x"7FFF";
                  else sound_out_right <= std_logic_vector(soundmulresult15(15 downto 0));
                  end if;
               
               when others => null;
            end case;
            if (endProcStep < 4) then
               endProcStep <= endProcStep + 1;
            end if; 
            
            soundmulresult := soundmul1 * soundmul2;
            soundmulresult14 <= resize(shift_right(soundmulresult, 14), 26);  
            soundmulresult15 <= resize(shift_right(soundmulresult, 15), 25);  
            
            soundmulresult14_1 <= soundmulresult14;

         end if; -- ce
         
         if (rep_counter > 0 and cpuPaused = '0') then
            rep_counter <= rep_counter - 1;
            if (rep_counter = 1) then
               rep_done <= '1';
            end if;
         end if;
         
         if (dma_write = '1') then
            if (FifoIn_Full = '0') then
               FifoIn_Wr  <= '1';
               FifoIn_Din <= dma_writedata;
            end if;
            if (REPRODUCIBLESPUDMA = '1') then
               rep_counter <= rep_counter + 36;
               rep_done    <= '0';
            end if;
         end if;
         
         if (dma_read = '1' and FifoOut_Cnt > 0) then
            FifoOut_Cnt <= FifoOut_Cnt - 1;
            if (state = RAM_READ and ram_done = '1') then
               FifoOut_Cnt <= FifoOut_Cnt;
            end if;
         end if;
         
         if (FifoOut_reset = '1') then
            FifoOut_Cnt <= 0;
         end if;
         
         if (SPUon = '0') then
            sound_out_left  <= (others => '0');
            sound_out_right <= (others => '0');
         end if;
         
         if (SS_RAM_request = '1') then
            ram_dataWrite  <= SS_RAM_dataWrite;    
            ram_Adr        <= SS_RAM_Adr;       
            ram_request    <= SS_RAM_request; 
            ram_isTransfer <= '1';            
            ram_rnw        <= SS_RAM_rnw;        
         end if;
         
      end if;
   end process;
   
--##############################################################
--############################### ADSR
--##############################################################

   adsr_dec(ADSR_OFF    )   <= '1';
   adsr_dec(ADSR_ATTACK )   <= '0';
   adsr_dec(ADSR_DECAY  )   <= '1';
   adsr_dec(ADSR_SUSTAIN)   <= adsrSetting(30);
   adsr_dec(ADSR_RELEASE)   <= '1';
                                
   adsr_exp(ADSR_OFF    )   <= '0';
   adsr_exp(ADSR_ATTACK )   <= adsrSetting(15);
   adsr_exp(ADSR_DECAY  )   <= '1';
   adsr_exp(ADSR_SUSTAIN)   <= adsrSetting(31);
   adsr_exp(ADSR_RELEASE)   <= adsrSetting(21);
                                
   adsr_rate(ADSR_OFF    )  <= (others => '0');
   adsr_rate(ADSR_ATTACK )  <= adsrSetting(14 downto 8);
   adsr_rate(ADSR_DECAY  )  <= '0' & adsrSetting(7 downto 4) & "00";
   adsr_rate(ADSR_SUSTAIN)  <= adsrSetting(28 downto 22);
   adsr_rate(ADSR_RELEASE)  <= adsrSetting(20 downto 16) & "00";
     
--##############################################################
--############################### REVERB
--##############################################################  
  
   REVERB_mSAME  <= unsigned(REVERB_mLSAME ) when (reverbRight = '0') else unsigned(REVERB_mRSAME );
   REVERB_mCOMB1 <= unsigned(REVERB_mLCOMB1) when (reverbRight = '0') else unsigned(REVERB_mRCOMB1);
   REVERB_mCOMB2 <= unsigned(REVERB_mLCOMB2) when (reverbRight = '0') else unsigned(REVERB_mRCOMB2);
   REVERB_dSAME  <= unsigned(REVERB_dLSAME ) when (reverbRight = '0') else unsigned(REVERB_dRSAME );
   REVERB_mDIFF  <= unsigned(REVERB_mLDIFF ) when (reverbRight = '0') else unsigned(REVERB_mRDIFF );
   REVERB_mCOMB3 <= unsigned(REVERB_mLCOMB3) when (reverbRight = '0') else unsigned(REVERB_mRCOMB3);
   REVERB_mCOMB4 <= unsigned(REVERB_mLCOMB4) when (reverbRight = '0') else unsigned(REVERB_mRCOMB4);
   REVERB_dDIFF  <= unsigned(REVERB_dRDIFF ) when (reverbRight = '0') else unsigned(REVERB_dLDIFF );
   REVERB_mAPF1  <= unsigned(REVERB_mLAPF1 ) when (reverbRight = '0') else unsigned(REVERB_mRAPF1 );
   REVERB_mAPF2  <= unsigned(REVERB_mLAPF2 ) when (reverbRight = '0') else unsigned(REVERB_mRAPF2 );
   REVERB_vIN    <=   signed(REVERB_vLIN   ) when (reverbRight = '0') else   signed(REVERB_vRIN   );
   reverb_sample <= reverbsumleft            when (reverbRight = '0') else reverbsumright;
   
   apf1neg <= x"7FFF" when (REVERB_vAPF1 = x"8000") else (to_signed(0, 16) - signed(REVERB_vAPF1));
   apf2neg <= x"7FFF" when (REVERB_vAPF2 = x"8000") else (to_signed(0, 16) - signed(REVERB_vAPF2));
   
   reverb_reqAddr  <= REVERB_dSAME                            when (state = REVERB_READ1  and reverb_count = 0) else
                      REVERB_dDIFF                            when (state = REVERB_READ1  and reverb_count = 1) else
                      REVERB_mSAME                            when (state = REVERB_READ1  and reverb_count = 2) else
                      REVERB_mDIFF                            when (state = REVERB_READ1  and reverb_count = 3) else
                      REVERB_mSAME                            when (state = REVERB_WRITE1 and reverb_count = 0) else
                      REVERB_mDIFF                            when (state = REVERB_WRITE1 and reverb_count = 1) else
                      REVERB_mCOMB1                           when (state = REVERB_READ2  and reverb_count = 0) else
                      REVERB_mCOMB2                           when (state = REVERB_READ2  and reverb_count = 1) else
                      REVERB_mCOMB3                           when (state = REVERB_READ2  and reverb_count = 2) else
                      REVERB_mCOMB4                           when (state = REVERB_READ2  and reverb_count = 3) else
                      (REVERB_mAPF1 - unsigned(REVERB_dAPF1)) when (state = REVERB_READ2  and reverb_count = 4) else
                      (REVERB_mAPF2 - unsigned(REVERB_dAPF2)) when (state = REVERB_READ2  and reverb_count = 5) else
                      REVERB_mAPF1                            when (state = REVERB_WRITE2 and reverb_count = 0) else
                      REVERB_mAPF2;
                 
   reverb_reqAddr2 <= ((reverb_reqAddr & "00") - 1) when (state = REVERB_READ1 and (reverb_count = 2 or reverb_count = 3)) else
                      (reverb_reqAddr & "00");                    
                 
   reverbAddAddr   <= ('0' & reverb_reqAddr2) + ('0' & reverbCurrentAddress);
   
   reverb_calcAddr <= resize(reverbAddAddr + (unsigned(REVERB_mBASE) & "00"), 18) & '0' when (reverbAddAddr(18) = '1') else resize(reverbAddAddr, 18) & '0';
   
--##############################################################
--############################### RAM IF
--##############################################################
   
   SS_RAM_dataRead   <= ram_dataRead;
   SS_RAM_done       <= ram_done;
   
   ispu_ram : entity work.spu_ram
   port map
   (
      clk1x                => clk1x, 
      clk2x                => clk2x,    
      clk2xIndex           => clk2xIndex,      
      ce                   => ce,                 
      reset                => reset,              
                           
      SPUon                => SPUon,           
      useSDRAM             => useSDRAM,           
                            
      -- internal IF       
      ram_dataWrite        => ram_dataWrite,      
      ram_Adr              => ram_Adr,            
      ram_request          => ram_request,          
      ram_rnw              => ram_rnw,           
      ram_dataRead         => ram_dataRead,       
      ram_done             => ram_done,     

      ram_isTransfer       => ram_isTransfer,
      
      ram_isVoice          => ram_isVoice,  
      ram_VoiceIndex       => index,      
      
      ram_isReverb         => ram_isReverb, 
      ram_ReverbIndex      => ram_ReverbIndex,    
                           
      -- SDRAM interface   
      sdram_dataWrite      => sdram_dataWrite,    
      sdram_Adr            => sdram_Adr,          
      sdram_be             => sdram_be,           
      sdram_rnw            => sdram_rnw,          
      sdram_ena            => sdram_ena,          
      sdram_dataRead       => sdram_dataRead,     
      sdram_done           => sdram_done,

      -- DDR3 interface
      mem_request          => mem_request,   
      mem_BURSTCNT         => mem_BURSTCNT,  
      mem_ADDR             => mem_ADDR,      
      mem_DIN              => mem_DIN,       
      mem_BE               => mem_BE,        
      mem_WE               => mem_WE,        
      mem_RD               => mem_RD,        
      mem_ack              => mem_ack,       
      mem_DOUT             => mem_DOUT,      
      mem_DOUT_READY       => mem_DOUT_READY
   );
   
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 63 loop
               ss_in(i) <= (others => '0');
            end loop;
            ss_in(5) <= x"00000001"; -- noiseLevel
            
         elsif (SS_wren = '1' and SS_Adr < 64) then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         SS_idle <= '0';
         if (FifoIn_Empty = '1' and FifoOut_Empty = '1' and state = IDLE and sampleticks < 760 and sampleticks > 0 and stashedSamples = 0) then
            SS_idle <= '1';
         end if;
         
         if (SS_rden = '1') then
            if (SS_Adr < 64) then
               SS_DataRead <= ss_out(to_integer(SS_Adr));
            elsif (SS_Adr >= 64 and SS_Adr < 256) then
               SS_DataRead <= x"0000" & RamVoice_dataB(1);
            elsif (SS_Adr >= 256 and SS_Adr < 304) then
               SS_DataRead <= x"0000" & RamVoiceVolumes_dataB(1);    
            elsif (SS_Adr >= 320 and SS_Adr < 370) then
               SS_DataRead <= "0000000" & EnvCounterRam_dataB;
            elsif (SS_Adr >= 384 and SS_Adr < 480) then
                case (SS_Adr(1 downto 0)) is
                   when "00" => SS_DataRead <= x"0000" & RamVoiceRecord_dataB(1)(15 downto 0);     -- voice.currentAddr
                   when "01" => SS_DataRead <= RamVoiceRecord_dataB(1)(47 downto 16);              -- voice.adpcmLast0 + voice.adpcmLast1
                   when "10" => SS_DataRead <= "000" & RamVoiceRecord_dataB(1)(76 downto 48);      -- voice.adpcmSamplePos + voice.adpcmDecodePtr + voice.adsrphase 
                   when "11" => SS_DataRead <= x"00" & RamVoiceRecord_dataB(1)(100 downto 77);     -- voice.adsrTicks
                   when others =>
                end case;
            else
               SS_DataRead <= (others => '0');
            end if;
         end if;
      
      end if;
   end process;

   -- synthesis translate_off

   goutput : if 1 = 1 generate
   signal outputCnt        : unsigned(31 downto 0) := (others => '0'); 
   signal clkCounter       : unsigned(31 downto 0) := (others => '0'); 
   signal clkCounter_start : unsigned(31 downto 0) := (others => '0'); 
   
   begin
      process
         constant WRITETIME            : std_logic := '1';
         
         file outfile                  : text;
         variable f_status             : FILE_OPEN_STATUS;
         variable line_out             : line;    
         
         variable bus_read_1           : std_logic;
         variable bus_addr_1           : unsigned(9 downto 0);
         
         variable newoutputCnt         : unsigned(31 downto 0); 
         
         variable debugout_buf         : tdebugout_buf;
         variable debugout_ptr         : integer;
         variable outputNext           : integer;
         
         variable irq_1                : std_logic := '0';
         variable adsrphase_1          : unsigned(2 downto 0);
         
         variable envdebug_left        : signed(15 downto 0);
         variable envdebug_right       : signed(15 downto 0);
         
         variable noiseLevel_1         : unsigned(15 downto 0);
         
         variable capture3_1           : std_logic := '0';

      begin
   
         file_open(f_status, outfile, "R:\\debug_sound_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\debug_sound_sim.txt", append_mode);
         
         debugout_ptr := -1;
         outputNext := 0;
                     
         wait until reset = '1';
         wait until reset = '0';
         clkCounter <= (others => '0');
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            newoutputCnt := outputCnt;
                        
            --if (dma_write = '1') then
            --   write(line_out, string'("DMAWRITE: ")); 
            --   if (WRITETIME = '1') then
            --      write(line_out, to_hstring(clkCounter + 1));
            --   end if;
            --   write(line_out, string'(" 0000 ")); 
            --   write(line_out, to_hstring(dma_writedata));
            --   writeline(outfile, line_out);
            --   newoutputCnt := newoutputCnt + 1;
            --end if;
            
            if (dma_read = '1') then
               write(line_out, string'("DMAREAD: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
               end if;
               write(line_out, string'(" 0000 ")); 
               write(line_out, to_hstring(dma_readdata));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if (outputNext = 2) then
               outputNext := 0;
               for i in 0 to debugout_ptr loop
                  case (debugout_buf(i).datatype) is
                     when  6  => write(line_out, string'("ADPCM: "));
                     when  7  => write(line_out, string'("CHAN: "));
                     when  8  => write(line_out, string'("ADSRTICKS: "));
                     when  9  => write(line_out, string'("REVERBWRITE: "));
                     when  10 => write(line_out, string'("REVERBREAD: "));
                     when  11 => write(line_out, string'("REVERBSAMPLE: "));
                     when  12 => write(line_out, string'("CAPTURE: "));
                     when  13 => write(line_out, string'("ENVCHAN: "));
                     when  14 => write(line_out, string'("NOISE: "));
                     when  15 => write(line_out, string'("DMARAM: "));
                     when  16 => write(line_out, string'("ADSRVOLUME: "));
                     when  17 => write(line_out, string'("IRQ: "));
                     when others => write(line_out, string'("UNKNOWN: ")); 
                  end case;
                  
                  if (WRITETIME = '1') then
                     write(line_out, to_hstring(clkCounter - 1));
                  end if;
                  write(line_out, string'(" "));
                  write(line_out, to_hstring(debugout_buf(i).addr));
                  write(line_out, string'(" "));
                  write(line_out, to_hstring(debugout_buf(i).data));
                  writeline(outfile, line_out);
                  newoutputCnt := newoutputCnt + 1;
               end loop;
            
               write(line_out, string'("SAMPLEOUT: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 1));
               end if;
               write(line_out, string'(" 0000 ")); 
               write(line_out, to_hstring(sound_out_left));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
               write(line_out, string'("SAMPLEOUT: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter - 1));
               end if;
               write(line_out, string'(" 0001 ")); 
               write(line_out, to_hstring(sound_out_right));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
               
               clkCounter_start <= clkCounter;
               
               debugout_ptr := -1;
            end if;
            
            if (capture3_1 = '1') then
               outputNext := 1;
            end if;
            
            if (sampleticks = 767 and outputNext = 1) then
               outputNext := 2;
            end if;
            
            if (bus_read_1 = '1') then
               write(line_out, string'("READREG: "));
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter));
               end if;
               write(line_out, string'(" ")); 
               write(line_out, to_hstring("000000" & bus_addr_1));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(bus_dataRead));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            bus_read_1 := bus_read;
            bus_addr_1 := bus_addr;
            
            if (bus_write = '1') then
               write(line_out, string'("WRITEREG: ")); 
               if (WRITETIME = '1') then
                  write(line_out, to_hstring(clkCounter + 1));
               end if;
               write(line_out, string'(" ")); 
               write(line_out, to_hstring("000000" & bus_addr));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(bus_dataWrite));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if; 
            
            if ((state = REVERB_READ1 or state = REVERB_READ2) and ram_done = '1') then
               debugout_ptr := debugout_ptr + 1;
               debugout_buf(debugout_ptr).datatype := 10;
               debugout_buf(debugout_ptr).addr := unsigned(ram_Adr(15 downto 0));
               debugout_buf(debugout_ptr).data := unsigned(ram_dataRead);
            end if;
            
            if ((state = REVERB_WRITE1 or state = REVERB_WRITE2) and ram_request = '1') then
               debugout_ptr := debugout_ptr + 1;
               debugout_buf(debugout_ptr).datatype := 9;
               debugout_buf(debugout_ptr).addr := unsigned(ram_Adr(15 downto 0));
               debugout_buf(debugout_ptr).data := unsigned(ram_dataWrite);
            end if;            
            
            if (state = REVERB_END and reverb_count = 0 and (reverbLastLeft /= 0 or reverbLastRight /= 0)) then
               debugout_ptr := debugout_ptr + 1;
               debugout_buf(debugout_ptr).datatype := 11;
               debugout_buf(debugout_ptr).addr := unsigned(reverbLastLeft);
               debugout_buf(debugout_ptr).data := unsigned(reverbLastRight);
            end if;
            
            if ((state = CAPTURE1 or state = CAPTURE2 or state = CAPTURE3 or capture3_1 = '1') and ram_dataWrite /= x"0000")  then
               debugout_ptr := debugout_ptr + 1;
               debugout_buf(debugout_ptr).datatype := 12;
               debugout_buf(debugout_ptr).addr := unsigned(ram_Adr(15 downto 0));
               debugout_buf(debugout_ptr).data := unsigned(ram_dataWrite);
            end if;
                        
            if (capture3_1 = '1' and noiseLevel_1 /= noiseLevel) then
               debugout_ptr := debugout_ptr + 1;
               debugout_buf(debugout_ptr).datatype := 14;
               debugout_buf(debugout_ptr).addr := x"0000";
               debugout_buf(debugout_ptr).data := unsigned(noiseLevel);
            end if;
            noiseLevel_1 := noiseLevel;
            
            capture3_1 := '0';
            if (state = CAPTURE3) then
               capture3_1 := '1';
            end if;
            
            if (irq_1 = '0' and irqOut = '1') then
               if (REPRODUCIBLESPUIRQ = '1') then
                  write(line_out, string'("IRQ: ")); 
                  if (WRITETIME = '1') then
                     write(line_out, to_hstring(clkCounter - 1));
                  end if;
                  write(line_out, string'(" 0000 0000")); 
                  writeline(outfile, line_out);
                  newoutputCnt := newoutputCnt + 1;
               else
                  debugout_ptr := debugout_ptr + 1;
                  debugout_buf(debugout_ptr).datatype := 17;
                  debugout_buf(debugout_ptr).addr := x"0000";
                  debugout_buf(debugout_ptr).data := x"0000";
               end if;
            end if;  
            irq_1 := irqOut;
                    
            if (state = VOICE_APPLYVOLUME) then
               adsrphase_1 := voice.adsrphase;
            end if;
            
            if (envelopeState = ENV_WRITE) then
               if (envelopeRight = '1') then
                  envdebug_right := envVolume;
               else
                  envdebug_left := envVolume;
               end if;
            end if;
            
            if (state = VOICE_CHECKEND) then
                 
               if (adsrphase_1 /= ADSRPHASE_OFF) then
                  debugout_ptr := debugout_ptr + 1;
                  debugout_buf(debugout_ptr).datatype := 6;
                  debugout_buf(debugout_ptr).addr := to_unsigned(index, 8) & resize(sampleIndex, 8);
                  debugout_buf(debugout_ptr).data := unsigned(sample);
               end if;

               if (voice.adsrphase /= ADSRPHASE_OFF) then               
                  debugout_ptr := debugout_ptr + 1;
                  debugout_buf(debugout_ptr).datatype := 8;
                  debugout_buf(debugout_ptr).addr := to_unsigned(index, 8) & resize(voice.adsrphase, 8);
                  debugout_buf(debugout_ptr).data := voice.adsrTicks(15 downto 0);
                  
                  debugout_ptr := debugout_ptr + 1;
                  debugout_buf(debugout_ptr).datatype := 16;
                  debugout_buf(debugout_ptr).addr := to_unsigned(index, 8) & x"00";
                  debugout_buf(debugout_ptr).data := unsigned(adsrVolumeNew);
               end if;
            
               if (envdebug_left /= 0) then
                  debugout_ptr := debugout_ptr + 1;
                  debugout_buf(debugout_ptr).datatype := 13;
                  debugout_buf(debugout_ptr).addr := x"00" & to_unsigned(index, 8);
                  debugout_buf(debugout_ptr).data := unsigned(envdebug_left);
               end if;
               if (envdebug_right /= 0) then
                  debugout_ptr := debugout_ptr + 1;
                  debugout_buf(debugout_ptr).datatype := 13;
                  debugout_buf(debugout_ptr).addr := x"01" & to_unsigned(index, 8);
                  debugout_buf(debugout_ptr).data := unsigned(envdebug_right);
               end if;
               
               if (chanLeft /= 0) then
                  debugout_ptr := debugout_ptr + 1;
                  debugout_buf(debugout_ptr).datatype := 7;
                  debugout_buf(debugout_ptr).addr := x"00" & to_unsigned(index, 8);
                  debugout_buf(debugout_ptr).data := unsigned(chanLeft(15 downto 0));
               end if;
               if (chanRight /= 0) then
                  debugout_ptr := debugout_ptr + 1;
                  debugout_buf(debugout_ptr).datatype := 7;
                  debugout_buf(debugout_ptr).addr := x"01" & to_unsigned(index, 8);
                  debugout_buf(debugout_ptr).data := unsigned(chanRight(15 downto 0));
               end if;
               
            end if;
            
            --if (state = RAM_WRITE and FifoIn_Empty = '0' and ramcount < 24) then
            --   debugout_ptr := debugout_ptr + 1;
            --   debugout_buf(debugout_ptr).datatype := 15;
            --   debugout_buf(debugout_ptr).addr := ramTransferAddr(15 downto 0);
            --   debugout_buf(debugout_ptr).data := unsigned(FifoIn_Dout);
            --end if;
            
            outputCnt <= newoutputCnt;
            clkCounter <= clkCounter + 1;
            
            if (reset = '1') then
               clkCounter <= (others => '0');
               file_close(outfile);
               file_open(f_status, outfile, "R:\\debug_sound_sim.txt", write_mode);
               file_close(outfile);
               file_open(f_status, outfile, "R:\\debug_sound_sim.txt", append_mode);
               debugout_ptr := -1;
            end if;
           
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on

end architecture;





