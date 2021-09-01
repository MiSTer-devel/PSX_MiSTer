library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pProc_bus.all;
use work.pexport.all;

entity psx_top is
   generic
   (
      is_simu               : std_logic := '0'
   );
   port 
   (
      clk1x                 : in  std_logic;  
      clk2x                 : in  std_logic;  
      reset                 : in  std_logic; 
      -- commands 
      loadExe               : in  std_logic;
      -- RAM/BIOS interface      
      ram_dataWrite         : out std_logic_vector(31 downto 0);
      ram_dataRead          : in  std_logic_vector(127 downto 0);
      ram_Adr               : out std_logic_vector(22 downto 0);
      ram_be                : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw               : out std_logic;
      ram_ena               : out std_logic;
      ram_128               : out std_logic;
      ram_done              : in  std_logic;
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
   
   signal ce                     : std_logic := '1';
   signal clk1xToggle            : std_logic := '0';
   signal clk1xToggle2X          : std_logic := '0';
   signal clk2xIndex             : std_logic := '0';
   
   -- Busses
   signal bus_exp1_addr          : unsigned(22 downto 0); 
   signal bus_exp1_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_exp1_read          : std_logic;
   signal bus_exp1_write         : std_logic;
   signal bus_exp1_dataRead      : std_logic_vector(31 downto 0);
   
   signal bus_gpu_addr           : unsigned(3 downto 0); 
   signal bus_gpu_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_gpu_read           : std_logic;
   signal bus_gpu_write          : std_logic;
   signal bus_gpu_dataRead       : std_logic_vector(31 downto 0);
   
   -- Memory mux
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
   
   -- export
   signal cpu_done               : std_logic; 
   signal new_export             : std_logic; 
   signal cpu_export             : cpu_export_type;
   signal export_8               : std_logic_vector(7 downto 0);
   signal export_16              : std_logic_vector(15 downto 0);
   signal export_32              : std_logic_vector(31 downto 0);
   signal export_gtm             : unsigned(11 downto 0);
   signal export_line            : unsigned(11 downto 0);
   signal export_gpus            : unsigned(31 downto 0);
   
   
begin 

   sound_out_left   <= (others => '0');
   sound_out_right  <= (others => '0');
   
   ce <= '1';
   
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
   
   igpu : entity work.gpu
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
      hblank               => hblank,
      vblank               => vblank,
      
      export_gtm           => export_gtm,
      export_line          => export_line,
      export_gpus          => export_gpus
   );
   

   imemorymux : entity work.memorymux
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
         
      loadExe              => loadExe,
      reset_exe            => reset_exe,
            
      ram_dataWrite        => ram_dataWrite,
      ram_dataRead         => ram_dataRead, 
      ram_Adr              => ram_Adr,  
      ram_be               => ram_be,        
      ram_rnw              => ram_rnw,      
      ram_ena              => ram_ena,      
      ram_128              => ram_128,      
      ram_done             => ram_done,     
      
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
      bus_exp1_dataWrite   => bus_exp1_dataWrite,
      bus_exp1_read        => bus_exp1_read,   
      bus_exp1_write       => bus_exp1_write,  
      bus_exp1_dataRead    => bus_exp1_dataRead,

      bus_gpu_addr         => bus_gpu_addr,     
      bus_gpu_dataWrite    => bus_gpu_dataWrite,
      bus_gpu_read         => bus_gpu_read,     
      bus_gpu_write        => bus_gpu_write,    
      bus_gpu_dataRead     => bus_gpu_dataRead
   );
   
   
   icpu : entity work.cpu
   port map
   (
      clk1x             => clk1x,
      ce                => ce,   
      reset             => reset_intern,
         
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
   
      cpu_done          => cpu_done,  
      cpu_export        => cpu_export
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
         
         export_irq     => x"00",
         
         export_gtm     => export_gtm,
         export_line    => export_line,
         export_gpus    => export_gpus,
         
         export_8       => export_8,
         export_16      => export_16,
         export_32      => export_32
      );
   
   
   end generate;
-- synthesis translate_on
   
end architecture;





