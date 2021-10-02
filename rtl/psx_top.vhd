library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pProc_bus.all;
use work.pexport.all;

entity psx_top is
   generic
   (
      is_simu               : std_logic := '0';
      REPRODUCIBLEGPUTIMING : std_logic := '0'
   );
   port 
   (
      clk1x                 : in  std_logic;  
      clk2x                 : in  std_logic;   
      reset                 : in  std_logic; 
      -- commands 
      loadExe               : in  std_logic;
      -- RAM/BIOS interface      
      ram_refresh           : out std_logic;
      ram_dataWrite         : out std_logic_vector(31 downto 0);
      ram_dataRead          : in  std_logic_vector(127 downto 0);
      ram_Adr               : out std_logic_vector(22 downto 0);
      ram_be                : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw               : out std_logic;
      ram_ena               : out std_logic;
      ram_128               : out std_logic;
      ram_done              : in  std_logic;
      ram_reqprocessed      : in  std_logic;
      ram_idle              : in  std_logic;
      -- vram interface
      vram_BUSY             : in  std_logic;                    
      vram_DOUT             : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY       : in  std_logic;
      vram_BURSTCNT         : out std_logic_vector(7 downto 0) := (others => '0'); 
      vram_ADDR             : out std_logic_vector(19 downto 0) := (others => '0');                       
      vram_DIN              : out std_logic_vector(63 downto 0) := (others => '0');
      vram_BE               : out std_logic_vector(7 downto 0) := (others => '0'); 
      vram_WE               : out std_logic := '0';
      vram_RD               : out std_logic := '0'; 
      hsync                 : out std_logic;
      vsync                 : out std_logic;
      hblank                : out std_logic;
      vblank                : out std_logic;
      DisplayWidth          : out unsigned( 9 downto 0);
      DisplayHeight         : out unsigned( 8 downto 0);
      DisplayOffsetX        : out unsigned( 9 downto 0);
      DisplayOffsetY        : out unsigned( 8 downto 0);
      -- Keys - all active high   
      KeyTriangle           : in  std_logic; 
      KeyCircle             : in  std_logic; 
      KeyCross              : in  std_logic; 
      KeySquare             : in  std_logic;
      KeySelect             : in  std_logic;
      KeyStart              : in  std_logic;
      KeyRight              : in  std_logic;
      KeyLeft               : in  std_logic;
      KeyUp                 : in  std_logic;
      KeyDown               : in  std_logic;
      KeyR1                 : in  std_logic;
      KeyR2                 : in  std_logic;
      KeyR3                 : in  std_logic;
      KeyL1                 : in  std_logic;
      KeyL2                 : in  std_logic;
      KeyL3                 : in  std_logic;
      Analog1X              : in  signed(7 downto 0);
      Analog1Y              : in  signed(7 downto 0);
      Analog2X              : in  signed(7 downto 0);
      Analog2Y              : in  signed(7 downto 0);                 
      -- sound                            
      sound_out_left        : out std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right       : out std_logic_vector(15 downto 0) := (others => '0')
   );
end entity;

architecture arch of psx_top is

   signal reset_intern           : std_logic := '0';
   signal reset_exe              : std_logic;
   
   signal ce                     : std_logic := '0';
   signal clk1xToggle            : std_logic := '0';
   signal clk1xToggle2X          : std_logic := '0';
   signal clk2xIndex             : std_logic := '0';
   
   -- Busses
   signal bus_exp1_addr          : unsigned(22 downto 0); 
   --signal bus_exp1_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_exp1_read          : std_logic;
   --signal bus_exp1_write         : std_logic;
   signal bus_exp1_dataRead      : std_logic_vector(31 downto 0);
   
   signal bus_memc_addr          : unsigned(5 downto 0); 
   signal bus_memc_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_memc_read          : std_logic;
   signal bus_memc_write         : std_logic;
   signal bus_memc_dataRead      : std_logic_vector(31 downto 0);
   
   signal bus_pad_addr           : unsigned(3 downto 0); 
   signal bus_pad_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_pad_read           : std_logic;
   signal bus_pad_write          : std_logic;
   signal bus_pad_writeMask      : std_logic_vector(3 downto 0);
   signal bus_pad_dataRead       : std_logic_vector(31 downto 0);   
   
   signal bus_sio_addr           : unsigned(3 downto 0); 
   signal bus_sio_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_sio_read           : std_logic;
   signal bus_sio_write          : std_logic;
   signal bus_sio_writeMask      : std_logic_vector(3 downto 0);
   signal bus_sio_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_irq_addr           : unsigned(3 downto 0); 
   signal bus_irq_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_irq_read           : std_logic;
   signal bus_irq_write          : std_logic;
   signal bus_irq_dataRead       : std_logic_vector(31 downto 0);   
   
   signal bus_dma_addr           : unsigned(6 downto 0); 
   signal bus_dma_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_dma_read           : std_logic;
   signal bus_dma_write          : std_logic;
   signal bus_dma_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_tmr_addr           : unsigned(5 downto 0); 
   signal bus_tmr_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_tmr_read           : std_logic;
   signal bus_tmr_write          : std_logic;
   signal bus_tmr_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_gpu_addr           : unsigned(3 downto 0); 
   signal bus_gpu_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_gpu_read           : std_logic;
   signal bus_gpu_write          : std_logic;
   signal bus_gpu_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_exp2_addr          : unsigned(12 downto 0); 
   signal bus_exp2_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_exp2_read          : std_logic;
   signal bus_exp2_write         : std_logic;
   signal bus_exp2_dataRead      : std_logic_vector(31 downto 0);
   signal bus_exp2_writeMask     : std_logic_vector(3 downto 0);
   
   -- Memory mux
   signal memMuxIdle             : std_logic;
   
   signal mem_request            : std_logic;
   signal mem_rnw                : std_logic; 
   signal mem_isData             : std_logic; 
   signal mem_isCache            : std_logic; 
   signal mem_addressInstr       : unsigned(31 downto 0); 
   signal mem_addressData        : unsigned(31 downto 0); 
   signal mem_reqsize            : unsigned(1 downto 0); 
   signal mem_writeMask          : std_logic_vector(3 downto 0);
   signal mem_dataWrite          : std_logic_vector(31 downto 0); 
   signal mem_dataRead           : std_logic_vector(31 downto 0); 
   signal mem_dataCache          : std_logic_vector(127 downto 0); 
   signal mem_done               : std_logic;
   
   signal ram_next_dma           : std_logic;
   signal ram_next_cpu           : std_logic;
   
   signal ram_cpu_dataWrite      : std_logic_vector(31 downto 0);
   signal ram_cpu_Adr            : std_logic_vector(22 downto 0);
   signal ram_cpu_be             : std_logic_vector(3 downto 0);
   signal ram_cpu_rnw            : std_logic;
   signal ram_cpu_ena            : std_logic;
   signal ram_cpu_128            : std_logic;
   signal ram_cpu_done           : std_logic;
   
   -- gpu
   signal hblank_intern          : std_logic;
   signal vblank_intern          : std_logic;
   
   -- irq
   signal irqRequest             : std_logic;
   signal irq_VBLANK             : std_logic;
   signal irq_GPU                : std_logic;
   signal irq_CDROM              : std_logic;
   signal irq_DMA                : std_logic;
   signal irq_TIMER0             : std_logic;
   signal irq_TIMER1             : std_logic;
   signal irq_TIMER2             : std_logic;
   signal irq_PAD                : std_logic;
   signal irq_SIO                : std_logic;
   signal irq_SPU                : std_logic;
   signal irq_LIGHTPEN           : std_logic;
   
   -- dma
   signal cpuPaused              : std_logic;
   signal dmaOn                  : std_logic;
   
   signal ram_dma_dataWrite      : std_logic_vector(31 downto 0);
   signal ram_dma_Adr            : std_logic_vector(22 downto 0);
   signal ram_dma_be             : std_logic_vector(3 downto 0);
   signal ram_dma_rnw            : std_logic;
   signal ram_dma_ena            : std_logic;
   signal ram_dma_128            : std_logic;
   signal ram_dma_done           : std_logic;
   
   signal gpu_dmaRequest         : std_logic;
   signal DMA_GPU_writeEna       : std_logic;
   signal DMA_GPU_readEna        : std_logic;
   signal DMA_GPU_write          : std_logic_vector(31 downto 0);
   signal DMA_GPU_read           : std_logic_vector(31 downto 0);
   
   -- cpu
   signal ce_intern              : std_logic := '0';
   signal ce_cpu                 : std_logic := '0';
   
   
   -- GTE
   signal gte_busy               : std_logic;
   signal gte_readAddr           : unsigned(5 downto 0);
   signal gte_readData           : unsigned(31 downto 0);
   signal gte_writeAddr          : unsigned(5 downto 0);
   signal gte_writeData          : unsigned(31 downto 0);
   signal gte_writeEna           : std_logic; 
   signal gte_cmdData            : unsigned(31 downto 0);
   signal gte_cmdEna             : std_logic; 

   -- export
   signal cpu_done               : std_logic; 
   signal new_export             : std_logic; 
   signal cpu_export             : cpu_export_type;
   signal export_8               : std_logic_vector(7 downto 0);
   signal export_16              : std_logic_vector(15 downto 0);
   signal export_32              : std_logic_vector(31 downto 0);
   signal export_irq             : unsigned(15 downto 0);
   signal export_gtm             : unsigned(11 downto 0);
   signal export_line            : unsigned(11 downto 0);
   signal export_gpus            : unsigned(31 downto 0);
   signal export_gobj            : unsigned(15 downto 0);
   
   
begin 

   sound_out_left   <= (others => '0');
   sound_out_right  <= (others => '0');
   
   -- reset
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         reset_intern <= reset or reset_exe;
      end if;
   end process;
   

   -- clock index
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         clk1xToggle <= not clk1xToggle;
      end if;
   end process;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         clk1xToggle2x <= clk1xToggle;
         clk2xIndex    <= '0';
         if (clk1xToggle2x = clk1xToggle) then
            clk2xIndex <= '1';
         end if;
      end if;
   end process;

   -- busses
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         bus_exp1_dataRead <= (others => '0');
         if (bus_exp1_read = '1') then
            bus_exp1_dataRead <= (others => '1');
         end if;
      
      end if;
   end process;
   
   -- ce generation
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         ce        <= '1';
         ce_cpu    <= '1';
      
         if (reset_intern = '1') then
            cpuPaused <= '0';
         else
      
            if ((cpuPaused = '1' and dmaOn = '1') or (dmaOn = '1' and memMuxIdle = '1' and mem_request = '0')) then
               cpuPaused <= '1';
               ce_cpu    <= '0';
            elsif (dmaOn = '0') then
               cpuPaused <= '0';
               ce_cpu    <= '1';
            end if;
            
         end if;
      end if;
   end process;
   
   imemctrl : entity work.memctrl
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,

      bus_addr             => bus_memc_addr,     
      bus_dataWrite        => bus_memc_dataWrite,
      bus_read             => bus_memc_read,     
      bus_write            => bus_memc_write,    
      bus_dataRead         => bus_memc_dataRead
   );

   ijoypad: entity work.joypad
   port map 
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      irqRequest           => irq_PAD,
      
      KeyTriangle          => KeyTriangle,           
      KeyCircle            => KeyCircle,           
      KeyCross             => KeyCross,           
      KeySquare            => KeySquare,           
      KeySelect            => KeySelect,      
      KeyStart             => KeyStart,       
      KeyRight             => KeyRight,       
      KeyLeft              => KeyLeft,        
      KeyUp                => KeyUp,          
      KeyDown              => KeyDown,        
      KeyR1                => KeyR1,           
      KeyR2                => KeyR2,           
      KeyR3                => KeyR3,           
      KeyL1                => KeyL1,           
      KeyL2                => KeyL2,           
      KeyL3                => KeyL3,           
      Analog1X             => Analog1X,       
      Analog1Y             => Analog1Y,       
      Analog2X             => Analog2X,       
      Analog2Y             => Analog2Y,
      
      bus_addr             => bus_pad_addr,     
      bus_dataWrite        => bus_pad_dataWrite,
      bus_read             => bus_pad_read,     
      bus_write            => bus_pad_write,    
      bus_writeMask        => bus_pad_writeMask,   
      bus_dataRead         => bus_pad_dataRead
   );
   
   isio : entity work.sio
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      bus_addr             => bus_sio_addr,     
      bus_dataWrite        => bus_sio_dataWrite,
      bus_read             => bus_sio_read,     
      bus_write            => bus_sio_write,    
      bus_writeMask        => bus_sio_writeMask,
      bus_dataRead         => bus_sio_dataRead 
   );
   
   irq_GPU       <= '0'; -- todo
   irq_CDROM     <= '0'; -- todo
   irq_SIO       <= '0'; -- todo
   irq_SPU       <= '0'; -- todo
   irq_LIGHTPEN  <= '0'; -- todo

   iirq : entity work.irq
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      irq_VBLANK           => irq_VBLANK,
      irq_GPU              => irq_GPU,     
      irq_CDROM            => irq_CDROM,   
      irq_DMA              => irq_DMA,     
      irq_TIMER0           => irq_TIMER0,  
      irq_TIMER1           => irq_TIMER1,  
      irq_TIMER2           => irq_TIMER2,  
      irq_PAD              => irq_PAD,     
      irq_SIO              => irq_SIO,     
      irq_SPU              => irq_SPU,     
      irq_LIGHTPEN         => irq_LIGHTPEN,
      
      bus_addr             => bus_irq_addr,     
      bus_dataWrite        => bus_irq_dataWrite,
      bus_read             => bus_irq_read,     
      bus_write            => bus_irq_write,    
      bus_dataRead         => bus_irq_dataRead,
      
      irqRequest           => irqRequest,
      
      export_irq           => export_irq
   );
   
   idma : entity work.dma
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      cpuPaused            => cpuPaused,
      dmaOn                => dmaOn,
      irqOut               => irq_DMA,
      
      ram_refresh          => ram_refresh,  
      ram_dataWrite        => ram_dma_dataWrite,
      ram_dataRead         => ram_dataRead, 
      ram_Adr              => ram_dma_Adr,      
      ram_be               => ram_dma_be,       
      ram_rnw              => ram_dma_rnw,      
      ram_ena              => ram_dma_ena,      
      ram_128              => ram_dma_128,      
      ram_done             => ram_dma_done, 
      ram_reqprocessed     => ram_reqprocessed,
      ram_idle             => ram_idle,
      
      gpu_dmaRequest       => gpu_dmaRequest,  
      DMA_GPU_writeEna     => DMA_GPU_writeEna,
      DMA_GPU_readEna      => DMA_GPU_readEna, 
      DMA_GPU_write        => DMA_GPU_write,   
      DMA_GPU_read         => DMA_GPU_read,   
      
      bus_addr             => bus_dma_addr,     
      bus_dataWrite        => bus_dma_dataWrite,
      bus_read             => bus_dma_read,     
      bus_write            => bus_dma_write,    
      bus_dataRead         => bus_dma_dataRead
   );
   
   ram_dataWrite <= ram_dma_dataWrite when (cpuPaused = '1') else ram_cpu_dataWrite;
   ram_Adr       <= ram_dma_Adr       when (cpuPaused = '1') else ram_cpu_Adr;      
   ram_be        <= ram_dma_be        when (cpuPaused = '1') else ram_cpu_be;       
   ram_rnw       <= ram_dma_rnw       when (cpuPaused = '1') else ram_cpu_rnw;      
   ram_ena       <= ram_dma_ena       when (cpuPaused = '1') else ram_cpu_ena;      
   ram_128       <= ram_dma_128       when (cpuPaused = '1') else ram_cpu_128;      
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (ram_ena = '1') then
            ram_next_dma <= '0';
            ram_next_cpu <= '0';
            if (cpuPaused = '1') then
               ram_next_dma <= '1';
            else
               ram_next_cpu <= '1';
            end if;
         end if;
      
      end if;
   end process;
   
   ram_dma_done <= ram_done and ram_next_dma;
   ram_cpu_done <= ram_done and ram_next_cpu;
   
   itimer : entity work.timer
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      dotclock             => '0', -- todo
      hblank               => hblank_intern,
      vblank               => vblank_intern,
      
      irqRequest0          => irq_TIMER0,
      irqRequest1          => irq_TIMER1,
      irqRequest2          => irq_TIMER2,
      
      bus_addr             => bus_tmr_addr,     
      bus_dataWrite        => bus_tmr_dataWrite,
      bus_read             => bus_tmr_read,     
      bus_write            => bus_tmr_write,       
      bus_dataRead         => bus_tmr_dataRead
   );
   
   hblank <= hblank_intern;
   vblank <= vblank_intern;
   
   igpu : entity work.gpu
   generic map
   (
      REPRODUCIBLEGPUTIMING => REPRODUCIBLEGPUTIMING
   )
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      ce                   => ce,   
      reset                => reset_intern,
      
      isPal                => '1',
      
      bus_addr             => bus_gpu_addr,     
      bus_dataWrite        => bus_gpu_dataWrite,
      bus_read             => bus_gpu_read,     
      bus_write            => bus_gpu_write,    
      bus_dataRead         => bus_gpu_dataRead, 
      
      gpu_dmaRequest       => gpu_dmaRequest,  
      DMA_GPU_writeEna     => DMA_GPU_writeEna,
      DMA_GPU_readEna      => DMA_GPU_readEna, 
      DMA_GPU_write        => DMA_GPU_write,   
      DMA_GPU_read         => DMA_GPU_read,  
      
      irq_VBLANK           => irq_VBLANK,
      
      vram_BUSY            => vram_BUSY,      
      vram_DOUT            => vram_DOUT,      
      vram_DOUT_READY      => vram_DOUT_READY,
      vram_BURSTCNT        => vram_BURSTCNT,  
      vram_ADDR            => vram_ADDR,      
      vram_DIN             => vram_DIN,       
      vram_BE              => vram_BE,        
      vram_WE              => vram_WE,        
      vram_RD              => vram_RD, 

      hsync                => hsync, 
      vsync                => vsync, 
      hblank               => hblank_intern,
      vblank               => vblank_intern,
      DisplayWidth         => DisplayWidth, 
      DisplayHeight        => DisplayHeight,
      DisplayOffsetX       => DisplayOffsetX,
      DisplayOffsetY       => DisplayOffsetY,
      
      export_gtm           => export_gtm,
      export_line          => export_line,
      export_gpus          => export_gpus,
      export_gobj          => export_gobj
   );
   
   iexp2 : entity work.exp2
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      bus_addr             => bus_exp2_addr,     
      bus_dataWrite        => bus_exp2_dataWrite,
      bus_read             => bus_exp2_read,     
      bus_write            => bus_exp2_write,    
      bus_writeMask        => bus_exp2_writeMask, 
      bus_dataRead         => bus_exp2_dataRead
   );

   imemorymux : entity work.memorymux
   generic map
   (
      NOMEMWAIT => is_simu
   )
   port map
   (
      clk1x                => clk1x,
      ce                   => ce_cpu,   
      reset                => reset_intern,
      
      isIdle               => memMuxIdle,
         
      loadExe              => loadExe,
      reset_exe            => reset_exe,
            
      ram_dataWrite        => ram_cpu_dataWrite,
      ram_dataRead         => ram_dataRead, 
      ram_Adr              => ram_cpu_Adr,  
      ram_be               => ram_cpu_be,        
      ram_rnw              => ram_cpu_rnw,      
      ram_ena              => ram_cpu_ena,      
      ram_128              => ram_cpu_128,      
      ram_done             => ram_cpu_done,     
      
      mem_request          => mem_request,  
      mem_rnw              => mem_rnw,      
      mem_isData           => mem_isData,      
      mem_isCache          => mem_isCache,      
      mem_addressInstr     => mem_addressInstr,  
      mem_addressData      => mem_addressData,  
      mem_reqsize          => mem_reqsize,  
      mem_writeMask        => mem_writeMask,
      mem_dataWrite        => mem_dataWrite,
      mem_dataRead         => mem_dataRead, 
      mem_dataCache        => mem_dataCache, 
      mem_done             => mem_done,

      bus_exp1_addr        => bus_exp1_addr,   
      --bus_exp1_dataWrite   => bus_exp1_dataWrite,
      bus_exp1_read        => bus_exp1_read,   
      --bus_exp1_write       => bus_exp1_write,  
      bus_exp1_dataRead    => bus_exp1_dataRead,
      
      bus_memc_addr        => bus_memc_addr,     
      bus_memc_dataWrite   => bus_memc_dataWrite,
      bus_memc_read        => bus_memc_read,     
      bus_memc_write       => bus_memc_write,    
      bus_memc_dataRead    => bus_memc_dataRead,   
      
      bus_pad_addr         => bus_pad_addr,     
      bus_pad_dataWrite    => bus_pad_dataWrite,
      bus_pad_read         => bus_pad_read,     
      bus_pad_write        => bus_pad_write,    
      bus_pad_writeMask    => bus_pad_writeMask,
      bus_pad_dataRead     => bus_pad_dataRead,       
      
      bus_sio_addr         => bus_sio_addr,     
      bus_sio_dataWrite    => bus_sio_dataWrite,
      bus_sio_read         => bus_sio_read,     
      bus_sio_write        => bus_sio_write,    
      bus_sio_writeMask    => bus_sio_writeMask,
      bus_sio_dataRead     => bus_sio_dataRead, 

      bus_irq_addr         => bus_irq_addr,     
      bus_irq_dataWrite    => bus_irq_dataWrite,
      bus_irq_read         => bus_irq_read,     
      bus_irq_write        => bus_irq_write,    
      bus_irq_dataRead     => bus_irq_dataRead,       
      
      bus_dma_addr         => bus_dma_addr,     
      bus_dma_dataWrite    => bus_dma_dataWrite,
      bus_dma_read         => bus_dma_read,     
      bus_dma_write        => bus_dma_write,    
      bus_dma_dataRead     => bus_dma_dataRead,     

      bus_tmr_addr         => bus_tmr_addr,     
      bus_tmr_dataWrite    => bus_tmr_dataWrite,
      bus_tmr_read         => bus_tmr_read,     
      bus_tmr_write        => bus_tmr_write,    
      bus_tmr_dataRead     => bus_tmr_dataRead,       
      
      bus_gpu_addr         => bus_gpu_addr,     
      bus_gpu_dataWrite    => bus_gpu_dataWrite,
      bus_gpu_read         => bus_gpu_read,     
      bus_gpu_write        => bus_gpu_write,    
      bus_gpu_dataRead     => bus_gpu_dataRead,
      
      bus_exp2_addr        => bus_exp2_addr,     
      bus_exp2_dataWrite   => bus_exp2_dataWrite,
      bus_exp2_read        => bus_exp2_read,     
      bus_exp2_write       => bus_exp2_write,    
      bus_exp2_dataRead    => bus_exp2_dataRead, 
      bus_exp2_writeMask   => bus_exp2_writeMask
   );
   
   icpu : entity work.cpu
   port map
   (
      clk1x             => clk1x,
      clk2x             => clk2x,
      ce                => ce_cpu,   
      reset             => reset_intern,
         
      irqRequest        => irqRequest,
         
      mem_request       => mem_request,  
      mem_rnw           => mem_rnw,      
      mem_isData        => mem_isData,      
      mem_isCache       => mem_isCache,      
      mem_addressInstr  => mem_addressInstr,  
      mem_addressData   => mem_addressData,  
      mem_reqsize       => mem_reqsize,  
      mem_writeMask     => mem_writeMask,
      mem_dataWrite     => mem_dataWrite,
      mem_dataRead      => mem_dataRead, 
      mem_dataCache     => mem_dataCache, 
      mem_done          => mem_done,
      
      gte_busy          => gte_busy,     
      gte_readAddr      => gte_readAddr, 
      gte_readData      => gte_readData, 
      gte_writeAddr     => gte_writeAddr,
      gte_writeData     => gte_writeData,
      gte_writeEna      => gte_writeEna, 
      gte_cmdData       => gte_cmdData,  
      gte_cmdEna        => gte_cmdEna,   
      
      cpu_done          => cpu_done,  
      cpu_export        => cpu_export
   );
   
   igte : entity work.gte
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => reset,     
      
      gte_busy             => gte_busy,     
      gte_readAddr         => gte_readAddr, 
      gte_readData         => gte_readData, 
      gte_readEna          => '0',
      gte_writeAddr        => gte_writeAddr,
      gte_writeData        => gte_writeData,
      gte_writeEna         => gte_writeEna, 
      gte_cmdData          => gte_cmdData,  
      gte_cmdEna           => gte_cmdEna  
   );
   
   -- export
-- synthesis translate_off
   gexport : if is_simu = '1' generate
   begin
   
      new_export <= cpu_done; 
      
      iexport : entity work.export
      port map
      (
         clk            => clk1x,
         ce             => ce,
         reset          => reset_intern,
         
         new_export     => cpu_done,
         export_cpu     => cpu_export,
         
         export_irq     => export_irq,
         
         export_gtm     => export_gtm,
         export_line    => export_line,
         export_gpus    => export_gpus,
         export_gobj    => export_gobj,
         
         export_8       => export_8,
         export_16      => export_16,
         export_32      => export_32
      );
   
   
   end generate;
-- synthesis translate_on
   
end architecture;





