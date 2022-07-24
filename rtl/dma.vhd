library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity dma is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      errorCHOP            : out std_logic;
      errorDMACPU          : out std_logic;
      errorDMAFIFO         : out std_logic;
      
      REPRODUCIBLEDMATIMING: in  std_logic;
      DMABLOCKATONCE       : in  std_logic;
      
      canDMA               : in  std_logic;
      cpuPaused            : in  std_logic;
      dmaRequest           : out std_logic;
      dmaOn                : out std_logic;
      irqOut               : out std_logic := '0';
      
      ram_refresh          : out std_logic;
      ram_dataWrite        : out std_logic_vector(31 downto 0) := (others => '0');
      ram_dataRead         : in  std_logic_vector(127 downto 0);
      ram_Adr              : out std_logic_vector(22 downto 0) := (others => '0');
      ram_be               : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw              : out std_logic := '0';
      ram_ena              : out std_logic := '0';
      ram_128              : out std_logic := '0';
      ram_done             : in  std_logic;
      ram_reqprocessed     : in  std_logic;
      
      gpu_dmaRequest       : in  std_logic;
      DMA_GPU_waiting      : out std_logic := '0';
      DMA_GPU_writeEna     : out std_logic := '0';
      DMA_GPU_readEna      : out std_logic := '0';
      DMA_GPU_write        : out std_logic_vector(31 downto 0);
      DMA_GPU_read         : in  std_logic_vector(31 downto 0);
      
      mdec_dmaWriteRequest : in  std_logic;
      mdec_dmaReadRequest  : in  std_logic;
      DMA_MDEC_writeEna    : out std_logic := '0';
      DMA_MDEC_readEna     : out std_logic := '0';
      DMA_MDEC_write       : out std_logic_vector(31 downto 0);
      DMA_MDEC_read        : in  std_logic_vector(31 downto 0);      
      
      DMA_CD_readEna       : out std_logic := '0';
      DMA_CD_read          : in  std_logic_vector(7 downto 0);
      
      spu_dmaRequest       : in  std_logic;
      DMA_SPU_writeEna     : out std_logic := '0';
      DMA_SPU_readEna      : out std_logic := '0';
      DMA_SPU_write        : out std_logic_vector(15 downto 0);
      DMA_SPU_read         : in  std_logic_vector(15 downto 0);
      
      bus_addr             : in  unsigned(6 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(31 downto 0);
      
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(5 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0);
      SS_idle              : out std_logic
   );
end entity;

architecture arch of dma is

   type tdmaState is
   (
      OFF,
      WAITING,
      READHEADER,
      WAITREAD,
      WORKING,
      STOPPING,
      PAUSING
   );
   signal dmaState : tdmaState := OFF;

   type dmaRecord is record
      D_MADR            : unsigned(23 downto 0);
      D_BCR             : unsigned(31 downto 0);
      D_CHCR            : unsigned(31 downto 0);
      request           : std_logic;
      timeupPending     : std_logic;
      requestsPending   : std_logic;
      channelOn         : std_logic;
      chopwaiting       : std_logic;
      chopwaitcount     : unsigned(7 downto 0);
   end record;
  
   type tdmaArray is array (0 to 6) of dmaRecord;
   signal dmaArray    : tdmaArray;
   signal dmaSettings : dmaRecord;
  
   signal DPCR                : unsigned(31 downto 0);
   signal DICR                : unsigned(23 downto 0);
   signal DICR_readback       : unsigned(31 downto 0);
   signal DICR_IRQs           : unsigned(6 downto 0);
         
   signal triggerDMA          : std_logic_vector(6 downto 0);
   signal triggerchannel      : integer range 0 to 6;
      
   signal readStall           : std_logic;
      
   signal wordAccu            : integer range 0 to 3 := 0;
   signal DMA_CD_read_accu    : std_logic_vector(23 downto 0);
   signal DMA_SPU_read_accu   : std_logic_vector(15 downto 0);
      
   signal isOn                : std_logic;
   signal activeChannel       : integer range 0 to 6;
   signal paused              : std_logic;
   signal gpupaused           : std_logic;
   signal waitcnt             : integer range 0 to 15;
   signal wordcount           : unsigned(16 downto 0);
   signal toDevice            : std_logic;
   signal directionNeg        : std_logic;
   signal nextAddr            : std_logic_vector(23 downto 0);
   signal blocksleft          : unsigned(15 downto 0);
   signal dmacount            : unsigned(9 downto 0);
         
   signal chopsize            : unsigned(7 downto 0);
   signal chopwaittime        : unsigned(7 downto 0);
   
   signal dmaEndWait          : integer range 0 to 12;
         
   signal autoread            : std_logic := '0';
   signal firstword           : std_logic := '0';
      
   signal dataNext            : std_logic_vector(95 downto 0);
   signal dataCount           : integer range 0 to 3 := 0;
   signal firstsize           : integer range 0 to 3 := 0;
   signal requestOnFly        : integer range 0 to 2;
   
   signal requestedDwords     : integer range 0 to 65536;
   signal requiredDwords      : integer range 0 to 65536;
      
   signal fifoIn_reset        : std_logic := '0';
   signal fifoIn_Din          : std_logic_vector(31 downto 0);
   signal fifoIn_Wr           : std_logic; 
   signal fifoIn_Full         : std_logic;
   signal fifoIn_Dout         : std_logic_vector(31 downto 0);
   signal fifoIn_Rd           : std_logic;
   signal fifoIn_Empty        : std_logic;
   signal fifoIn_Valid        : std_logic;   
   signal fifoIn_Valid_1      : std_logic;   
      
   signal fifoOut_reset       : std_logic := '0';
   signal fifoOut_Din         : std_logic_vector(50 downto 0);
   signal fifoOut_Wr          : std_logic; 
   signal fifoOut_Full        : std_logic;
   signal fifoOut_NearFull    : std_logic;
   signal fifoOut_Dout        : std_logic_vector(50 downto 0);
   signal fifoOut_Rd          : std_logic;
   signal fifoOut_Empty       : std_logic;
   signal fifoOut_Done        : std_logic;
      
   signal ramwrite_pending    : std_logic;
   signal fifoOut_Wr_1        : std_logic;
      
   -- REPRODUCIBLEDMATIMING   
   signal REP_counter         : integer;
   signal REP_target          : integer;
   
   -- savestates
   type t_ssarray is array(0 to 63) of std_logic_vector(31 downto 0);
   signal ss_in   : t_ssarray := (others => (others => '0'));  
   signal ss_out  : t_ssarray := (others => (others => '0'));  
  
begin 

   dmaOn <= '1' when (dmaState /= OFF) else '0';

   ram_refresh <= '1' when (reset = '1') else '0';
   ram_be      <= "1111";
   ram_128     <= '1';

   DICR_readback( 5 downto  0) <= DICR( 5 downto 0);
   DICR_readback(14 downto  6) <= "000000000";
   DICR_readback(23 downto 15) <= DICR(23 downto 15);
   DICR_readback(30 downto 24) <= DICR_IRQs;
   DICR_readback(31)           <= '1' when (DICR(15) = '1') else
                                  '1' when (DICR(23) = '1' and (DICR(22 downto 16) and DICR_IRQs) /= "0000000") else 
                                  '0';

   DMA_MDEC_writeEna <= '1' when (dmaState = working and fifoIn_Valid = '1' and activeChannel = 0 and toDevice = '1') else '0'; 
   DMA_MDEC_write    <= fifoIn_Dout;  
   
   DMA_MDEC_readEna  <= '1' when (dmaState = working and fifoOut_NearFull = '0' and activeChannel = 1 and toDevice = '0') else '0';
   
   DMA_GPU_waiting   <= '1' when (dmaOn = '1' and activeChannel = 2) else
                        '1' when (DPCR((2 * 4) + 3) = '1' and dmaArray(2).D_CHCR(24) = '1') else 
                        '0';
                        
   DMA_GPU_readEna   <= '1' when (dmaState = working and fifoOut_NearFull = '0' and activeChannel = 2 and toDevice = '0') else '0';
   DMA_GPU_writeEna  <= '1' when (dmaState = working and fifoIn_Valid = '1' and activeChannel = 2 and toDevice = '1') else '0'; 
   DMA_GPU_write     <= fifoIn_Dout;

   DMA_CD_readEna    <= '1' when (dmaState = working and fifoOut_NearFull = '0' and activeChannel = 3 and toDevice = '0') else '0';
   
   DMA_SPU_readEna   <= '1' when (dmaState = working and fifoOut_NearFull = '0' and activeChannel = 4 and toDevice = '0') else '0';
   
   DMA_SPU_writeEna  <= '1' when (dmaState = working and fifoIn_Valid = '1' and activeChannel = 4 and toDevice = '1') else 
                        '1' when ((dmaState = working or dmaState = stopping or dmaState = pausing) and fifoIn_Valid_1 = '1' and activeChannel = 4 and toDevice = '1') else 
                        '0'; 
   DMA_SPU_write     <= fifoIn_Dout(15 downto 0) when fifoIn_Valid = '1' else fifoIn_Dout(31 downto 16);

   readStall <= '1' when (activeChannel = 2 and toDevice = '0' and gpu_dmaRequest = '0') else '0';

   chopsize     <= to_unsigned(1, 8) sll to_integer(dmaSettings.D_CHCR(18 downto 16));
   chopwaittime <= to_unsigned(1, 8) sll to_integer(dmaSettings.D_CHCR(22 downto 20));

   gSSout: for i in 0 to 6 generate
   begin
      ss_out(28 + i)(23 downto 0) <= std_logic_vector(dmaArray(i).D_MADR);        
      ss_out(35 + i)              <= std_logic_vector(dmaArray(i).D_BCR);          
      ss_out(42 + i)              <= std_logic_vector(dmaArray(i).D_CHCR);         
      ss_out(19 + i)(8)           <= dmaArray(i).request;        
      ss_out(19 + i)(9)           <= dmaArray(i).requestsPending;
      ss_out(19 + i)(10)          <= dmaArray(i).timeupPending;  
      ss_out(19 + i)(11)          <= dmaArray(i).channelOn;  
   end generate;

   ss_out(26)               <= std_logic_vector(DPCR);     
   ss_out(27)(23 downto 0)  <= std_logic_vector(DICR);    
   ss_out(27)(30 downto 24) <= std_logic_vector(DICR_IRQs);
   ss_out(27)(31)           <= DICR_readback(31);

   ss_out(4)(7 downto 0)    <= x"07" when (DMA_GPU_waiting = '1') else x"00";
   ss_out(4)(8)             <= isOn;         
   ss_out(2)(18 downto 16)  <= std_logic_vector(to_unsigned(activeChannel, 3));       
   ss_out(4)(9)             <= paused;       
   ss_out(4)(10)            <= gpupaused;    

   process (clk1x)
      variable channel         : integer range 0 to 7;
      variable triggerNew      : std_logic;
      variable triggerPrio     : unsigned(2 downto 0);
      variable requestOnFlyNew : integer range 0 to 2;
   begin
      if rising_edge(clk1x) then
      
         fifoIn_reset  <= '0';
         fifoOut_reset <= '0';
         
         fifoOut_Wr    <= '0';
         
         fifoIn_Valid   <= fifoIn_Rd;
         fifoIn_Valid_1 <= fifoIn_Valid;
      
         if (cpuPaused = '1') then
            REP_counter <= REP_counter + 1;
         else
            REP_counter <= 0;
         end if;
         
         errorCHOP      <= '0';
         errorDMACPU    <= '0';
         errorDMAFIFO   <= '0';
         
         requestOnFlyNew := requestOnFly;
      
         if (reset = '1') then
         
            dmaState <= OFF;
         
            for i in 0 to 6 loop
               dmaArray(i).D_MADR            <= unsigned(ss_in(28 + i)(23 downto 0));
               dmaArray(i).D_BCR             <= unsigned(ss_in(35 + i));
               dmaArray(i).D_CHCR            <= unsigned(ss_in(42 + i));
               dmaArray(i).request           <= ss_in(19 + i)(8);
               dmaArray(i).requestsPending   <= ss_in(19 + i)(9);
               dmaArray(i).timeupPending     <= ss_in(19 + i)(10);
               dmaArray(i).channelOn         <= ss_in(19 + i)(11);
               dmaArray(i).chopwaiting       <= '0';
               dmaArray(i).chopwaitcount     <= (others => '0');
            end loop;
            
            DPCR           <= unsigned(ss_in(26)); -- x"07654321";
            DICR           <= unsigned(ss_in(27)(23 downto 0));
            DICR_IRQs      <= unsigned(ss_in(27)(30 downto 24));
               
            triggerDMA     <= (others => '0');
            isOn           <= ss_in(4)(8);
            activeChannel  <= to_integer(unsigned(ss_in(2)(18 downto 16)));
            paused         <= ss_in(4)(9);
            gpupaused      <= ss_in(4)(10);
            waitcnt        <= 0;
            
            autoread       <= '0';
            
            fifoIn_reset   <= '1';
            
            fifoOut_reset  <= '1';
            fifoOut_Done   <= '1';
            
            dataCount      <= 0;
            requestOnFly   <= 0;
            ramwrite_pending <= '0';
         
            irqOut         <= '0';

         elsif (ce = '1') then
         
            irqOut     <= '0';
         
            ram_ena    <= '0';
         
            bus_dataRead <= (others => '0');

            channel := to_integer(unsigned(bus_addr(6 downto 4)));
            
            dmaArray(0).request <= mdec_dmaWriteRequest;
            dmaArray(1).request <= mdec_dmaReadRequest;
            dmaArray(2).request <= gpu_dmaRequest;
            dmaArray(3).request <= '1';
            dmaArray(4).request <= spu_dmaRequest;
            dmaArray(5).request <= '0';
            dmaArray(6).request <= '1';
            
            -- bus read
            if (bus_read = '1') then
               if (channel < 7) then
                  case (bus_addr(3 downto 2)) is
                     when "00" => bus_dataRead <= x"00" & std_logic_vector(dmaArray(channel).D_MADR);
                     when "01" => bus_dataRead <= std_logic_vector(dmaArray(channel).D_BCR); 
                     when "10" => bus_dataRead <= std_logic_vector(dmaArray(channel).D_CHCR);
                     when others => bus_dataRead <= (others => '1');
                  end case;
               else
                  case (bus_addr(3 downto 2)) is
                     when "00" => bus_dataRead <= std_logic_vector(DPCR);
                     when "01" => bus_dataRead <= std_logic_vector(DICR_readback); 
                     when others => bus_dataRead <= (others => '1');
                  end case;
               end if;
            end if;

            -- bus write
            if (bus_write = '1') then
               if (channel < 7) then
                  case (bus_addr(3 downto 2)) is
                     when "00" => dmaArray(channel).D_MADR <= unsigned(bus_dataWrite(23 downto 0));
                     when "01" => dmaArray(channel).D_BCR  <= unsigned(bus_dataWrite);
                     when "10" =>  -- todo: channel 6 has only 3 r/w bits
                        dmaArray(channel).D_CHCR( 1 downto  0) <= unsigned(bus_dataWrite( 1 downto  0));
                        dmaArray(channel).D_CHCR(10 downto  8) <= unsigned(bus_dataWrite(10 downto  8));
                        dmaArray(channel).D_CHCR(18 downto 16) <= unsigned(bus_dataWrite(18 downto 16));
                        dmaArray(channel).D_CHCR(22 downto 20) <= unsigned(bus_dataWrite(22 downto 20));
                        dmaArray(channel).D_CHCR(          24) <= bus_dataWrite(24);
                        dmaArray(channel).D_CHCR(30 downto 28) <= unsigned(bus_dataWrite(30 downto 28));
                        if (bus_dataWrite(24) = '0') then
                           dmaArray(channel).channelOn <= '0';
                        end if;
                     when others => null;
                  end case;
               else
                  case (bus_addr(3 downto 2)) is
                     when "00" => 
                        DPCR       <= unsigned(bus_dataWrite);
                     when "01" => 
                        DICR( 5 downto  0) <= unsigned(bus_dataWrite(5 downto 0));
                        DICR(14 downto  6) <= (14 downto 6 => '0');
                        DICR(          15) <= bus_dataWrite(15);
                        DICR(23 downto 16) <= unsigned(bus_dataWrite(23 downto 16));
                        DICR_IRQs          <= DICR_IRQs and (not unsigned(bus_dataWrite(30 downto 24)));
                        if (bus_dataWrite(15) = '1') then  -- force bit not used in duckstation, why?
                           irqOut <= '1';
                        end if;
                     when others => null;
                  end case;
               end if;
               
            end if;
            
            -- triggers from modules
            triggerDMA <= (others => '0');
            if (dmaArray(0).D_CHCR(28) = '1' or mdec_dmaWriteRequest = '1')  then triggerDMA(0) <= '1'; end if;
            if (dmaArray(1).D_CHCR(28) = '1' or mdec_dmaReadRequest = '1')   then triggerDMA(1) <= '1'; end if;
            if (dmaArray(2).D_CHCR(28) = '1' or gpu_dmaRequest = '1')        then triggerDMA(2) <= '1'; end if;
            if (dmaArray(3).D_CHCR(28) = '1')                                then triggerDMA(3) <= '1'; end if;
            if (dmaArray(4).D_CHCR(28) = '1' or spu_dmaRequest = '1')        then triggerDMA(4) <= '1'; end if;
            if (dmaArray(6).D_CHCR(28) = '1')                                then triggerDMA(6) <= '1'; end if;
             
            -- trigger
            triggerNew     := '0';
            triggerPrio    := "111";
            if (dmaState = OFF and dmaEndWait = 0 and bus_write = '0' and bus_read = '0') then
               for i in 0 to 6 loop
                  if (triggerDMA(i) = '1' and dmaArray(i).chopwaiting = '0') then
                     if ((DPCR((i * 4) + 3) = '1' and dmaArray(i).D_CHCR(24) = '1') or dmaArray(i).channelOn = '1') then -- enable + start or already on(retrigger after busy)
                        
                        if (triggerNew = '0' or (unsigned(DPCR((i * 4) + 2 downto (i*4))) <= triggerPrio)) then
                           triggerNew     := '1';
                           triggerchannel <= i;
                           triggerPrio    := unsigned(DPCR((i * 4) + 2 downto (i*4)));
                        end if;
                           
                     end if;
                  end if;
               end loop;
            end if;
            dmaRequest <= triggerNew;
            
            if (dmaState = OFF and dmaEndWait > 0) then
               dmaEndWait <= dmaEndWait - 1;
            end if;
            
            if (dmaRequest = '1' and canDMA = '1' and dmaState = OFF) then
               dmaArray(triggerchannel).requestsPending <= '0';
               dmaArray(triggerchannel).timeupPending   <= '0';
               dmaArray(triggerchannel).D_CHCR(28)      <= '0';
               dmaArray(triggerchannel).channelOn       <= '1';
               
               dmaState      <= WAITING;
               waitcnt       <= 8;
               isOn          <= '1';
               activeChannel <= triggerchannel;
               REP_target    <= 32;
               
               dmaSettings.D_CHCR <= dmaArray(triggerchannel).D_CHCR;
               dmaSettings.D_MADR <= dmaArray(triggerchannel).D_MADR;
               dmaSettings.D_BCR  <= dmaArray(triggerchannel).D_BCR;
            end if;
            
            -- accu
            if (DMA_CD_readEna = '1') then
               case (wordAccu) is
                  when 0 => wordAccu <= 3; 
                  when 1 => wordAccu <= 0; DMA_CD_read_accu(23 downto 16) <= DMA_CD_read;
                  when 2 => wordAccu <= 1; DMA_CD_read_accu(15 downto  8) <= DMA_CD_read;
                  when 3 => wordAccu <= 2; DMA_CD_read_accu( 7 downto  0) <= DMA_CD_read;
                  when others => null;
               end case;
            end if;
            
            if (DMA_SPU_readEna = '1') then
               case (wordAccu) is
                  when 0 => wordAccu <= 1; 
                  when 1 => wordAccu <= 0; DMA_SPU_read_accu <= DMA_SPU_read;
                  when others => null;
               end case;
            end if;
            
            -- chopping wait
            for i in 0 to 6 loop
               if (dmaArray(i).chopwaiting = '1' and cpuPaused = '0') then
                  if (dmaArray(i).chopwaitcount > 1) then
                     dmaArray(i).chopwaitcount <= dmaArray(i).chopwaitcount - 1;
                  else
                     dmaArray(i).chopwaiting   <= '0';
                     dmaArray(i).chopwaitcount <= (others => '0');
                  end if;
               end if;
            end loop;
            
            if (dmaState /= OFF and (bus_write = '1' or bus_read = '1')) then
               errorDMACPU <= '1';
            end if;
            
            if (fifoIn_Full = '1' or fifoOut_Full = '1') then
               errorDMAFIFO <= '1';
            end if;
            
            case (dmaState) is
            
               when OFF => null;
               
               when WAITING =>
                  if (dmaSettings.D_CHCR(0) = '0' and activeChannel = 2 and dmaSettings.D_CHCR(10 downto 9) = "01") then
                     dmaEndWait <= 12;
                  else
                     dmaEndWait <= 4;
                  end if;
               
                  if (waitcnt > 0 and cpuPaused = '1') then
                     waitcnt <= waitcnt - 1;
                  end if;
                  
                  if (waitcnt = 8) then
                     dmacount     <= (others => '0');
                     toDevice     <= dmaSettings.D_CHCR(0);
                     wordAccu     <= 0;
                     if (activeChannel = 3) then
                        wordAccu <= 3;
                     end if;
                     if (activeChannel = 4) then
                        wordAccu <= 1;
                     end if;
                     
                     if (dmaSettings.D_CHCR(8) = '1' and activeChannel /= 3 and activeChannel /= 6) then
                        errorCHOP <= '1';
                     end if;
                     
                     if (dmaSettings.D_CHCR(0) = '1') then
                        if (requestOnFly = 0) then
                           ram_rnw         <= '1';
                           ram_ena         <= '1';
                           ram_Adr         <= "00" & std_logic_vector(dmaSettings.D_MADR(20 downto 2)) & "00";
                           autoread        <= '1';
                           requestOnFlyNew := 1;
                        else
                           waitcnt <= waitcnt;
                        end if;
                     else
                        case (dmaSettings.D_CHCR(10 downto 9)) is
                           when "00" => -- manual
                              if (dmaSettings.D_CHCR(8) = '1') then -- chopping
                                 wordcount <= resize(chopsize, 17);
                                 if (dmaSettings.D_BCR(15 downto 0) = 0) then
                                    dmaSettings.D_BCR(16 downto 0) <= to_unsigned(16#10000#, 17) - chopsize;
                                 elsif (dmaSettings.D_BCR(15 downto 0) > chopsize) then
                                    dmaSettings.D_BCR(15 downto 0) <= dmaSettings.D_BCR(15 downto 0) - chopsize;
                                 else
                                    wordcount                                  <= '0' & dmaSettings.D_BCR(15 downto 0);
                                    dmaSettings.D_BCR(15 downto 0) <= (others => '0');
                                 end if;
                              else
                                 if (dmaSettings.D_BCR(15 downto 0) = 0) then
                                    wordcount <= '1' & x"0000";
                                 else
                                    wordcount <= '0' & dmaSettings.D_BCR(15 downto 0);
                                 end if;
                              end if;
                           
                           when "01" => -- request
                              blocksleft  <= dmaSettings.D_BCR(31 downto 16) - 1;
                              wordcount   <= '0' & dmaSettings.D_BCR(15 downto 0);
                           
                           when others => null;
                        end case;
                     end if;
                     directionNeg <= '0';
                     if (dmaSettings.D_CHCR(10) = '0' and dmaSettings.D_CHCR(1) = '1') then
                        directionNeg <= '1';
                     end if;    
                     
                     if (dmaSettings.D_CHCR(0) = '0') then -- from device -> can start immidiatly
                        waitcnt <= 0;
                        case (dmaSettings.D_CHCR(10 downto 9)) is
                           when "00" => -- manual
                              dmaState    <= WORKING;
                           
                           when "01" => -- request
                              dmaState    <= WORKING;
                              
                           when "10" => -- linked list -> forbidden
                              dmaState <= OFF;
                              isOn     <= '0';
                           
                           when others => 
                              dmaState <= OFF;
                              isOn     <= '0';
                        end case;
                     end if;
                  end if;
                  
                  if (waitcnt = 1) then
                     if (fifoIn_Empty = '1' and toDevice = '1') then
                        waitcnt <= waitcnt;
                     else
                        case (dmaSettings.D_CHCR(10 downto 9)) is
                           when "00" => -- manual
                              dmaState    <= WORKING;
                           
                           when "01" => -- request
                              dmaState    <= WORKING;
                           
                           when "10" => -- linked list
                              dmaState    <= READHEADER;
                           
                           when others => 
                              dmaState <= OFF;
                              isOn     <= '0';
                        end case;
                     end if;
                  end if;
               
               when READHEADER =>
                  REP_target <= REP_target + 16;
                  dmacount  <= dmacount + 1;
                  nextAddr  <= fifoIn_Dout(23 downto 0);
                  if (unsigned(fifoIn_Dout(31 downto 24)) > 0) then
                     dmaSettings.D_MADR <= dmaSettings.D_MADR + 4;
                     dmaState           <= WAITREAD;           
                  elsif (fifoIn_Dout(23) = '1' or fifoIn_Dout(23 downto 0) = x"000000" or dmaSettings.D_CHCR(0) = '0') then
                     dmaState <= STOPPING;
                     autoread <= '0';
                  else
                     dmaSettings.D_MADR <= unsigned(fifoIn_Dout(23 downto 0));
                     if (fifoIn_Dout(23) = '1') then
                        dmaState <= STOPPING;
                        autoread <= '0';
                     else
                        if (DMABLOCKATONCE = '1' and gpu_dmaRequest = '1') then
                           waitcnt   <= 8;
                           dmaState  <= WAITING;
                           autoread  <= '0';
                        else
                           dmaState    <= PAUSING;
                           paused      <= '1';
                           autoread    <= '0';
                        end if;
                     end if;
                  end if;  
               
               when WAITREAD => dmaState <= WORKING;
               
               when WORKING =>
                  if (fifoIn_Valid = '1' or (toDevice = '0' and fifoOut_NearFull = '0' and wordAccu = 0 and readStall = '0')) then
                     dmacount    <= dmacount + 1;
                     REP_target  <= REP_target + 1;
                     case (activeChannel) is
                     
                        when 0 =>
                           if (toDevice = '0') then
                              report "read from MDEC in not possible" severity failure;
                           end if;
                        
                        when 1 =>
                           if (toDevice = '0') then
                              fifoOut_Wr                <= '1';
                              fifoOut_Din(50 downto 32) <= std_logic_vector(dmaSettings.D_MADR(20 downto 2));
                              fifoOut_Din(31 downto 0)  <= DMA_MDEC_read;
                           else
                              report "write to MDEC out not possible" severity failure;
                           end if;
                     
                        when 2 =>
                           if (toDevice = '0') then
                              fifoOut_Wr                <= '1';
                              fifoOut_Din(50 downto 32) <= std_logic_vector(dmaSettings.D_MADR(20 downto 2));
                              fifoOut_Din(31 downto 0)  <= DMA_GPU_read;
                           end if;
                           
                        when 3 =>
                           if (toDevice = '0') then
                              fifoOut_Wr                <= '1';
                              fifoOut_Din(50 downto 32) <= std_logic_vector(dmaSettings.D_MADR(20 downto 2));
                              fifoOut_Din(31 downto 0)  <= DMA_CD_read & DMA_CD_read_accu;
                              REP_target                <= REP_target + 4;
                           end if;
                           
                        when 4 =>
                           REP_target <= REP_target + 2;
                           if (toDevice = '0') then
                              fifoOut_Wr                <= '1';
                              fifoOut_Din(50 downto 32) <= std_logic_vector(dmaSettings.D_MADR(20 downto 2));
                              fifoOut_Din(31 downto 0)  <= DMA_SPU_read & DMA_SPU_read_accu;
                           end if;
                           
                        when 6 =>
                           if (toDevice = '0') then
                              fifoOut_Wr                <= '1';
                              fifoOut_Din(50 downto 32) <= std_logic_vector(dmaSettings.D_MADR(20 downto 2));
                              if (wordcount = 1) then
                                 fifoOut_Din(31 downto 0) <= x"00FFFFFF";
                              else
                                 fifoOut_Din(31 downto 0) <= x"00" & std_logic_vector(dmaSettings.D_MADR(23 downto 2) - 1) & "00";
                              end if;
                              REP_target                <= REP_target + 3;
                           end if;
                     
                        when others => report "DMA channel not implemented" severity failure; 
                     end case;
                     
                     if (dmaSettings.D_CHCR(10) = '0' and directionNeg = '1')  then 
                        dmaSettings.D_MADR <= dmaSettings.D_MADR - 4;
                     else
                        dmaSettings.D_MADR <= dmaSettings.D_MADR + 4;
                     end if;
                  
                     wordcount <= wordcount - 1;
                     if (wordcount <= 1) then
                        case (dmaSettings.D_CHCR(10 downto 9)) is
                           when "00" => -- manual
                              if (dmaSettings.D_CHCR(8) = '1' and dmaSettings.D_BCR(15 downto 0) > 0) then
                                 dmaState <= PAUSING;
                                 autoread <= '0';
                                 dmaArray(activeChannel).chopwaiting   <= '1';
                                 dmaArray(activeChannel).chopwaitcount <= chopwaittime;
                                 dmaArray(activeChannel).D_CHCR(28)    <= '1';
                              else
                                 dmaState <= STOPPING;
                                 autoread <= '0';
                              end if;
                                 
                           when "01" => -- request
                              dmaSettings.D_BCR(31 downto 16) <= blocksleft;
                              blocksleft <= blocksleft - 1;
                              if (blocksleft = 0) then
                                 dmaState <= STOPPING;
                                 autoread <= '0';
                              else
                                 wordcount  <= '0' & dmaSettings.D_BCR(15 downto 0);
                                 if (DMABLOCKATONCE = '0' or dmaArray(activeChannel).request = '0') then
                                    dmaState <= PAUSING;
                                    autoread <= '0';
                                 end if;
                              end if;
                           
                           when "10" => -- linked list
                              dmaSettings.D_MADR <= unsigned(nextAddr);
                              if (nextAddr(23) = '1') then
                                 dmaState <= STOPPING;
                                 autoread <= '0';
                              else
                                 if (DMABLOCKATONCE = '1' and gpu_dmaRequest = '1') then
                                    dmaState <= WAITING;
                                    waitcnt  <= 8;
                                    autoread <= '0';
                                 else
                                    dmaState <= PAUSING;
                                    paused   <= '1';
                                    autoread <= '0';
                                 end if;
                              end if;
                           
                           when others => null;
                        end case;
                     end if;
                  end if;
               
               when STOPPING =>
                  if (fifoOut_Done = '1' and fifoOut_Wr = '0' and (requestOnFly = 0 or (requestOnFly = 1 and ram_done = '1'))) then
                     if (REPRODUCIBLEDMATIMING = '0' or REP_counter >= REP_target) then
                        dmaState   <= OFF;
                        isOn       <= '0';
                        dmaArray(activeChannel).D_MADR <= dmaSettings.D_MADR;
                        dmaArray(activeChannel).D_BCR  <= dmaSettings.D_BCR;
                        dmaArray(activeChannel).D_CHCR(24) <= '0';
                        dmaArray(activeChannel).channelOn  <= '0';
                        if (DICR(16 + activeChannel) = '1') then
                           DICR_IRQs(activeChannel) <= '1';
                           if (DICR(23) = '1') then
                              irqOut <= '1';
                           end if;
                        end if;
                     end if;
                  end if;
               
               when PAUSING =>
                  if (fifoOut_Done = '1' and fifoOut_Wr = '0' and (requestOnFly = 0 or (requestOnFly = 1 and ram_done = '1'))) then
                     if (REPRODUCIBLEDMATIMING = '0' or REP_counter >= REP_target) then
                        dmaState   <= OFF;
                        isOn       <= '0';
                        dmaArray(activeChannel).D_MADR <= dmaSettings.D_MADR;
                        dmaArray(activeChannel).D_BCR  <= dmaSettings.D_BCR;
                     end if;
                  end if;
            
            end case;

--##############################################################
--############################### ram handling
--##############################################################
         
            if (ram_done = '1' and toDevice = '1') then
               requestOnFlyNew := requestOnFlyNew - 1;
               dataNext        <= ram_dataRead(127 downto 32);
               dataCount       <= 3;
            
               if (firstword = '1') then
                  firstword       <= '0';
                  dataCount       <= firstsize;
                  case (dmaSettings.D_CHCR(10 downto 9)) is
                     when "00" => -- manual
                        if (dmaSettings.D_CHCR(8) = '1') then -- chopping
                           wordcount      <= resize(chopsize, 17);
                           requiredDwords <= to_integer(chopsize);
                           if (dmaSettings.D_BCR(15 downto 0) = 0) then
                              dmaSettings.D_BCR(16 downto 0) <= to_unsigned(16#10000#, 17) - chopsize;
                           elsif (dmaSettings.D_BCR(15 downto 0) > chopsize) then
                              dmaSettings.D_BCR(15 downto 0) <= dmaSettings.D_BCR(15 downto 0) - chopsize;
                           else
                              wordcount                                  <= '0' & dmaSettings.D_BCR(15 downto 0);
                              requiredDwords                             <= to_integer(dmaSettings.D_BCR(15 downto 0));
                              dmaSettings.D_BCR(15 downto 0)             <= (others => '0');
                           end if;
                        else
                           if (dmaSettings.D_BCR(15 downto 0) = 0) then
                              wordcount <= '1' & x"0000";
                              requiredDwords <= 16#10000#;
                           else
                              wordcount      <= '0' & dmaSettings.D_BCR(15 downto 0);
                              requiredDwords <= to_integer(dmaSettings.D_BCR(15 downto 0));
                           end if;
                        end if;
                     
                     when "01" => -- request
                        blocksleft     <= dmaSettings.D_BCR(31 downto 16) - 1;
                        wordcount      <= '0' & dmaSettings.D_BCR(15 downto 0);
                        requiredDwords <= to_integer(dmaSettings.D_BCR(15 downto 0));
                     
                     when "10" => -- linked list
                        wordcount      <= "0" & x"00" & unsigned(ram_dataRead(31 downto 24)); 
                        requiredDwords <= to_integer(unsigned(ram_dataRead(31 downto 24))) + 1;
                        if (ram_dataRead(31 downto 24) = x"00") then
                           autoread <= '0';
                        end if;
                     
                     when others => null;
                  end case;
               end if;
            end if;
            
            if (DMABLOCKATONCE = '0' and firstword = '0' and autoread = '1' and requestedDwords >= requiredDwords) then
               autoread <= '0';
            end if;
            
            if (ram_reqprocessed = '1' and autoread = '1') then
               if (ram_done = '1' and toDevice = '1' and firstword = '1' and dmaSettings.D_CHCR(10 downto 9) = "10" and ram_dataRead(31 downto 24) = x"00") then
                  autoread <= '0'; -- stop third read for empty linked list
               else
                  ram_ena         <= '1';
                  requestOnFlyNew := requestOnFlyNew + 1;
                  if (DMABLOCKATONCE = '0') then
                     requestedDwords <= requestedDwords + 4;
                  end if;
                  if (directionNeg = '1') then
                     ram_Adr <= std_logic_vector((unsigned(ram_Adr(22 downto 4)) & "0000") - 16); 
                  else
                     ram_Adr <= std_logic_vector((unsigned(ram_Adr(22 downto 4)) & "0000") + 16); 
                  end if;
               end if;
            end if;
            
            if (dmaState = WAITING and waitcnt = 8) then
               firstword        <= '1';
               firstsize        <= to_integer(3 - dmaSettings.D_MADR(3 downto 2));
               requestedDwords  <= to_integer(4 - dmaSettings.D_MADR(3 downto 2));
               fifoIn_reset     <= '1';
               dataCount        <= 0;
            elsif (dataCount > 0) then
               dataCount <= dataCount - 1;
               dataNext  <= x"00000000" & dataNext(95 downto 32);
            end if;
            
            requestOnFly <= requestOnFlyNew;
            
            -- fifo Out
            if (ram_done = '1') then
               ramwrite_pending <= '0';
            end if;
            
            if (fifoOut_Rd = '1') then
               ram_rnw          <= '0';
               ram_ena          <= '1';
               ram_Adr          <= "00" & fifoOut_Dout(50 downto 32) & "00";
               ram_dataWrite    <= fifoOut_Dout(31 downto 0);
               ramwrite_pending <= '1';
            end if; 
            
            fifoOut_Wr_1 <= fifoOut_Wr;
            if (fifoOut_Wr = '1' or fifoOut_Wr_1 = '1' ) then
               fifoOut_Done <= '0';
            elsif (ram_done = '1' and fifoOut_Empty = '1' and fifoOut_Rd = '0' and ram_ena = '0') then
               fifoOut_Done <= '1';
            end if;
            
         end if; -- ce
         
      end if;
   end process;
   
   fifoIn_Wr  <= ce when (toDevice = '1' and (ram_done = '1' or dataCount > 0)) else '0'; 
   
   fifoIn_Din <= ram_dataRead(31 downto 0) when ram_done = '1' else dataNext(31 downto 0);
   
   
   fifoIn_Rd <= '1' when (fifoIn_Empty = '0' and toDevice = '1' and dmaState = WAITING and waitcnt = 1) else
                '1' when (fifoIn_Empty = '0' and toDevice = '1' and dmaState = WAITREAD) else 
                '1' when (fifoIn_Empty = '0' and toDevice = '1' and dmaState = working and (activeChannel /= 4 or fifoIn_Valid = '0')) else 
                '0';

   
   iDMAfifoIn: entity mem.Syncfifo
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 32,
      NEARFULLDISTANCE => 32
   )
   port map
   ( 
      clk      => clk1x,
      reset    => fifoIn_reset,  
      Din      => fifoIn_Din,     
      Wr       => fifoIn_Wr,      
      Full     => fifoIn_Full,    
      NearFull => open, -- todo: is there any situation where data is coming faster? SPU? -> full error should trigger
      Dout     => fifoIn_Dout,    
      Rd       => fifoIn_Rd,      
      Empty    => fifoIn_Empty   
   );
   
   fifoOut_Rd <= ce when (fifoOut_Empty = '0' and (ramwrite_pending = '0' or ram_done = '1')) else '0';
   
   DMAfifoOut: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 256,
      DATAWIDTH        => 51,
      NEARFULLDISTANCE => 250
   )
   port map
   ( 
      clk      => clk1x,
      reset    => fifoOut_reset,  
      Din      => fifoOut_Din,     
      Wr       => fifoOut_Wr,      
      Full     => fifoOut_Full,    
      NearFull => fifoOut_NearFull,
      Dout     => fifoOut_Dout,    
      Rd       => fifoOut_Rd,      
      Empty    => fifoOut_Empty   
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
            
            ss_in(26) <= x"07654321"; -- DPCR
            
         elsif (SS_wren = '1') then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         end if;
         
         if (SS_rden = '1') then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         end if;
      
         SS_idle <= '0';
         if (dmaOn = '0' and dmaRequest = '0') then
            SS_idle <= '1';
         end if;
      
      end if;
   end process;

end architecture;





