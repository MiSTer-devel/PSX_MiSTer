library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;

entity mdec is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(31 downto 0);
      
      dmaWriteRequest      : out std_logic;
      dmaReadRequest       : out std_logic;
      dma_write            : in  std_logic;
      dma_writedata        : in  std_logic_vector(31 downto 0);
      dma_read             : in  std_logic;
      dma_readdata         : out std_logic_vector(31 downto 0);
      
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(6 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0);
      SS_Idle              : out std_logic
   );
end entity;

architecture arch of mdec is
  
   signal reset_receive       : std_logic := '0';
   signal reset_calc          : std_logic := '0';
  
   signal FifoIn_Din          : std_logic_vector(31 downto 0) := (others => '0');
   signal FifoIn_Wr           : std_logic; 
   signal FifoIn_NearFull     : std_logic;
   signal FifoIn_Dout         : std_logic_vector(31 downto 0);
   signal FifoIn_Rd           : std_logic;
   signal FifoIn_Empty        : std_logic;
  
   type treceiveState is
   (
      RECEIVE_IDLE,
      RECEIVE_YUV,
      RECEIVE_SCALE,
      RECEIVE_BLOCK
   );
   signal receiveState        : treceiveState := RECEIVE_IDLE;
      
   signal isColor             : std_logic := '0'; 
   signal recCount            : unsigned(4 downto 0);
   signal wordsRemain         : unsigned(15 downto 0) := (others => '0');
   
   signal rec_depth           : std_logic_vector(1 downto 0) := "00";
   signal rec_signed          : std_logic := '0';
   signal rec_bit15           : std_logic := '0';
      
   signal RamYUVaddrA         : unsigned(4 downto 0) := (others => '0');
   signal RamYUVdataA         : std_logic_vector(31 downto 0) := (others => '0');
   signal RamYUVwrite         : std_logic := '0';     
   signal RamYUVaddrB         : unsigned(6 downto 0) := (others => '0');
   signal RamYUVdataB         : std_logic_vector(7 downto 0); 

   signal scaleT1_address_b   : std_logic_vector(5 downto 0) := (others => '0');
   signal scaleT1_data_b      : std_logic_vector(15 downto 0);   
   
   signal scaleT2_address_b   : std_logic_vector(5 downto 0) := (others => '0');
   signal scaleT2_data_b      : std_logic_vector(15 downto 0);
  
   -- RL decoding
   signal decodeDone          : std_logic := '0';
   signal blockDoneNext       : std_logic := '0';
   signal blockDoneDecode     : std_logic := '0';
   signal fifoSecondAvail     : std_logic := '0';
   signal RLdata              : std_logic_vector(15 downto 0);
   signal currentBlock        : unsigned(2 downto 0);
   signal currentCoeff        : unsigned(6 downto 0) := (others => '0');
   signal currentQScale       : unsigned(5 downto 0);
   signal currentData         : signed(9 downto 0);
   signal calcNextRL          : std_logic := '0';
   signal currentBlockDone    : std_logic := '0';
      
   signal calcNowRL           : std_logic := '0';
   signal calcBlockDone       : std_logic := '0';
   signal calcQScale          : unsigned(5 downto 0);
   signal calcData            : signed(9 downto 0);
   signal calcBlock           : unsigned(2 downto 0);
   signal calcCoeff           : unsigned(5 downto 0);
   signal calcZigzag          : integer range 0 to 63;
   
   type tzigzag is array(0 to 63) of integer range 0 to 63;
   constant zigzag : tzigzag := 
   (0,  1,  8,  16, 9,  2,  3,  10, 17, 24, 32, 25, 18, 11, 4,  5,
	12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6,  7,  14, 21, 28,
	35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
	58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63);
  
   signal FifoRL_Din          : std_logic_vector(21 downto 0) := (others => '0');
   signal FifoRL_Wr           : std_logic; 
   signal FifoRL_Dout         : std_logic_vector(21 downto 0);
   signal FifoRL_Rd           : std_logic;
   signal FifoRL_Empty        : std_logic;
   
   -- IDCT
   type tidctState is
   (
      IDCT_IDLE,
      IDCT_STAGE1,
      IDCT_STAGE2,
      IDCT_WAIT
   );
   signal idctState           : tidctState := IDCT_IDLE;
   
   signal idct_wait_cnt       : integer range 0 to 2171;
   
   -- synthesis translate_off
   type tidct_input is array(0 to 63) of signed(11 downto 0);
   signal idct_input          : tidct_input;
   -- synthesis translate_on
   
   signal IDCTi_address_a     : std_logic_vector(5 downto 0) := (others => '0');
   signal IDCTi_data_a        : std_logic_vector(11 downto 0) := (others => '0');
   signal IDCTi_wren_a        : std_logic := '0';
   signal IDCTi_wren_b        : std_logic := '0';
   signal IDCTi_address_b     : std_logic_vector(5 downto 0) := (others => '0');
   signal IDCTi_dataO_a       : std_logic_vector(11 downto 0) := (others => '0');
   signal IDCTi_dataO_b       : std_logic_vector(11 downto 0) := (others => '0');
                              
   signal scaleT_address_a    : std_logic_vector(5 downto 0) := (others => '0');
   signal scaleT_address_Wr   : std_logic_vector(5 downto 0) := (others => '0');
   signal scaleT_data_a       : std_logic_vector(15 downto 0) := (others => '0');
   signal scaleT_data_aFirst  : std_logic_vector(15 downto 0) := (others => '0');
   signal scaleT_data_aNext   : std_logic_vector(15 downto 0) := (others => '0');
   signal scaleT_wren_a       : std_logic := '0';
      
   signal idct_block          : integer range 0 to 5;
   signal idct_x              : integer range 0 to 7;
   signal idct_y              : integer range 0 to 7;
   signal idct_u              : integer range 0 to 7;
   signal idct_u1             : integer range 0 to 7;
   signal idct_sum            : signed(50 downto 0);
   signal idct_done           : std_logic := '0';
   
   --type tidct_temp is array(0 to 63) of signed(29 downto 0);
   --signal idct_temp           : tidct_temp;
   
   signal IDCTt_address_a     : std_logic_vector(5 downto 0) := (others => '0');
   signal IDCTt_data_a        : std_logic_vector(30 downto 0) := (others => '0');
   signal IDCTt_wren_a        : std_logic := '0';
   signal IDCTt_wren_b        : std_logic := '0';
   signal IDCTt_address_b1    : std_logic_vector(5 downto 0) := (others => '0');
   signal IDCTt_address_b2    : std_logic_vector(5 downto 0) := (others => '0');
   signal IDCTt_dataO_b1      : std_logic_vector(30 downto 0) := (others => '0');
   signal IDCTt_dataO_b2      : std_logic_vector(30 downto 0) := (others => '0');
  
   signal idct_calc0_ena      : std_logic := '0';
   signal idct_calc0_stage    : std_logic := '0';
   signal idct_calc0_target1  : integer range 0 to 63;
   signal idct_calc0_target2  : integer range 0 to 511;
   signal idct_calc0_first    : std_logic := '0';
   signal idct_calc0_last     : std_logic := '0';
   signal idct_calc0_mul11    : signed(30 downto 0);
   signal idct_calc0_mul12    : signed(15 downto 0);
   signal idct_calc0_mul21    : signed(30 downto 0);
   signal idct_calc0_mul22    : signed(15 downto 0);
   signal idct_calc1_ena      : std_logic := '0';
   signal idct_calc1_stage    : std_logic := '0';
   signal idct_calc1_target1  : integer range 0 to 63;
   signal idct_calc1_target2  : integer range 0 to 511;
   signal idct_calc1_first    : std_logic := '0';
   signal idct_calc1_last     : std_logic := '0';
   signal idct_calc1_swap     : std_logic := '0';
   signal idct_calc1_mul1     : signed(46 downto 0); 
   signal idct_calc1_mul2     : signed(46 downto 0); 
   signal idct_calc2_ena      : std_logic := '0';
   signal idct_calc2_stage    : std_logic := '0';
   signal idct_calc2_target1  : integer range 0 to 63;
   signal idct_calc2_target2  : integer range 0 to 511;
   signal idct_calc2_last     : std_logic := '0';
   signal idct_calc2_swap     : std_logic := '0';
  
   signal idct_write          : std_logic := '0';
   signal idct_buffer         : std_logic := '0';
   signal idct_target         : unsigned(9 downto 0) := (others => '0');
   signal idct_resultClip     : signed(7 downto 0) := (others => '0');
  
   -- color conversion
   type tcolorState is
   (
      COLOR_IDLE,
      COLOR_SELECTBLOCK,
      COLOR_READ0,
      COLOR_READ1,
      COLOR_READ2,
      COLOR_READ3,
      COLOR_CALC,
      COLOR_BW_READ,
      COLOR_BW_WRITE
   );
   signal colorState          : tcolorState := COLOR_IDLE;
      
   signal color_buffer        : std_logic := '0';
   signal color_block         : integer range 2 to 5;
   signal color_x             : integer range 0 to 7;
   signal color_y             : integer range 0 to 7;
   signal color_xBase         : integer range 0 to 8;
   signal color_yBase         : integer range 0 to 8;
      
   signal idct_readAddr       : unsigned(9 downto 0) := (others => '0');
   signal idct_readData       : std_logic_vector(7 downto 0) := (others => '0');
   signal color_read_R        : signed(7 downto 0) := (others => '0');
   signal color_read_B        : signed(7 downto 0) := (others => '0');
   signal color_read_Y        : signed(7 downto 0) := (others => '0');
      
   signal color_conv_R        : signed(16 downto 0) := (others => '0');
   signal color_conv_G        : signed(16 downto 0) := (others => '0');
   signal color_conv_B        : signed(16 downto 0) := (others => '0');
      
   signal color_bwAddr        : integer range 0 to 63;
   signal color_addr          : unsigned(7 downto 0) := (others => '0');
   signal color_result        : std_logic_vector(23 downto 0);
   signal color_write         : std_logic := '0';
   signal color_done          : std_logic := '0';
   
   -- output   
   signal FifoOut_Din         : std_logic_vector(31 downto 0) := (others => '0');
   signal FifoOut_Wr          : std_logic; 
   signal FifoOut_NearFull    : std_logic; 
   signal FifoOut_Dout        : std_logic_vector(31 downto 0);
   signal FifoOut_Rd          : std_logic;
   signal FifoOut_Empty       : std_logic;
      
   type toutputState is 
   (  
      OUTPUT_IDLE,   
      OUTPUT_READ 
   ); 
   signal outputState         : toutputState := OUTPUT_IDLE;
                              
   signal color_readAddr      : unsigned(7 downto 0) := (others => '0');
   signal color_readData      : std_logic_vector(23 downto 0) := (others => '0');
   signal color_readData_1    : std_logic_vector(23 downto 0) := (others => '0');
   signal color_readNext      : std_logic := '0';
   signal color_readValid     : std_logic := '0';
  
   type tcolormapState is
   (
      COLORMAP_IDLE,
      COLORMAP_4_1,
      COLORMAP_4_2,
      COLORMAP_4_3,
      COLORMAP_4_4,
      COLORMAP_4_5,
      COLORMAP_4_6,
      COLORMAP_4_7,
      COLORMAP_4_8,
      COLORMAP_8_1,
      COLORMAP_8_2,
      COLORMAP_8_3,
      COLORMAP_8_4,
      COLORMAP_16_1,
      COLORMAP_16_2,
      COLORMAP_24_1,
      COLORMAP_24_2,
      COLORMAP_24_3,
      COLORMAP_24_4
   );
   signal colormapState       : tcolormapState := COLORMAP_IDLE;
      
   signal fifoOut_done        : std_logic := '0';
      
   -- readback + registers 
   signal MDECSTAT            : std_logic_vector(31 downto 0);
   signal MDECCONTROL         : std_logic_vector( 2 downto 0);
   
   -- savestates
   type t_ssarray is array(0 to 1) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray  := (others => (others => '0')); 
   signal ss_out : t_ssarray  := (others => (others => '0'));
                              
   signal RamSSaddrA          : unsigned(5 downto 0) := (others => '0');
   signal RamSSdataA          : std_logic_vector(31 downto 0) := (others => '0');
   signal RamSSwrite          : std_logic := '0';     
   signal RamSSaddrB          : unsigned(5 downto 0) := (others => '0');
   signal RamSSdataB          : std_logic_vector(31 downto 0); 
                              
   signal ram_SSrden          : std_logic;
   
   signal ss_timeout          : unsigned(23 downto 0);

   function colorChannel(y : signed(7 downto 0); chroma : signed(16 downto 0); mode15 : std_logic; unsignedOut : std_logic) return std_logic_vector is
      variable sum  : signed(17 downto 0);
      variable w17  : signed(17 downto 0);
      variable res  : signed(17 downto 0);
      variable outv : std_logic_vector(7 downto 0);
   begin
      sum := shift_left(resize(y, 18), 8) + resize(chroma, 18);
      w17 := resize(sum(16 downto 0), 18);
      if (mode15 = '1') then
         res := shift_right(w17 + 1024, 11);
         if (res < -16) then res := to_signed(-16, 18); elsif (res > 15) then res := to_signed(15, 18); end if;
         outv := std_logic_vector(res(4 downto 0)) & "000";
         if (unsignedOut = '1') then outv(7) := not outv(7); end if;
      else
         res := shift_right(w17 + 128, 8);
         if (res < -128) then res := to_signed(-128, 18); elsif (res > 127) then res := to_signed(127, 18); end if;
         outv := std_logic_vector(res(7 downto 0));
         if (unsignedOut = '1') then outv(7) := not outv(7); end if;
      end if;
      return outv;
   end function;

   function roundUp8to5(data : std_logic_vector(7 downto 0)) return std_logic_vector is
   begin
      if (data(7 downto 3) /= "11111" and data(2) = '1') then
         return std_logic_vector(unsigned(data(7 downto 3)) + 1);
      else
         return data(7 downto 3);
      end if;
   end function;

begin 

   FifoIn_Din <= dma_writedata when (dma_write = '1') else bus_dataWrite;
   FifoIn_Wr  <= ce when ((bus_write = '1' and bus_addr = x"0") or dma_write = '1') else '0';

   ififoIn: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 512,
      DATAWIDTH        => 32,
      NEARFULLDISTANCE => 223
   )
   port map
   ( 
      clk      => clk1x,     
      reset    => reset_calc,   
                
      Din      => FifoIn_Din,     
      Wr       => FifoIn_Wr,      
      Full     => open,    
      NearFull => FifoIn_NearFull,

      Dout     => FifoIn_Dout,    
      Rd       => FifoIn_Rd,      
      Empty    => FifoIn_Empty   
   );
   
   FifoIn_Rd  <= '0' when (blockDoneNext = '1') else
                 '1' when (FifoIn_Empty = '0' and receiveState = RECEIVE_IDLE and FifoIn_Dout(31 downto 29) = "001") else
                 '1' when (FifoIn_Empty = '0' and receiveState = RECEIVE_IDLE and FifoIn_Dout(31 downto 29) = "010") else
                 '1' when (FifoIn_Empty = '0' and receiveState = RECEIVE_IDLE and FifoIn_Dout(31 downto 29) = "011") else
                 '1' when (FifoIn_Empty = '0' and receiveState = RECEIVE_IDLE and wordsRemain > 0) else
                 '1' when (FifoIn_Empty = '0' and receiveState = RECEIVE_YUV) else
                 '1' when (FifoIn_Empty = '0' and receiveState = RECEIVE_SCALE) else
                 '1' when (FifoIn_Empty = '0' and receiveState = RECEIVE_BLOCK and decodeDone = '0' and fifoSecondAvail = '1') else
                 '0';
   
   RLdata <= FifoIn_Dout(15 downto 0) when fifoSecondAvail = '0' else FifoIn_Dout(31 downto 16);
   
   
   ss_out(0)               <= MDECSTAT; 
   ss_out(1)(31 downto 29) <= MDECCONTROL;
   
   -- receive FIFO handling
   process (clk1x)
      variable nextCoeff : unsigned(6 downto 0);
      variable coeff63   : std_logic;
   begin
      if rising_edge(clk1x) then
      
         reset_receive     <= '0';
         reset_calc        <= '0';
      
         RamYUVwrite       <= '0';
         RamSSwrite        <= '0';
         calcNextRL        <= '0';
         currentBlockDone  <= '0';
         scaleT_wren_a     <= '0';
      
         if (reset = '1') then
         
            reset_calc      <= '1';
            blockDoneNext   <= '0';
         
            receiveState    <= RECEIVE_IDLE;
            fifoSecondAvail <= '0';
            currentBlock    <= (others => '0');
            currentCoeff    <= to_unsigned(64, 7);
            
            wordsRemain     <= (others => '0');
            
            MDECCONTROL     <= ss_in(1)(31 downto 29);
            rec_bit15       <= ss_in(0)(23);          
            rec_signed      <= ss_in(0)(24);          
            rec_depth       <= ss_in(0)(26 downto 25);
            
         elsif (SS_wren = '1') then
         
            if (SS_Adr >= 16 and SS_Adr < 48) then
               RamYUVaddrA <= resize(SS_Adr - 16, 5);
               RamYUVdataA <= SS_DataWrite;
               RamYUVwrite <= '1';
               RamSSaddrA  <= '0' & resize(SS_Adr - 16, 5);
               RamSSdataA  <= SS_DataWrite;
               RamSSwrite  <= '1';
            end if;
            
            if (SS_Adr >= 64 and SS_Adr < 96) then
               scaleT_address_Wr  <= std_logic_vector(SS_Adr(4 downto 0)) & '0';
               scaleT_data_aFirst <= SS_DataWrite(15 downto  0);
               scaleT_data_aNext  <= SS_DataWrite(31 downto 16);
               scaleT_wren_a      <= '1';
               RamSSaddrA  <= '1' & resize(SS_Adr - 64, 5);
               RamSSdataA  <= SS_DataWrite;
               RamSSwrite  <= '1';
            end if;
         
         elsif (ce = '1') then
         
            if (bus_write = '1' and bus_addr = x"4") then
               MDECCONTROL <= bus_dataWrite(31 downto 29);
               if (bus_dataWrite(31) = '1') then
                  reset_receive <= '1';
                  reset_calc    <= '1';
               end if;
            end if;
            
            if (blockDoneNext = '1') then
               blockDoneNext    <= '0';
               currentBlockDone <= '1';
               if (blockDoneDecode = '1') then
                  decodeDone <= '1';
               end if;
               currentCoeff <= to_unsigned(64, 7);
               if (receiveState = RECEIVE_BLOCK) then
                  currentBlock <= currentBlock + 1;
               else
                  currentBlock <= (others => '0');
               end if;
            else
            
            case (receiveState) is
            
               when RECEIVE_IDLE =>
                  if (FifoIn_Empty = '0') then
                     rec_depth  <= FifoIn_Dout(28 downto 27);
                     rec_signed <= FifoIn_Dout(26);
                     rec_bit15  <= FifoIn_Dout(25);
                     
                     case (FifoIn_Dout(31 downto 29)) is
                        when "001" => -- decode macroblock
                           receiveState <= RECEIVE_BLOCK;
                           wordsRemain  <= unsigned(FifoIn_Dout(15 downto 0));
                           decodeDone   <= '0';
                        
                        when "010" => -- Set Quant Table
                           receiveState <= RECEIVE_YUV;
                           isColor      <= FifoIn_Dout(0);
                           recCount     <= (others => '0');
                           if (FifoIn_Dout(0) = '1') then
                              wordsRemain  <= to_unsigned(32, 16);
                           else
                              wordsRemain  <= to_unsigned(16, 16);
                           end if;
                        
                        when "011" => -- Set Scale Table
                           receiveState <= RECEIVE_SCALE;
                           recCount     <= (others => '0');
                           wordsRemain  <= to_unsigned(32, 16);
                           
                        when others =>
                           if (wordsRemain > 0) then
                              wordsRemain <= wordsRemain - 1;
                           end if;
                        
                     end case;
                  end if;
            
               when RECEIVE_YUV =>
                  if (FifoIn_Empty = '0') then
                     RamYUVaddrA <= recCount;
                     RamYUVdataA <= FifoIn_Dout;
                     RamYUVwrite <= '1';                     
                     RamSSaddrA  <= '0' & recCount;
                     RamSSdataA  <= FifoIn_Dout;
                     RamSSwrite  <= '1';
                     recCount    <= recCount + 1;
                     if ((isColor = '1' and recCount = 31) or (isColor = '0' and recCount = 15)) then
                        receiveState <= RECEIVE_IDLE;
                        wordsRemain  <= wordsRemain - 16; -- todo : this is very likely wrong, but emulators do it that way. need to verify
                     end if;
                  end if;
                  
               when RECEIVE_SCALE =>
                  if (FifoIn_Empty = '0') then
                     scaleT_address_Wr  <= std_logic_vector(recCount) & '0';
                     scaleT_data_aFirst <= FifoIn_Dout(15 downto  0);
                     scaleT_data_aNext  <= FifoIn_Dout(31 downto 16);
                     scaleT_wren_a      <= '1';
                     RamSSaddrA  <= '1' & recCount;
                     RamSSdataA  <= FifoIn_Dout;
                     RamSSwrite  <= '1';
                     recCount    <= recCount + 1;
                     if (recCount = 31) then
                        receiveState <= RECEIVE_IDLE;
                        wordsRemain  <= wordsRemain - 16; -- todo : this is very likely wrong, but emulators do it that way. need to verify
                     end if;
                  end if; 
                  
               when RECEIVE_BLOCK =>
                  if (decodeDone = '1' and fifoOut_done = '1') then
                     decodeDone   <= '0';
                     currentBlock <= (others => '0');
                  elsif (FifoIn_Empty = '0' and decodeDone = '0') then
                  
                     currentData <= signed(RLdata(9 downto 0));
                     coeff63     := '0';
                     if (currentCoeff = 64) then
                        if (RLdata /= x"FE00") then
                           currentCoeff  <= (others => '0');
                           currentQScale <= unsigned(RLdata(15 downto 10));
                           calcNextRL    <= '1';
                        end if;
                     else
                        nextCoeff    := currentCoeff + unsigned(RLdata(15 downto 10)) + 1;
                        currentCoeff <= nextCoeff;
                        if (nextCoeff = 63) then
                           coeff63       := '1';
                           calcNextRL    <= '1';
                           blockDoneNext <= '1';
                           if ((rec_depth(1) = '1' and currentBlock = 5) or rec_depth(1) = '0') then
                              blockDoneDecode <= '1';
                           else
                              blockDoneDecode <= '0';
                           end if;
                        elsif (nextCoeff >= 63) then
                           currentBlock <= currentBlock + 1;
                           currentCoeff <= to_unsigned(64, 7);
                           if ((rec_depth(1) = '1' and currentBlock = 5) or rec_depth(1) = '0') then
                              decodeDone <= '1';
                           end if;
                           currentBlockDone <= '1';
                        else
                           calcNextRL    <= '1';
                        end if;
                     end if;
                     
                     if (fifoSecondAvail = '0') then
                        fifoSecondAvail <= '1';
                     else
                        fifoSecondAvail <= '0';
                        wordsRemain <= wordsRemain - 1;
                        if (wordsRemain = 1) then -- only if at last block?
                           receiveState <= RECEIVE_IDLE;
                           if (coeff63 = '0') then
                              currentCoeff <= to_unsigned(64, 7);
                              currentBlock <= (others => '0');
                           end if;
                        end if;
                     end if;
                     
                  end if;
            
            end case;
            
            end if;
         
         end if;
         
         if (reset_receive = '1') then
            blockDoneNext   <= '0';
            receiveState    <= RECEIVE_IDLE;
            fifoSecondAvail <= '0';
            currentBlock    <= (others => '0');
            currentCoeff    <= to_unsigned(64, 7);
            wordsRemain     <= (others => '0');
            rec_bit15       <= '0';
            rec_signed      <= '0';
            rec_depth       <= "00";
         end if;
         
      end if;
   end process;
   
   iramYUV: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 5,
      data_width_a  => 32,
      addr_width_b  => 7,
      data_width_b  => 8
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => std_logic_vector(RamYUVaddrA),
      data_a      => RamYUVdataA,
      wren_a      => (RamYUVwrite),
      
      clock_b     => clk1x,
      address_b   => std_logic_vector(RamYUVaddrB),
      data_b      => x"00",
      wren_b      => '0',
      q_b         => RamYUVdataB
   );
   
   RamYUVaddrB <= '0' & currentCoeff(5 downto 0) when (currentBlock >= 2) else '1' & currentCoeff(5 downto 0);
   
   iramSS: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 6,
      data_width_a  => 32,
      addr_width_b  => 6,
      data_width_b  => 32
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => std_logic_vector(RamSSaddrA),
      data_a      => RamSSdataA,
      wren_a      => (RamSSwrite),
      
      clock_b     => clk1x,
      address_b   => std_logic_vector(RamSSaddrB),
      data_b      => x"00000000",
      wren_b      => '0',
      q_b         => RamSSdataB
   );
   
   RamSSaddrB <= (SS_Adr(5 downto 0) - 16) when SS_Adr < 64 else '1' & SS_Adr(4 downto 0);
   
   -- RL decoding
   process (clk1x)
      variable calcvalue : integer;
      variable calcmag   : integer range 0 to 16777215;
   begin
      if rising_edge(clk1x) then
         
         -- get values from block ram
         calcBlockDone <= currentBlockDone;
         calcNowRL     <= calcNextRL;
         calcQScale    <= currentQScale;
         calcData      <= currentData; 
         calcBlock     <= currentBlock; 
         calcCoeff     <= currentCoeff(5 downto 0);
         calcZigzag    <= zigzag(to_integer(currentCoeff(5 downto 0)));
         
         -- generate output value
         FifoRL_Wr <= '0';
         if (calcBlockDone = '1') then
            FifoRL_Wr      <= '1';
            FifoRL_Din(21) <= '1';
         elsif (calcNowRL = '1') then
            FifoRL_Wr <= '1';
            
            calcvalue := to_integer(calcData);
            if (calcQScale = 0) then
               calcvalue := calcvalue * 4;
            else
               calcmag := abs(calcvalue) * to_integer(unsigned(RamYUVdataB));
               if (calcCoeff > 0) then
                  if (calcvalue < 0) then
                     calcmag := (calcmag * to_integer(calcQScale) + 7) / 8;
                  else
                     calcmag := (calcmag * to_integer(calcQScale) + 4) / 8;
                  end if;
               end if;
               if (calcmag = 0) then
                  calcvalue := 0;
               elsif (calcmag >= 1024) then
                  if (calcvalue < 0) then calcvalue := -2047; else calcvalue := 2047; end if;
               else
                  if (calcvalue < 0) then calcvalue := 1 - 2 * calcmag; else calcvalue := 2 * calcmag - 1; end if;
               end if;
            end if;
        
            FifoRL_Din(11 downto 0) <= std_logic_vector(to_signed(calcvalue, 12));
            
            FifoRL_Din(14 downto 12) <= std_logic_vector(calcBlock);
            if (calcQScale = 0) then
               FifoRL_Din(20 downto 15) <= std_logic_vector(calcCoeff);
            else
               FifoRL_Din(20 downto 15) <= std_logic_vector(to_unsigned(calcZigzag, 6));
            end if;
            
            FifoRL_Din(21) <= '0';
                    
         end if;
         
         if (reset_calc = '1') then
            FifoRL_Wr <= '0';
         end if;
         
      end if;
   end process;
   
   ififoRL: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 512,
      DATAWIDTH        => 22,
      NEARFULLDISTANCE => 256
   )
   port map
   ( 
      clk      => clk2x,     
      reset    => reset_calc,   
                
      Din      => FifoRL_Din,     
      Wr       => (FifoRL_Wr and clk2xIndex),      
      Full     => open,    
      NearFull => open,

      Dout     => FifoRL_Dout,    
      Rd       => FifoRL_Rd,      
      Empty    => FifoRL_Empty   
   );
   
   FifoRL_Rd <= '1' when (idctState = IDCT_IDLE and FifoRL_Empty = '0' and FifoOut_Empty = '1') else '0';

   -- IDCT
   IDCTi_address_a <= std_logic_vector(to_unsigned(idct_u  * 8 + idct_x, 6)) when (idctState = IDCT_STAGE1) else FifoRL_Dout(20 downto 15);
   IDCTi_address_b <= std_logic_vector(to_unsigned(idct_u1 * 8 + idct_x, 6)) when (idctState = IDCT_STAGE1) else std_logic_vector(to_unsigned(idct_x * 8 + idct_y, 6));
   
   IDCTi_wren_a    <= ce when (idctState = IDCT_IDLE and FifoRL_Empty = '0' and FifoOut_Empty = '1' and FifoRL_Dout(21) = '0') else '0';
   IDCTi_wren_b    <= ce when (idctState = IDCT_STAGE2) else '0';
   
   IDCTi_data_a    <= FifoRL_Dout(11 downto 0);
   
   iIDCTiTable: entity work.dpram
   generic map ( addr_width => 6, data_width => 12)
   port map
   (
      clock_a     => clk2x,
      address_a   => IDCTi_address_a,
      data_a      => IDCTi_data_a,
      wren_a      => IDCTi_wren_a,
      q_a         => IDCTi_dataO_a,
      
      clock_b     => clk2x,
      address_b   => IDCTi_address_b,
      data_b      => (11 downto 0 => '0'),
      wren_b      => IDCTi_wren_b,
      q_b         => IDCTi_dataO_b
   );
   
-------------------------
   
   scaleT_address_a <= scaleT_address_WR(5 downto 1) & '1' when (clk2xIndex = '1') else scaleT_address_WR(5 downto 1) & '0';
   scaleT_data_a    <= scaleT_data_aNext                   when (clk2xIndex = '1') else scaleT_data_aFirst;
   
   iscaleTable1: entity work.dpram
   generic map ( addr_width => 6, data_width => 16)
   port map
   (
      clock_a     => clk2x,
      address_a   => scaleT_address_a,
      data_a      => scaleT_data_a,
      wren_a      => scaleT_wren_a,
      
      clock_b     => clk2x,
      address_b   => scaleT1_address_b,
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => scaleT1_data_b
   );
   
   iscaleTable2: entity work.dpram
   generic map ( addr_width => 6, data_width => 16)
   port map
   (
      clock_a     => clk2x,
      address_a   => scaleT_address_a,
      data_a      => scaleT_data_a,
      wren_a      => scaleT_wren_a,
      
      clock_b     => clk2x,
      address_b   => scaleT2_address_b,
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => scaleT2_data_b
   );
   
   scaleT1_address_b <= std_logic_vector(to_unsigned(idct_u  * 8 + idct_y, 6)) when (idctState = IDCT_STAGE1) else std_logic_vector(to_unsigned(idct_u  * 8 + idct_x, 6));
   scaleT2_address_b <= std_logic_vector(to_unsigned(idct_u1 * 8 + idct_y, 6)) when (idctState = IDCT_STAGE1) else std_logic_vector(to_unsigned(idct_u1 * 8 + idct_x, 6));
   idct_calc0_mul12  <= shift_right(signed(scaleT1_data_b), 3) when (idct_calc0_stage = '0') else shift_right(signed(scaleT1_data_b), 4);
   idct_calc0_mul22  <= shift_right(signed(scaleT2_data_b), 3) when (idct_calc0_stage = '0') else shift_right(signed(scaleT2_data_b), 4);
   
-------------------------
   
   IDCTt_address_a <= std_logic_vector(to_unsigned(idct_calc2_target1, 6));
   IDCTt_wren_a    <= ce when (idct_calc2_ena = '1' and idct_calc2_last = '1' and idct_calc2_stage = '0') else '0';
   IDCTt_data_a    <= std_logic_vector(resize(signed(idct_sum(16 downto 4)), 31));
   
   iIDCTtTable1: entity work.dpram
   generic map ( addr_width => 6, data_width => 31)
   port map
   (
      clock_a     => clk2x,
      address_a   => IDCTt_address_a,
      data_a      => IDCTt_data_a,
      wren_a      => IDCTt_wren_a,
      
      clock_b     => clk2x,
      address_b   => IDCTt_address_b1,
      data_b      => (30 downto 0 => '0'),
      wren_b      => '0',
      q_b         => IDCTt_dataO_b1
   );
   
   iIDCTtTable2: entity work.dpram
   generic map ( addr_width => 6, data_width => 31)
   port map
   (
      clock_a     => clk2x,
      address_a   => IDCTt_address_a,
      data_a      => IDCTt_data_a,
      wren_a      => IDCTt_wren_a,
      
      clock_b     => clk2x,
      address_b   => IDCTt_address_b2,
      data_b      => (30 downto 0 => '0'),
      wren_b      => '0',
      q_b         => IDCTt_dataO_b2
   );
   
   IDCTt_address_b1 <= std_logic_vector(to_unsigned(idct_u  + idct_y * 8, 6));
   IDCTt_address_b2 <= std_logic_vector(to_unsigned(idct_u1 + idct_y * 8, 6));
   
-------------------------

   idct_calc0_mul11 <= resize(signed(IDCTi_dataO_a), idct_calc0_mul11'length) when (idct_calc0_stage = '0') else signed(IDCTt_dataO_b1);
   idct_calc0_mul21 <= resize(signed(IDCTi_dataO_b), idct_calc0_mul11'length) when (idct_calc0_stage = '0') else signed(IDCTt_dataO_b2);
   
   process (clk2x)
      variable shifted : signed(17 downto 0);
   begin
      if rising_edge(clk2x) then
      
         idct_write     <= '0';
         idct_done      <= '0';
         idct_calc0_ena <= '0';
      
         if (reset_calc = '1') then
         
            idctState    <= IDCT_IDLE;
         
         elsif (ce = '1') then
         
            case (idctState) is
            
               when IDCT_IDLE =>
                  if (rec_depth = "11") then -- 15bit mode
                     idct_wait_cnt <= 2171;
                  else
                     idct_wait_cnt <= 10;
                  end if;
                  
                  if (FifoRL_Empty = '0' and FifoOut_Empty = '1') then
                     if (FifoRL_Dout(21) = '1') then
                        idctState   <= IDCT_STAGE1;
                        idct_x      <= 0;
                        idct_y      <= 0;
                        idct_u      <= 0;
                        idct_u1     <= 1;
                     else
                        if (unsigned(FifoRL_Dout(20 downto 15)) = 0) then
                           idct_block <= to_integer(unsigned(FifoRL_Dout(14 downto 12)));
                        end if;
                        -- synthesis translate_off
                        idct_input(to_integer(unsigned(FifoRL_Dout(20 downto 15)))) <= signed(FifoRL_Dout(11 downto 0));
                        -- synthesis translate_on
                     end if;
                  end if;
               
               when IDCT_STAGE1 =>
                  idct_calc0_ena     <= '1';
                  idct_calc0_stage   <= '0';
                  --idct_calc0_mul11   <= resize(idct_input(idct_u * 8 + idct_x), idct_calc0_mul11'length);
                  --idct_calc0_mul12   <= scaleTable(idct_u * 8 + idct_y);
                  --idct_calc0_mul21   <= resize(idct_input(idct_u1 * 8 + idct_x), idct_calc0_mul11'length);
                  --idct_calc0_mul22   <= scaleTable(idct_u1 * 8 + idct_y);
                  idct_calc0_target1 <= idct_x + idct_y * 8;
                  if (idct_u = 0) then idct_calc0_first <= '1'; else idct_calc0_first <= '0'; end if;
                  if (idct_u = 6) then idct_calc0_last  <= '1'; else idct_calc0_last  <= '0'; end if;
                  
                  if (idct_u < 6) then 
                     idct_u  <= idct_u  + 2; 
                     idct_u1 <= idct_u1 + 2;
                  else 
                     idct_u  <= 0; 
                     idct_u1 <= 1;
                     if (idct_y < 7) then 
                        idct_y <= idct_y + 1; 
                     else 
                        idct_y <= 0; 
                        if (idct_x < 7) then 
                           idct_x <= idct_x + 1; 
                        else
                           idct_x <= 0; 
                           idctState <= IDCT_STAGE2;
                        end if;
                     end if;
                  end if;
                  
               when IDCT_STAGE2 =>
                  idct_calc0_ena     <= '1';
                  idct_calc0_stage   <= '1';
                  --idct_calc0_mul11   <= idct_temp(idct_u + idct_y * 8);
                  --idct_calc0_mul12   <= scaleTable(idct_u * 8 + idct_x);
                  --idct_calc0_mul21   <= idct_temp(idct_u1 + idct_y * 8);
                  --idct_calc0_mul22   <= scaleTable(idct_u1 * 8 + idct_x);
                  idct_calc0_target2 <= idct_x + idct_y * 8 + idct_block * 64;
                  if (idct_u = 0) then idct_calc0_first <= '1'; else idct_calc0_first <= '0'; end if;
                  if (idct_u = 6) then idct_calc0_last  <= '1'; else idct_calc0_last  <= '0'; end if;
               
                  if (idct_u < 6) then 
                     idct_u  <= idct_u  + 2; 
                     idct_u1 <= idct_u1 + 2;
                  else 
                     idct_u  <= 0; 
                     idct_u1 <= 1;
                     if (idct_y < 7) then 
                        idct_y <= idct_y + 1; 
                     else 
                        idct_y <= 0; 
                        if (idct_x < 7) then 
                           idct_x <= idct_x + 1; 
                        else
                           idct_x <= 0; 
                           idctState <= IDCT_IDLE;
                           if ((rec_depth(1) = '1' and idct_block = 5) or rec_depth(1) = '0') then
                              idctState <= IDCT_WAIT;
                           end if;
                        end if;
                     end if;
                  end if;
                  
                  -- synthesis translate_off
                  idct_input(idct_x * 8 + idct_y) <= (others => '0'); -- clear table here for next usage
                  -- synthesis translate_on
               
               when IDCT_WAIT =>
                  if (idct_wait_cnt > 0) then
                     idct_wait_cnt <= idct_wait_cnt - 1;
                  else
                     idctState <= IDCT_IDLE;
                     idct_done <= '1';
                  end if;
                  
               
            end case;
            
            -- calculation pipeline -> pipeline delay can be ignored as following stages don't read last written value early
            -- stage 0 multiply
            idct_calc1_ena     <= idct_calc0_ena;
            idct_calc1_stage   <= idct_calc0_stage;
            idct_calc1_target1 <= idct_calc0_target1;
            idct_calc1_target2 <= idct_calc0_target2;
            idct_calc1_first   <= idct_calc0_first;
            idct_calc1_last    <= idct_calc0_last;
            idct_calc1_mul1    <= idct_calc0_mul11 * idct_calc0_mul12;
            idct_calc1_mul2    <= idct_calc0_mul21 * idct_calc0_mul22;
            idct_calc1_swap    <= idct_done;
            
            -- stage 1 add sum
            idct_calc2_ena     <= idct_calc1_ena;
            idct_calc2_stage   <= idct_calc1_stage;
            idct_calc2_last    <= idct_calc1_last;
            idct_calc2_target1 <= idct_calc1_target1;
            idct_calc2_target2 <= idct_calc1_target2;
            idct_calc2_swap    <= idct_calc1_swap;
            if (idct_calc1_ena = '1') then
               if (idct_calc1_first = '1') then
                  idct_sum <= to_signed(0, idct_sum'length) + shift_right(idct_calc1_mul1, 7) + shift_right(idct_calc1_mul2, 7);
               else
                  idct_sum <= idct_sum + shift_right(idct_calc1_mul1, 7) + shift_right(idct_calc1_mul2, 7);
               end if;
            end if;
            
            -- stage 2 write
            if (idct_calc2_swap = '1') then
               idct_buffer <= not idct_buffer;
            end if;
            
            if (idct_calc2_ena = '1' and idct_calc2_last = '1') then
               if (idct_calc2_stage = '0') then
                  --idct_temp(idct_calc2_target1) <= resize(idct_sum, 30);
               else
                  idct_target <= idct_buffer & to_unsigned(idct_calc2_target2, 9);
                  idct_write  <= '1';
                  shifted := shift_right(resize(signed(idct_sum(16 downto 0)), 18) + 128, 8);
                  if (shifted < -128) then
                     idct_resultClip <= to_signed(-128, 8);
                  elsif (shifted > 127) then
                     idct_resultClip <= to_signed(127, 8);
                  else
                     idct_resultClip <= resize(shifted, 8);
                  end if;
                  
               end if;
            end if;
            
         end if;
         
      end if;
   end process;
   
   iramIDCTResult: entity work.dpram
   generic map 
   ( 
      addr_width => 10, 
      data_width => 8
   )
   port map
   (
      clock_a     => clk2x,
      clken_a     => '1',
      address_a   => std_logic_vector(idct_target),
      data_a      => std_logic_vector(idct_resultClip),
      wren_a      => idct_write,
      
      clock_b     => clk2x,
      address_b   => std_logic_vector(idct_readAddr),
      data_b      => x"00",
      wren_b      => '0',
      q_b         => idct_readData
   );
   
   idct_readAddr <= color_buffer & to_unsigned(color_bwAddr, 9) when (colorState = COLOR_BW_READ) else 
                    color_buffer & "000" & to_unsigned((color_x + color_xBase) / 2 + ((color_y + color_yBase) / 2) * 8, 6) when (colorState = COLOR_READ0) else 
                    color_buffer & "001" & to_unsigned((color_x + color_xBase) / 2 + ((color_y + color_yBase) / 2) * 8, 6) when (colorState = COLOR_READ1) else 
                    color_buffer & to_unsigned(color_block, 3) & to_unsigned(color_x + color_y * 8, 6);
   
   -- Color
   process (clk2x)
      variable conv_R   : signed(16 downto 0);
      variable conv_G   : signed(16 downto 0);
      variable mode15   : std_logic;
      variable bw_value : signed(7 downto 0);
      variable bw_nibble: signed(8 downto 0);
      variable bw_out   : std_logic_vector(7 downto 0);
      variable conv_GR  : signed(16 downto 0);
      variable conv_B   : signed(16 downto 0);
   begin
      if rising_edge(clk2x) then

         color_write <= '0';
         color_done  <= '0';

         if (reset_calc = '1') then
         
            colorState    <= COLOR_IDLE;
         
         elsif (ce = '1') then
         
            case (colorState) is
            
               when COLOR_IDLE =>
                  if (idct_done = '1') then
                     color_buffer <= idct_buffer;
                     if (rec_depth(1) = '1') then
                        color_block <= 2;
                        colorState  <= COLOR_SELECTBLOCK;
                        color_x     <= 0;
                        color_y     <= 0;
                     else
                        colorState   <= COLOR_BW_READ;
                        color_bwAddr <= 0;
                     end if;
                  end if;
               
               when COLOR_SELECTBLOCK =>
                  colorState  <= COLOR_READ0;
                  color_xBase <= 0;
                  color_yBase <= 0;
                  case (color_block) is
                     when 3 => color_xBase <= 8;
                     when 4 => color_yBase <= 8;
                     when 5 => color_xBase <= 8; color_yBase <= 8;
                     when others => null;
                  end case;
                  
               when COLOR_READ0 => 
                  colorState <= COLOR_READ1;
                  
               when COLOR_READ1 => 
                  colorState   <= COLOR_READ2;
                  color_read_R <= signed(idct_readData);
               
               when COLOR_READ2 =>
                  colorState   <= COLOR_READ3;
                  color_read_B <= signed(idct_readData);
                  
               when COLOR_READ3 =>
                  colorState   <= COLOR_CALC;
                  color_read_Y <= signed(idct_readData);
                  conv_R := to_signed(to_integer(color_read_R) * 359, 17);
                  conv_GR := to_signed(to_integer(color_read_R) * (-183), 17);
                  conv_GR(4 downto 0) := (others => '0');
                  conv_G := to_signed(to_integer(color_read_B) * (-88), 17) + conv_GR;
                  conv_B := to_signed(to_integer(color_read_B) * 454, 17);
                  color_conv_R <= conv_R;
                  color_conv_G <= conv_G;
                  color_conv_B <= conv_B;
                  
               when COLOR_CALC =>
                  mode15 := '0';
                  if (rec_depth = "11") then
                     mode15 := '1';
                  end if;
                  
                  color_write  <= '1';
                  color_addr   <= to_unsigned((color_x + color_xBase) + (color_y + color_yBase) * 16, 8);
                  color_result( 7 downto  0) <= colorChannel(color_read_Y, color_conv_R, mode15, not rec_signed);
                  color_result(15 downto  8) <= colorChannel(color_read_Y, color_conv_G, mode15, not rec_signed);
                  color_result(23 downto 16) <= colorChannel(color_read_Y, color_conv_B, mode15, not rec_signed);

                  colorState <= COLOR_READ0;
                  if (color_x < 7) then 
                     color_x <= color_x + 1; 
                  else 
                     color_x <= 0; 
                     if (color_y < 7) then 
                        color_y <= color_y + 1; 
                     else
                        color_y <= 0; 
                        if (color_block = 5) then
                           colorState <= COLOR_IDLE;
                           color_done <= '1';
                        else
                           colorState  <= COLOR_SELECTBLOCK;
                           color_block <= color_block + 1;
                        end if;
                     end if;
                  end if;
                  
               when COLOR_BW_READ =>
                  colorState <= COLOR_BW_WRITE;
               
               when COLOR_BW_WRITE =>
                  color_write  <= '1';
                  color_addr   <= to_unsigned(color_bwAddr, 8);
                  bw_value := signed(idct_readData);
                  if (rec_depth = "00") then
                     bw_nibble := shift_right(resize(bw_value, 9) + 8, 4);
                     if (bw_nibble > 7) then bw_nibble := to_signed(7, 9); end if;
                     bw_out := std_logic_vector(bw_nibble(3 downto 0)) & "0000";
                  else
                     bw_out := std_logic_vector(bw_value);
                  end if;
                  if (rec_signed = '0') then
                     bw_out(7) := not bw_out(7);
                  end if;
                  color_result <= x"0000" & bw_out;
                  if (color_bwAddr = 63) then
                     colorState   <= COLOR_IDLE;
                     color_done <= '1';
                  else
                     color_bwAddr <= color_bwAddr + 1;
                     colorState   <= COLOR_BW_READ;
                  end if;
                  
            end case;
            
         end if;
         
      end if;
   end process;
   
   iramColorResult: entity work.dpram
   generic map 
   ( 
      addr_width => 8, 
      data_width => 24
   )
   port map
   (
      clock_a     => clk2x,
      clken_a     => '1',
      address_a   => std_logic_vector(color_addr),
      data_a      => color_result,
      wren_a      => color_write,
      
      clock_b     => clk2x,
      address_b   => std_logic_vector(color_readAddr),
      data_b      => x"000000",
      wren_b      => '0',
      q_b         => color_readData
   );
   
   -- Output
   process (clk2x)
      variable color_round16_r : std_logic_vector(4 downto 0);
      variable color_round16_g : std_logic_vector(4 downto 0);
      variable color_round16_b : std_logic_vector(4 downto 0);
   begin
      if rising_edge(clk2x) then

         FifoOut_Wr      <= '0';
         color_readNext  <= '0';
         color_readValid <= color_readNext;
         
         if (decodeDone = '0') then
            fifoOut_done    <= '0';
         end if;

         if (reset_calc = '1') then
         
            outputState    <= OUTPUT_IDLE;
            colormapState  <= COLORMAP_IDLE;
         
         elsif (ce = '1') then
         
            case (outputState) is
            
               when OUTPUT_IDLE =>
                  if (color_done = '1') then
                     outputState    <= OUTPUT_READ;
                     color_readAddr <= (others => '0');
                     color_readNext <= '1';
                     case (rec_depth) is
                        when "00" => colormapState <= COLORMAP_4_1;
                        when "01" => colormapState <= COLORMAP_8_1;
                        when "10" => colormapState <= COLORMAP_24_1;
                        when "11" => colormapState <= COLORMAP_16_1;
                        when others => null;
                     end case;
                  end if;
               
               when OUTPUT_READ =>
                  color_readNext <= '1';
                  color_readAddr <= color_readAddr + 1;
                  if ((rec_depth(1) = '1' and color_readAddr = 254) or (rec_depth(1) = '0' and color_readAddr = 62)) then
                     outputState    <= OUTPUT_IDLE;
                     fifoOut_done   <= '1';
                  end if;
               
            end case;
            
            case (colormapState) is
            
               when COLORMAP_IDLE => null;
               
               -- 4 bit
               when COLORMAP_4_1 => if (color_readValid = '1') then colormapState <= COLORMAP_4_2; FifoOut_Din( 3 downto  0) <= color_readData(7 downto 4); end if;
               when COLORMAP_4_2 => if (color_readValid = '1') then colormapState <= COLORMAP_4_3; FifoOut_Din( 7 downto  4) <= color_readData(7 downto 4); end if;
               when COLORMAP_4_3 => if (color_readValid = '1') then colormapState <= COLORMAP_4_4; FifoOut_Din(11 downto  8) <= color_readData(7 downto 4); end if;
               when COLORMAP_4_4 => if (color_readValid = '1') then colormapState <= COLORMAP_4_5; FifoOut_Din(15 downto 12) <= color_readData(7 downto 4); end if;
               when COLORMAP_4_5 => if (color_readValid = '1') then colormapState <= COLORMAP_4_6; FifoOut_Din(19 downto 16) <= color_readData(7 downto 4); end if;
               when COLORMAP_4_6 => if (color_readValid = '1') then colormapState <= COLORMAP_4_7; FifoOut_Din(23 downto 20) <= color_readData(7 downto 4); end if;
               when COLORMAP_4_7 => if (color_readValid = '1') then colormapState <= COLORMAP_4_8; FifoOut_Din(27 downto 24) <= color_readData(7 downto 4); end if;
               when COLORMAP_4_8 => if (color_readValid = '1') then colormapState <= COLORMAP_4_1; FifoOut_Din(31 downto 28) <= color_readData(7 downto 4); FifoOut_Wr <= '1'; end if;
               
               -- 8 bit
               when COLORMAP_8_1 => if (color_readValid = '1') then colormapState <= COLORMAP_8_2; FifoOut_Din( 7 downto  0) <= color_readData(7 downto 0); end if;
               when COLORMAP_8_2 => if (color_readValid = '1') then colormapState <= COLORMAP_8_3; FifoOut_Din(15 downto  8) <= color_readData(7 downto 0); end if;
               when COLORMAP_8_3 => if (color_readValid = '1') then colormapState <= COLORMAP_8_4; FifoOut_Din(23 downto 16) <= color_readData(7 downto 0); end if;
               when COLORMAP_8_4 => if (color_readValid = '1') then colormapState <= COLORMAP_8_1; FifoOut_Din(31 downto 24) <= color_readData(7 downto 0); FifoOut_Wr <= '1'; end if;
               
               -- 16 bit
               when COLORMAP_16_1 | COLORMAP_16_2 =>
                  if (color_readValid = '1') then
                     color_round16_r := color_readData( 7 downto  3);
                     color_round16_g := color_readData(15 downto 11);
                     color_round16_b := color_readData(23 downto 19);

                     if (colormapState = COLORMAP_16_1) then
                        colormapState <= COLORMAP_16_2;
                        FifoOut_Din( 4 downto  0) <= color_round16_r;
                        FifoOut_Din( 9 downto  5) <= color_round16_g;
                        FifoOut_Din(14 downto 10) <= color_round16_b;
                        FifoOut_Din(15) <= rec_bit15;
                     else
                        colormapState <= COLORMAP_16_1;
                        FifoOut_Wr    <= '1';
                        FifoOut_Din(20 downto 16) <= color_round16_r;
                        FifoOut_Din(25 downto 21) <= color_round16_g;
                        FifoOut_Din(30 downto 26) <= color_round16_b;
                        FifoOut_Din(31) <= rec_bit15;
                     end if;
                  end if;

               -- 24 bit
               when COLORMAP_24_1 => -- 0 bytes left
                  if (color_readValid = '1') then
                     colormapState <= COLORMAP_24_2;
                     color_readData_1 <= color_readData;
                  end if;
                  
               when COLORMAP_24_2 => -- 3 bytes left
                  if (color_readValid = '1') then
                     colormapState <= COLORMAP_24_3;
                     FifoOut_Wr    <= '1';
                     FifoOut_Din( 7 downto  0) <= color_readData_1( 7 downto  0);
                     FifoOut_Din(15 downto  8) <= color_readData_1(15 downto  8);
                     FifoOut_Din(23 downto 16) <= color_readData_1(23 downto 16);
                     FifoOut_Din(31 downto 24) <= color_readData(7 downto 0);
                     color_readData_1 <= color_readData;
                  end if;
                  
               when COLORMAP_24_3 => -- 2 bytes left
                  if (color_readValid = '1') then
                     colormapState <= COLORMAP_24_4;
                     FifoOut_Wr    <= '1';
                     FifoOut_Din( 7 downto  0) <= color_readData_1(15 downto  8);
                     FifoOut_Din(15 downto  8) <= color_readData_1(23 downto 16);
                     FifoOut_Din(23 downto 16) <= color_readData( 7 downto 0);
                     FifoOut_Din(31 downto 24) <= color_readData(15 downto 8);
                     color_readData_1 <= color_readData;
                  end if;
                  
               when COLORMAP_24_4 => -- 1 byte left
                  if (color_readValid = '1') then
                     colormapState <= COLORMAP_24_1;
                     FifoOut_Wr    <= '1';
                     FifoOut_Din( 7 downto  0) <= color_readData_1(23 downto 16);
                     FifoOut_Din(15 downto  8) <= color_readData( 7 downto 0);
                     FifoOut_Din(23 downto 16) <= color_readData(15 downto 8);
                     FifoOut_Din(31 downto 24) <= color_readData(23 downto 16);
                  end if;
               
            end case;
            
         end if;
         
      end if;
   end process;
   
   ififoOut: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 256,
      DATAWIDTH        => 32,
      NEARFULLDISTANCE => 3
   )
   port map
   ( 
      clk      => clk2x,     
      reset    => reset_calc,   
                
      Din      => FifoOut_Din,     
      Wr       => FifoOut_Wr,      
      Full     => open,    
      NearFull => FifoOut_NearFull,

      Dout     => FifoOut_Dout,    
      Rd       => FifoOut_Rd,      
      Empty    => FifoOut_Empty   
   );
   
   FifoOut_Rd <= (not clk2xIndex) when (FifoOut_Empty = '0' and bus_read = '1' and bus_addr(3 downto 2) = "00") else
                 (not clk2xIndex) when (FifoOut_Empty = '0' and dma_read = '1') else 
                 '0';
   
   
   MDECSTAT(15 downto  0) <= std_logic_vector(wordsRemain - 1);
   MDECSTAT(18 downto 16) <= "100" when (currentBlock = 0) else "101" when (currentBlock = 1) else std_logic_vector(currentBlock - 2);
   MDECSTAT(22 downto 19) <= "0000";
   MDECSTAT(23)           <= rec_bit15;
   MDECSTAT(24)           <= rec_signed;
   MDECSTAT(26 downto 25) <= rec_depth;
   MDECSTAT(27)           <= '1' when (MDECCONTROL(0) = '1' and (FifoOut_NearFull = '1' or (FifoOut_Empty = '0' and dma_read = '0'))) else '0'; -- Data-Out Request (set when DMA1 enabled and ready to send data)
   MDECSTAT(28)           <= '1' when (FifoIn_NearFull = '0' and MDECCONTROL(1) = '1') else '0';              -- Data-In Request  (set when DMA0 enabled and ready to receive data)
   MDECSTAT(29)           <= '0' when (receiveState = RECEIVE_IDLE) else '1';
   MDECSTAT(30)           <= FifoIn_NearFull;
   MDECSTAT(31)           <= FifoOut_Empty;
   
   dmaWriteRequest <= MDECSTAT(28);
   dmaReadRequest  <= MDECSTAT(27);
   
   dma_readdata <= FifoOut_Dout when (FifoOut_Empty = '0') else (others => '1');
   
   -- readback
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         bus_dataRead <= (others => '0');
      
         if (bus_read = '1') then
            if (bus_addr(3 downto 2) = "00") then
               if (FifoOut_Empty = '0') then
                  bus_dataRead <= FifoOut_Dout;
               else
                  bus_dataRead <= x"FFFFFFFF";
               end if;
            elsif (bus_addr(3 downto 2) = "01") then
               bus_dataRead <= MDECSTAT;
            else
               bus_dataRead <= x"FFFFFFFF";
            end if;
         end if;
         
      end if;
   end process;

--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         if (SS_reset = '1') then
            ss_in <= (others => (others => '0'));
         elsif (SS_wren = '1' and SS_Adr < 2) then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         SS_Idle <= '0';
         if (FifoIn_Empty = '1' and FifoOut_Empty = '1' and receiveState = RECEIVE_IDLE and idctState = IDCT_IDLE and colorState = COLOR_IDLE and outputState = OUTPUT_IDLE) then
            SS_Idle    <= '1';
            ss_timeout <= (others => '0');
         end if;
         
         if (ss_timeout(23) = '1') then
            SS_Idle    <= '1';
         else
            ss_timeout <= ss_timeout + 1;
         end if;
         
         ram_SSrden <= '0';
         if (SS_rden = '1' and ((SS_Adr >= 16 and SS_Adr < 48) or (SS_Adr >= 64 and SS_Adr < 96))) then
            ram_SSrden <= '1';
         end if;
         
         if (ram_SSrden = '1') then
            SS_DataRead <= RamSSdataB;
         elsif (SS_rden = '1' and SS_Adr < 2) then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         elsif (SS_rden = '1') then
            SS_DataRead <= (others => '0');
         end if;
      
      end if;
   end process;

   -- synthesis translate_off
   
   goutput : if 1 = 1 generate
      type tdb_idct_result is array(0 to 63) of signed(7 downto 0);
      type tdb_color_result is array(0 to 255) of std_logic_vector(23 downto 0);
      type tdb_fifoout_result is array(0 to 255) of std_logic_vector(31 downto 0);
      
      signal debugCnt_RL      : integer;
      signal debugCnt_IDCT    : integer;
      signal debugCnt_COLOR   : integer;
      signal debugCnt_FIFOOUT : integer;
   begin
   
      process
         file outfile_RL            : text;
         file outfile_IDCT          : text;
         file outfile_COLOR         : text;
         file outfile_FIFOOUT       : text;
         variable f_status          : FILE_OPEN_STATUS;
         variable line_out          : line;
         variable regcheck          : integer range 0 to 3; 
            
         variable idctState_last    : tidctState;
         variable db_idct_result    : tdb_idct_result;
         variable db_color_result   : tdb_color_result;
         variable db_fifoout_result : tdb_fifoout_result;
         variable fifoout_cnt       : integer;
      begin
   
         file_open(f_status, outfile_RL, "R:\\debug_mdec_RL_sim.txt", write_mode);
         file_close(outfile_RL);
         file_open(f_status, outfile_RL, "R:\\debug_mdec_RL_sim.txt", append_mode);
         
         file_open(f_status, outfile_IDCT, "R:\\debug_mdec_IDCT_sim.txt", write_mode);
         file_close(outfile_IDCT);
         file_open(f_status, outfile_IDCT, "R:\\debug_mdec_IDCT_sim.txt", append_mode);
         
         file_open(f_status, outfile_COLOR, "R:\\debug_mdec_COLOR_sim.txt", write_mode);
         file_close(outfile_COLOR);
         file_open(f_status, outfile_COLOR, "R:\\debug_mdec_COLOR_sim.txt", append_mode);         
         
         file_open(f_status, outfile_FIFOOUT, "R:\\debug_mdec_FIFOOUT_sim.txt", write_mode);
         file_close(outfile_FIFOOUT);
         file_open(f_status, outfile_FIFOOUT, "R:\\debug_mdec_FIFOOUT_sim.txt", append_mode);
         
         debugCnt_RL      <= 0;
         debugCnt_IDCT    <= 0;
         debugCnt_COLOR   <= 0;
         debugCnt_FIFOOUT <= 0;
         
         while (true) loop
            
            wait until rising_edge(clk2x);
            
            if (idctState_last = IDCT_IDLE and idctState = IDCT_STAGE1) then
               write(line_out, to_string(debugCnt_RL));
               write(line_out, string'(" RL decoded block ")); 
               write(line_out, to_string(idct_block));
               writeline(outfile_RL, line_out);
               for i in 0 to 63 loop
                  write(line_out, to_string(to_integer(idct_input(i))));
                  writeline(outfile_RL, line_out);
               end loop;
               debugCnt_RL <= debugCnt_RL + 1;
            end if; 
            idctState_last := idctState;
            
            if (idct_write = '1') then
               db_idct_result(to_integer(idct_target(5 downto 0))) := idct_resultClip;
            
               if (idct_target(5 downto 0) = 0) then
                  write(line_out, to_string(debugCnt_IDCT));
                  write(line_out, string'(" IDCT converted block ")); 
                  write(line_out, to_string(to_integer(idct_target(8 downto 6))));
                  writeline(outfile_IDCT, line_out);
               end if;
               if (idct_target(5 downto 0) = 63) then
                  for i in 0 to 63 loop
                     write(line_out, to_string(to_integer(db_idct_result(i))));
                     writeline(outfile_IDCT, line_out);
                  end loop;
                  debugCnt_IDCT <= debugCnt_IDCT + 1;
               end if;
            end if; 
            
            if (color_write = '1') then
               db_color_result(to_integer(color_addr)) := color_result;
            
               if (color_addr= 0) then
                  write(line_out, to_string(debugCnt_COLOR));
                  write(line_out, string'(" color converted")); 
                  writeline(outfile_COLOR, line_out);
               end if;
               if (rec_depth(1) = '1' and color_addr = 255) then
                  for i in 0 to 255 loop
                     write(line_out, to_hstring(db_color_result(i)));
                     writeline(outfile_COLOR, line_out);
                  end loop;
                  debugCnt_COLOR <= debugCnt_COLOR + 1;
               end if;
               if (rec_depth(1) = '0' and color_addr = 63) then
                  for i in 0 to 63 loop
                     write(line_out, to_hstring(db_color_result(i)));
                     writeline(outfile_COLOR, line_out);
                  end loop;
                  debugCnt_COLOR <= debugCnt_COLOR + 1;
               end if;
            end if; 
            
            if (color_done = '1') then
               fifoout_cnt := 0;
            end if;
            if (FifoOut_Wr = '1') then
               db_fifoout_result(fifoout_cnt) := FifoOut_Din;
               fifoout_cnt := fifoout_cnt + 1;
            end if;
            if (fifoout_cnt > 0 and outputState = OUTPUT_IDLE and color_readValid = '0' and FifoOut_Wr = '0') then
               write(line_out, to_string(debugCnt_FIFOOUT));
               write(line_out, string'(" fifo out")); 
               writeline(outfile_FIFOOUT, line_out);
               for i in 0 to fifoout_cnt - 1 loop
                  write(line_out, to_hstring(db_fifoout_result(i)));
                  writeline(outfile_FIFOOUT, line_out);
               end loop;
               fifoout_cnt := 0;
               debugCnt_FIFOOUT <= debugCnt_FIFOOUT + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;
   
   -- synthesis translate_on

end architecture;





