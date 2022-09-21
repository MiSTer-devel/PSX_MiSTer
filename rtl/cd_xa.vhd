library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;

entity cd_xa is
   port 
   (
      clk1x                : in  std_logic;
      reset                : in  std_logic;

      spu_tick             : in  std_logic;
      
      CDDA_write           : in  std_logic;
      CDDA_data            : in  std_logic_vector(31 downto 0);

      XA_addr              : in  integer range 0 to 587;
      XA_data              : in  std_logic_vector(31 downto 0);
      XA_write             : in  std_logic;
      XA_start             : in  std_logic;
      XA_reset             : in  std_logic;
      
      XA_eof               : out std_logic := '0';
      
      cdaudio_left         : out signed(15 downto 0) := (others => '0');
      cdaudio_right        : out signed(15 downto 0) := (others => '0')
   );
end entity;

architecture arch of cd_xa is
  
  -- ram IN
  signal RamIn_addrA : unsigned(9 downto 0);
  signal RamIn_addrB : unsigned(11 downto 0);
  signal RamIn_dataB : std_logic_vector(7 downto 0);
 
  -- adpcm decoding
  type tAdpcmState is
   (
      ADPCM_IDLE,
      ADPCM_EVALEOF,
      ADPCM_EVALHEADER,
      ADPCM_NEXTCHUNK,
      ADPCM_NEXTBLOCK,
      ADPCM_READBLOCKHEADER,
      ADPCM_EVALBLOCKHEADER,
      ADPCM_STARTSAMPLE,
      ADPCM_READSAMPLE,
      ADPCM_GETNIBBLE,
      ADPCM_CALCRESULT,
      ADPCM_CLAMP
   );
   signal AdpcmState    : tAdpcmState := ADPCM_IDLE;
   
   signal bitsPerSample  : std_logic_vector(1 downto 0);
   signal stereo         : std_logic_vector(1 downto 0);
   signal sampleRate     : std_logic;
  
   signal chunkCounter   : integer range 0 to 18;
   signal chunkPtr       : integer range 0 to 4095;
  
   signal blockCounter   : integer range 0 to 8;
   signal blockCount     : integer range 4 to 8;
   
   signal adpcm_shift    : integer range 0 to 12;
   signal filterPos      : integer range -128 to 127;
   signal filterNeg      : integer range -128 to 127; 
   
   signal sampleCounter  : integer range 0 to 28;
   signal sampleNew      : signed(15 downto 0);
   signal oldSum         : signed(31 downto 0);
   signal sample         : signed(23 downto 0);
   signal clamped        : signed(15 downto 0);
   
   signal AdpcmLast0_L   : signed(23 downto 0);
   signal AdpcmLast0_R   : signed(23 downto 0);
   signal AdpcmLast1_L   : signed(23 downto 0);
   signal AdpcmLast1_R   : signed(23 downto 0);
   
   signal adpcm_mul1     : signed(23 downto 0);
   signal adpcm_mul2     : signed(7 downto 0);
   signal adpcm_mulres   : signed(31 downto 0);
   
   -- fifo ADPCM
   signal adpcm_writeLeft    : std_logic := '0';
   signal adpcm_writeRight   : std_logic := '0';
   
   signal FifoADPCM_L_reset  : std_logic := '0';
   signal FifoADPCM_R_reset  : std_logic := '0';
   signal FifoADPCM_L_Dout   : std_logic_vector(15 downto 0);
   signal FifoADPCM_R_Dout   : std_logic_vector(15 downto 0);
   signal FifoADPCM_Rd       : std_logic := '0';
   signal FifoADPCM_Empty    : std_logic;
   signal FifoADPCM_NearFull : std_logic;
  
   -- resample
   type tResampleState is
   (
      RESAMPLE_IDLE,
      RESAMPLE_CLEAR,
      RESAMPLE_WAITFIFO,
      RESAMPLE_READFIFO,
      RESAMPLE_WRITERING,
      RESAMPLE_NEXTSAMPLE,
      RESAMPLE_READRING,
      RESAMPLE_MUL,
      RESAMPLE_SUM,
      RESAMPLE_CLAMP
   );
   signal ResampleState       : tResampleState := RESAMPLE_IDLE;
   
   type tXaRingBuffer is array(0 to 31) of signed(15 downto 0);
   signal XaRingBufferL       : tXaRingBuffer;
   signal XaRingBufferR       : tXaRingBuffer;
  
   signal XaRing_pointer      : unsigned(4 downto 0);
   signal XaRing_readpointer  : unsigned(4 downto 0);
   signal XaSixStep           : integer range 0 to 6;
  
   signal resampleDup         : std_logic;
   signal ringInL             : signed(15 downto 0);
   signal ringInR             : signed(15 downto 0);
   
   signal resampleDir         : std_logic;
   signal resampleSamples     : unsigned(2 downto 0) := (others => '0');
   signal resampleSampleCnt   : unsigned(4 downto 0) := (others => '0');
   
   signal ringOut             : signed(15 downto 0);
   signal zigZagAddr          : unsigned(7 downto 0);
   signal zigZagOut           : signed(15 downto 0);
   signal resampleMul         : signed(16 downto 0);
   signal resampleSum         : signed(21 downto 0);
  
   -- fifoOut
   signal FifoOut_reset       : std_logic := '0';
   signal FifoOut_Din         : std_logic_vector(31 downto 0) := (others => '0');
   signal FifoOut_Wr          : std_logic := '0'; 
   signal FifoOut_NearFull    : std_logic; 
   signal FifoOut_Dout        : std_logic_vector(31 downto 0);
   signal FifoOut_Rd          : std_logic := '0';
   signal FifoOut_Empty       : std_logic;
  
  
begin 

   RamIn_addrA <= to_unsigned(XA_addr, 10);
   

   iRAmIN: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 10,
      data_width_a  => 32,
      addr_width_b  => 12,
      data_width_b  => 8
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => std_logic_vector(RamIn_addrA),
      data_a      => XA_data,
      wren_a      => XA_write,
      
      clock_b     => clk1x,
      address_b   => std_logic_vector(RamIn_addrB),
      data_b      => x"00",
      wren_b      => '0',
      q_b         => RamIn_dataB
   );
   
   -- adpcm decoding
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then

         XA_eof            <= '0';
         
         FifoADPCM_L_reset <= '0';
         FifoADPCM_R_reset <= '0';
         
         adpcm_writeLeft   <= '0';
         adpcm_writeRight  <= '0';

         adpcm_mulres <= adpcm_mul1 * adpcm_mul2;

         if (reset = '1') then
         
            AdpcmState      <= ADPCM_IDLE;
            
         else
         
            case (AdpcmState) is
            
               when ADPCM_IDLE =>
                  chunkCounter  <= 0;
                  chunkPtr      <= 24;
                  RamIn_addrB <= to_unsigned(16 + 2, 12);
                  if (XA_start = '1' and FifoADPCM_NearFull = '0') then -- skip sector if Fifo still has data -> e.g. used in Rugrats - Search for Reptar
                     AdpcmState  <= ADPCM_EVALEOF;
                     RamIn_addrB <= to_unsigned(16 + 3, 12);
                  end if;
               
               when ADPCM_EVALEOF =>
                  AdpcmState <= ADPCM_EVALHEADER;
                  if (RamIn_dataB(7) = '1') then
                     XA_eof <= '1';
                  end if;
               
               when ADPCM_EVALHEADER =>
                  AdpcmState    <= ADPCM_NEXTCHUNK;
                  bitsPerSample <= RamIn_dataB(5 downto 4);
                  stereo        <= RamIn_dataB(1 downto 0);
                  sampleRate    <= RamIn_dataB(2);
                  
               when ADPCM_NEXTCHUNK =>
                  if (chunkCounter = 18) then
                     AdpcmState <= ADPCM_IDLE;
                  else
                     if (bitsPerSample = "01") then blockcount <= 4; else blockcount <= 8; end if;
                     blockCounter <= 0;
                     AdpcmState   <= ADPCM_NEXTBLOCK;
                  end if;
                  
               when ADPCM_NEXTBLOCK =>
                  if (blockCounter = blockcount) then
                     chunkCounter <= chunkCounter + 1;
                     AdpcmState   <= ADPCM_NEXTCHUNK;
                     chunkPtr     <= chunkPtr + 128;
                  else
                     RamIn_addrB <= to_unsigned(chunkPtr + 4 + blockCounter, 12);
                     AdpcmState  <= ADPCM_READBLOCKHEADER;
                  end if;
                     
               when ADPCM_READBLOCKHEADER =>
                  AdpcmState <= ADPCM_EVALBLOCKHEADER;
               
               when ADPCM_EVALBLOCKHEADER =>
                  AdpcmState    <= ADPCM_STARTSAMPLE;
                  sampleCounter <= 0;
                  if (unsigned(RamIn_dataB(3 downto 0)) < 13) then
                     adpcm_shift <= to_integer(unsigned(RamIn_dataB(3 downto 0)));
                  else
                     adpcm_shift <= 9;
                  end if;
                  case (RamIn_dataB(5 downto 4)) is
                     when "00" => filterPos <=   0; filterNeg <= 0;
                     when "01" => filterPos <=  60; filterNeg <= 0;
                     when "10" => filterPos <= 115; filterNeg <= -52;
                     when "11" => filterPos <=  98; filterNeg <= -55;
                     when others => null;
                  end case;

               when ADPCM_STARTSAMPLE => 
                  AdpcmState <= ADPCM_READSAMPLE;
                  if (bitsPerSample = "01") then
                     RamIn_addrB <= to_unsigned(chunkPtr + 16 + blockCounter + sampleCounter * 4, 12);
                  else
                     RamIn_addrB <= to_unsigned(chunkPtr + 16 + (blockCounter / 2) + sampleCounter * 4, 12);
                  end if;
                  
                  if ((blockcounter mod 2) = 1 and stereo = "01") then
                     adpcm_mul1 <= AdpcmLast0_R;
                  else
                     adpcm_mul1 <= AdpcmLast0_L;
                  end if;
                  adpcm_mul2 <= to_signed(filterPos, 8);
                  
               when ADPCM_READSAMPLE =>
                  AdpcmState <= ADPCM_GETNIBBLE;

                  if ((blockcounter mod 2) = 1 and stereo = "01") then
                     adpcm_mul1 <= AdpcmLast1_R;
                  else
                     adpcm_mul1 <= AdpcmLast1_L;
                  end if;
                  adpcm_mul2 <= to_signed(filterNeg, 8);

               when ADPCM_GETNIBBLE =>
                  AdpcmState   <= ADPCM_CALCRESULT;
                  if (bitsPerSample = "01") then
                     sampleNew <= resize(shift_right(signed(RamIn_dataB) & x"00", adpcm_shift),16);
                  else
                     if ((blockcounter mod 2) = 1) then
                        sampleNew <= resize(shift_right(signed(RamIn_dataB(7 downto 4)) & x"000", adpcm_shift),16);
                     else
                        sampleNew <= resize(shift_right(signed(RamIn_dataB(3 downto 0)) & x"000", adpcm_shift),16);
                     end if;
                  end if;
                  
                  oldSum <= adpcm_mulres;
               
               when ADPCM_CALCRESULT =>
                  AdpcmState  <= ADPCM_CLAMP;
                  sample      <= resize((oldSum + adpcm_mulres + 32) / 64, 24) + resize(sampleNew, 24);
                  
               when ADPCM_CLAMP =>
                  if (sampleCounter = 27) then
                     AdpcmState   <= ADPCM_NEXTBLOCK;
                     blockCounter <= blockCounter + 1;
                  else
                     sampleCounter <= sampleCounter + 1;
                     AdpcmState    <= ADPCM_STARTSAMPLE;
                  end if;
         
                  if (sample < -32768) then clamped <= x"8000";
                  elsif (sample > 32767) then clamped <= x"7FFF";
                  else clamped <= sample(15 downto 0);
                  end if;
                  
                  if (stereo = "01") then
                     if ((blockcounter mod 2) = 1) then
                        adpcm_writeRight <= '1';
                     else
                        adpcm_writeLeft  <= '1';
                     end if;
                  else
                     adpcm_writeLeft  <= '1';
                     adpcm_writeRight <= '1';
                  end if;
                  
                  if ((blockcounter mod 2) = 1 and stereo = "01") then
                     AdpcmLast0_R <= sample;
                     AdpcmLast1_R <= AdpcmLast0_R;
                  else
                     AdpcmLast0_L <= sample;
                     AdpcmLast1_L <= AdpcmLast0_L;
                  end if;
         
            end case;
            
         end if;
         
         if (XA_reset = '1') then
            XA_eof            <= '1';
            
            FifoADPCM_L_reset <= '1';
            FifoADPCM_R_reset <= '1';
            
            AdpcmLast0_L      <= (others => '0');
            AdpcmLast1_L      <= (others => '0');
            AdpcmLast0_R      <= (others => '0');
            AdpcmLast1_R      <= (others => '0');
            
         end if;
         
      end if;
   end process;
   
   ififoADPCM_L: entity mem.SyncFifo
   generic map
   (
      SIZE             => 4096,
      DATAWIDTH        => 16,
      NEARFULLDISTANCE => 16
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoADPCM_L_reset,   
                
      Din      => std_logic_vector(clamped),     
      Wr       => adpcm_writeLeft,      
      Full     => open,    
      NearFull => open,

      Dout     => FifoADPCM_L_Dout,    
      Rd       => FifoADPCM_Rd,      
      Empty    => open 
   );
   
   ififoADPCM_R: entity mem.SyncFifo
   generic map
   (
      SIZE             => 4096,
      DATAWIDTH        => 16,
      NEARFULLDISTANCE => 16
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => FifoADPCM_R_reset,   
                
      Din      => std_logic_vector(clamped),     
      Wr       => adpcm_writeRight,      
      Full     => open,    
      NearFull => FifoADPCM_NearFull,

      Dout     => FifoADPCM_R_Dout,    
      Rd       => FifoADPCM_Rd,      
      Empty    => FifoADPCM_Empty   
   );
   
   zigZagAddr <= resampleSamples & resampleSampleCnt;
   
   icd_xa_zigzag : entity work.cd_xa_zigzag
   port map
   (
      clk1x  => clk1x,
      addr   => zigZagAddr,
      data   => zigZagOut
   );
   
   -- resample
   process(clk1x)
      variable clamp  : signed(15 downto 0);
   begin
      if (rising_edge(clk1x)) then

         FifoADPCM_Rd      <= '0';
         
         FifoOut_reset     <= '0';
         FifoOut_Wr        <= '0';

         if (reset = '1' or XA_reset = '1') then
         
            FifoOut_reset    <= '1';
            ResampleState    <= RESAMPLE_CLEAR;
            resampleDup      <= '0';
            XaRing_pointer   <= (others => '0');
           
         else
         
            if (CDDA_write = '1') then
               FifoOut_Wr  <= '1';
               FifoOut_Din <= CDDA_data;
            end if;
         
            case (ResampleState) is
            
               when RESAMPLE_IDLE =>
                  if (XaSixStep = 6) then
                     ResampleState   <= RESAMPLE_NEXTSAMPLE;
                     resampleSamples <= (others => '0');
                     XaSixStep       <= 0;
                     resampleDir     <= '0';
                  elsif (FifoOut_NearFull = '0' and resampleDup = '1') then
                     ResampleState <= RESAMPLE_WRITERING;
                     resampleDup   <= '0';
                  elsif (FifoOut_NearFull = '0' and FifoADPCM_Empty = '0') then
                     ResampleState <= RESAMPLE_WAITFIFO;
                     FifoADPCM_Rd  <= '1';
                  end if;
               
               when RESAMPLE_CLEAR =>
                  XaRing_pointer <= XaRing_pointer + 1;
                  if (XaRing_pointer = 31) then
                     ResampleState <= RESAMPLE_IDLE;
                  end if;
                  
                  XaRingBufferL(to_integer(XaRing_pointer)) <= (others => '0');
                  XaRingBufferR(to_integer(XaRing_pointer)) <= (others => '0');
                  XaSixStep      <= 0;
               
               when RESAMPLE_WAITFIFO =>
                  ResampleState <= RESAMPLE_READFIFO;
                  
               when RESAMPLE_READFIFO =>
                  ringInL       <= signed(FifoADPCM_L_Dout(15 downto 0));
                  ringInR       <= signed(FifoADPCM_R_Dout(15 downto 0));
                  ResampleState <= RESAMPLE_WRITERING;
                  
                  if (sampleRate = '1') then
                     resampleDup <= '1';
                  end if;
               
               when RESAMPLE_WRITERING =>
                  ResampleState                 <= RESAMPLE_IDLE;
                  XaSixStep                     <= XaSixStep + 1;
                  XaRing_pointer                <= XaRing_pointer + 1;
                  XaRingBufferL(to_integer(XaRing_pointer)) <= ringInL;
                  XaRingBufferR(to_integer(XaRing_pointer)) <= ringInR;
               
               when RESAMPLE_NEXTSAMPLE =>
                  if (resampleSamples = 7) then
                     ResampleState <= RESAMPLE_IDLE;
                  else
                     ResampleState      <= RESAMPLE_READRING;
                     resampleSampleCnt  <= (others => '0');
                     resampleSum        <= (others => '0');
                     XaRing_readpointer <= XaRing_pointer;
                  end if;
               
               when RESAMPLE_READRING =>
                  ResampleState <= RESAMPLE_MUL;
                  if (resampleDir = '0') then
                     ringOut <= XaRingBufferL(to_integer(XaRing_readpointer));
                  else
                     ringOut <= XaRingBufferR(to_integer(XaRing_readpointer));
                  end if;
                  --zigZagOut <= zigzagTable(resampleSamples * 32 + to_integer(resampleSampleCnt));
                  XaRing_readpointer <= XaRing_readpointer - 1;
                  
               when RESAMPLE_MUL =>
                  ResampleState <= RESAMPLE_SUM;
               
               when RESAMPLE_SUM =>
                  resampleSum <= resampleSum + resampleMul;
                  
                  if (resampleSampleCnt = 28) then
                     ResampleState <= RESAMPLE_CLAMP;
                  else
                     ResampleState     <= RESAMPLE_READRING;
                     resampleSampleCnt <= resampleSampleCnt + 1;
                  end if;
                  
               when RESAMPLE_CLAMP =>
                  if (resampleSum < -32768) then clamp := x"8000";
                  elsif (resampleSum > 32767) then clamp := x"7FFF";
                  else clamp := resampleSum(15 downto 0);
                  end if;
                  
                  if (resampleDir = '0') then
                     FifoOut_Din(15 downto 0) <= std_logic_vector(clamp);
                     resampleDir              <= '1';
                     ResampleState            <= RESAMPLE_READRING;
                     resampleSampleCnt        <= (others => '0');
                     resampleSum              <= (others => '0');
                     XaRing_readpointer       <= XaRing_pointer;
                  else
                     FifoOut_Wr                <= '1';
                     FifoOut_Din(31 downto 16) <= std_logic_vector(clamp);
                     resampleDir               <= '0';
                     ResampleState             <= RESAMPLE_NEXTSAMPLE;
                     resampleSamples           <= resampleSamples + 1;
                  end if;
                  
            end case;
            
         end if;
         
         resampleMul <= resize(ringOut * zigZagOut / 16#8000#, 17);
         
      end if;
   end process;
   
   ififoOut: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 1024,
      DATAWIDTH        => 32,
      NEARFULLDISTANCE => 16
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
   
   -- output
   process(clk1x)
   begin
      if (rising_edge(clk1x)) then

         FifoOut_Rd <= '0';

         if (reset = '1') then
            cdaudio_left  <= (others => '0');
            cdaudio_right <= (others => '0');
         else
            if (spu_tick = '1') then
               if (FifoOut_Empty = '0') then
                  FifoOut_Rd <= '1';
                  cdaudio_left  <= signed(FifoOut_Dout(15 downto  0));
                  cdaudio_right <= signed(FifoOut_Dout(31 downto 16));
               --else
               --   sampleOut  <= (others => '0');
               end if;
            end if;
         end if;
         
      end if;
   end process;
   
   -- synthesis translate_off

   goutput : if 1 = 1 generate
   signal outputCnt1  : unsigned(23 downto 0) := (others => '0'); 
   signal outputCnt2  : unsigned(23 downto 0) := (others => '0'); 
   
   begin
      process
         file outfile1                  : text;
         file outfile2                  : text;
         variable f_status             : FILE_OPEN_STATUS;
         variable line_out             : line;
         variable newoutputCnt1         : unsigned(23 downto 0);
         variable newoutputCnt2         : unsigned(23 downto 0);
      begin
   
         file_open(f_status, outfile1, "R:\\debug_xa1_sim.txt", write_mode);
         file_close(outfile1);
         file_open(f_status, outfile1, "R:\\debug_xa1_sim.txt", append_mode);
         
         file_open(f_status, outfile2, "R:\\debug_xa2_sim.txt", write_mode);
         file_close(outfile2);
         file_open(f_status, outfile2, "R:\\debug_xa2_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            newoutputCnt1 := outputCnt1;
            newoutputCnt2 := outputCnt2;
            
            if (XA_write = '1') then
               write(line_out, string'("DATAIN: "));
               write(line_out, to_hstring(newoutputCnt1));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(XA_data));
               writeline(outfile1, line_out);
               newoutputCnt1 := newoutputCnt1 + 1;
            end if; 
            
            if (adpcm_writeLeft = '1' or adpcm_writeRight = '1') then
               write(line_out, string'("ADPCMCALC: "));
               write(line_out, to_hstring(newoutputCnt1));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(unsigned(resize(clamped, 32))));
               writeline(outfile1, line_out);
               newoutputCnt1 := newoutputCnt1 + 1;
            end if;
            
            if (FifoOut_Wr = '1') then
               write(line_out, string'("OUT: "));
               write(line_out, to_hstring(newoutputCnt2));
               write(line_out, string'(" ")); 
               write(line_out, to_hstring(unsigned(FifoOut_Din)));
               writeline(outfile2, line_out);
               newoutputCnt2 := newoutputCnt2 + 1;
            end if;
            
            
            outputCnt1 <= newoutputCnt1;
            outputCnt2 <= newoutputCnt2;
           
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on

end architecture;





