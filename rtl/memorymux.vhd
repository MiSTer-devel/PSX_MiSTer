library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity memorymux is
   generic
   (
      NOMEMWAIT : std_logic
   );
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      loadExe              : in  std_logic;
      reset_exe            : out std_logic := '0';
      
      isIdle               : out std_logic;
      
      ram_dataWrite        : out std_logic_vector(31 downto 0) := (others => '0');
      ram_dataRead         : in  std_logic_vector(127 downto 0);
      ram_Adr              : out std_logic_vector(22 downto 0) := (others => '0');
      ram_be               : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw              : out std_logic := '0';
      ram_ena              : out std_logic := '0';
      ram_128              : out std_logic := '0';
      ram_done             : in  std_logic;
      
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
      
      bus_exp1_addr        : out unsigned(22 downto 0); 
      bus_exp1_dataWrite   : out std_logic_vector(31 downto 0);
      bus_exp1_read        : out std_logic;
      bus_exp1_write       : out std_logic;
      bus_exp1_dataRead    : in  std_logic_vector(31 downto 0);
      
      bus_pad_addr         : out unsigned(3 downto 0); 
      bus_pad_dataWrite    : out std_logic_vector(31 downto 0);
      bus_pad_read         : out std_logic;
      bus_pad_write        : out std_logic;
      bus_pad_writeMask    : out std_logic_vector(3 downto 0);
      bus_pad_dataRead     : in  std_logic_vector(31 downto 0);
      
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
      
      bus_gpu_addr         : out unsigned(3 downto 0); 
      bus_gpu_dataWrite    : out std_logic_vector(31 downto 0);
      bus_gpu_read         : out std_logic;
      bus_gpu_write        : out std_logic;
      bus_gpu_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_exp2_addr        : out unsigned(12 downto 0); 
      bus_exp2_dataWrite   : out std_logic_vector(31 downto 0);
      bus_exp2_read        : out std_logic;
      bus_exp2_write       : out std_logic;
      bus_exp2_dataRead    : in  std_logic_vector(31 downto 0);
      bus_exp2_writeMask   : out std_logic_vector(3 downto 0)
   );
end entity;

architecture arch of memorymux is
  
   type tState is
   (
      IDLE,
      READRAM,
      READCACHE,
      WRITERAM,
      --CHECKRAM,
      --ERRORRAM,
      READBIOS,
      BUSACTION,
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
   
   signal waitcnt          : integer range 0 to 127;
   
   signal dataFromBusses   : std_logic_vector(31 downto 0);
   
   -- EXE handling
   signal loadExe_latched  : std_logic := '0';
   signal exestep          : integer range 0 to 8;
   signal execopycnt       : unsigned(31 downto 0);
   signal exe_initial_pc   : unsigned(31 downto 0);
   signal exe_initial_gp   : unsigned(31 downto 0);
   signal exe_load_address : unsigned(31 downto 0);
   signal exe_file_size    : unsigned(31 downto 0);
   signal exe_stackpointer : unsigned(31 downto 0);
   
   
begin 

   isIdle <= '1' when (state = IDLE) else '0';

   process (state, mem_request, mem_rnw, mem_isData, mem_addressData, mem_reqsize, mem_writeMask, mem_dataWrite, ce)
      variable address : unsigned(28 downto 0);
   begin
   
      address := mem_addressData(28 downto 0);
   
      -- exp1
      bus_exp1_read      <= '0';
      bus_exp1_write     <= '0';
      bus_exp1_addr      <= address(22 downto 0);
      bus_exp1_dataWrite <= mem_dataWrite;
      if (address >= 16#1F000000# and address < 16#1F800000#) then
         if (ce = '1' and mem_request = '1' and mem_isData = '1') then
            bus_exp1_read  <= mem_rnw;
            bus_exp1_write <= not mem_rnw;
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

   end process;
   
   dataFromBusses <= bus_exp1_dataRead or bus_pad_dataRead or bus_irq_dataRead or bus_dma_dataRead or bus_tmr_dataRead or bus_gpu_dataRead or bus_exp2_dataRead;
  
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         ram_ena   <= '0';
         mem_done  <= '0';
         reset_exe <= '0';
         
         if (loadExe = '1') then
            loadExe_latched <= '1';
         end if;
      
         if (reset = '1') then

            state <= IDLE;

         elsif (ce = '1') then
         
            case (state) is
               when IDLE =>
                  if (loadExe_latched = '1') then
                     
                     loadExe_latched <= '0';
                     state           <= EXEREADHEADER;
               
                  elsif (mem_request = '1') then
                  
                     if (mem_isData = '0') then
               
                        if (mem_addressInstr(28 downto 0) < 16#800000#) then -- RAM
                           ram_ena <= '1';
                           ram_128 <= '0';
                           ram_rnw <= '1';
                           ram_Adr <= "00" & std_logic_vector(mem_addressInstr(20 downto 0));
                           state   <= READRAM;
                           if (mem_isCache = '1') then
                              ram_Adr(3 downto 0) <= (others => '0');
                              state               <= READCACHE;
                              waitcnt             <= 1;
                              ram_128             <= '1';
                           end if;
                        elsif (mem_addressInstr(28 downto 0) >= 16#1FC00000# and mem_addressInstr(28 downto 0) < 16#1FC80000#) then -- BIOS
                           ram_ena <= '1';
                           ram_128 <= '0';
                           ram_rnw <= '1';
                           ram_Adr <= "01" & "00" & std_logic_vector(mem_addressInstr(18 downto 0));
                           state   <= READBIOS;
                           waitcnt <= 16;
                           if (mem_isCache = '1') then
                              ram_Adr(3 downto 0) <= (others => '0');
                              state               <= READCACHE;
                              waitcnt             <= 87;
                              ram_128             <= '1';
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
                              state   <= READRAM;
                           else
                              state   <= WRITERAM;
                           end if;
                           ram_be        <= mem_writeMask;
                           ram_dataWrite <= mem_dataWrite;
                        elsif (ram_rnw = '1' and mem_addressData(28 downto 0) >= 16#1FC00000# and mem_addressData(28 downto 0) < 16#1FC80000#) then -- BIOS
                           ram_ena <= '1';
                           ram_128 <= '0';
                           ram_rnw <= '1';
                           ram_Adr <= "01" & "00" & std_logic_vector(mem_addressData(18 downto 0));
                           state   <= READBIOS;
                           case (mem_reqsize) is
                              when "00" => waitcnt <= 1;
                              when "01" => waitcnt <= 4;
                              when "10" => waitcnt <= 16;
                              when others => null;
                           end case;
                        else
                           state <= BUSACTION;
                        end if;
            
                     end if;
                     
                  end if;
                  
               when READRAM =>
                  if (ram_done = '1') then
                     if (ram_Adr(0) = '1') then
                        mem_dataRead <= x"00" & ram_dataRead(31 downto 8);
                     else
                        mem_dataRead <= ram_dataRead(31 downto 0);
                     end if;
                     mem_done     <= '1';
                     state        <= IDLE;
                  end if;       

               when READCACHE =>
                  if (ram_done = '1') then
                     mem_dataCache <= ram_dataRead;
                     if (NOMEMWAIT = '1') then
                        mem_done <= '1';
                        state    <= IDLE;
                     else
                        state    <= WAITING;
                     end if;
                  end if;                       
                  
               when WRITERAM =>
                  if (ram_done = '1') then
                     --state <= CHECKRAM;
                     --ram_ena <= '1';
                     --ram_rnw <= '1';
                     mem_done     <= '1';
                     state        <= IDLE;
                  end if;
                  
               --when CHECKRAM =>
               --   if (ram_done = '1') then
               --      mem_done     <= '1';
               --      state        <= IDLE;
               --      if (ram_be(0) = '1' and ram_dataRead( 7 downto  0) /= ram_dataWrite( 7 downto  0)) then state <= ERRORRAM; end if;
               --      if (ram_be(1) = '1' and ram_dataRead(15 downto  8) /= ram_dataWrite(15 downto  8)) then state <= ERRORRAM; end if;
               --      if (ram_be(2) = '1' and ram_dataRead(23 downto 16) /= ram_dataWrite(23 downto 16)) then state <= ERRORRAM; end if;
               --      if (ram_be(3) = '1' and ram_dataRead(31 downto 24) /= ram_dataWrite(31 downto 24)) then state <= ERRORRAM; end if;
               --   end if;
               --
               --when ERRORRAM =>
               --   report "should never happen" severity failure; 
               --   ram_Adr <= (others => '1');
                  
               when READBIOS =>
                  if (ram_done = '1') then
                     if (ram_Adr(0) = '1') then
                        mem_dataRead <= x"00" & ram_dataRead(31 downto 8);
                     else
                        mem_dataRead <= ram_dataRead(31 downto 0);
                     end if;
                     if (NOMEMWAIT = '1') then
                        mem_done <= '1';
                        state    <= IDLE;
                     else
                        state    <= WAITING;
                     end if;
                  end if;
                  
               when BUSACTION =>
                  mem_dataRead <= dataFromBusses;
                  mem_done     <= '1';
                  state        <= IDLE;
                  
               when WAITING =>
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     mem_done <= '1';
                     state    <= IDLE;
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
                        state     <= IDLE;
                        reset_exe <= '1';
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

         end if;
      end if;
   end process;
   

end architecture;





