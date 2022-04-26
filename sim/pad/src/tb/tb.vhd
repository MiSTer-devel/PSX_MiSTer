library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
--use IEEE.std_logic_textio.all; 
use STD.textio.all;

library psx;

entity etb  is
end entity;

architecture arch of etb is

   signal clk1x               : std_logic := '1';
   signal reset_in            : std_logic := '1';
   
   signal selected            : std_logic := '1';
   signal actionNext          : std_logic := '0';
   signal transmitting        : std_logic := '0';
   signal transmitValue       : std_logic_vector(7 downto 0);
   
   signal receiveValid        : std_logic;
   signal receiveBuffer       : std_logic_vector(7 downto 0);
   
   -- testbench
   signal cmdCount            : integer := 0;
   signal clkCount            : integer := 0;
   
begin

   clk1x  <= not clk1x  after 15 ns;
   
   reset_in  <= '0' after 3000 ns;
   
   ijoypad_pad : entity psx.joypad_pad
   port map
   (
      clk1x                => clk1x,
      ce                   => '1',
      reset                => reset_in,
      
      joypad.PadPortEnable => '1',
      joypad.PadPortAnalog => '0',
      joypad.PadPortMouse  => '0',
      joypad.PadPortGunCon => '0',
      joypad.PadPortNeGcon => '0',
      joypad.WheelMap      => '0',

      joypad.KeyTriangle   => '0',
      joypad.KeyCircle     => '0',
      joypad.KeyCross      => '0',
      joypad.KeySquare     => '0',
      joypad.KeySelect     => '0',
      joypad.KeyStart      => '0',
      joypad.KeyRight      => '0',
      joypad.KeyLeft       => '0',
      joypad.KeyUp         => '0',
      joypad.KeyDown       => '0',
      joypad.KeyR1         => '0',
      joypad.KeyR2         => '0',
      joypad.KeyR3         => '0',
      joypad.KeyL1         => '0',
      joypad.KeyL2         => '0',
      joypad.KeyL3         => '0',
      joypad.Analog1X      => x"00",
      joypad.Analog1Y      => x"00",
      joypad.Analog2X      => x"00",
      joypad.Analog2Y      => x"00",

      rumble               => open,

      isPal                => '0',
      
      selected             => selected,     
      actionNext           => actionNext,   
      transmitting         => transmitting, 
      transmitValue        => transmitValue,
      
      isActive             => open,
      slotIdle             => '1',
      
      receiveValid         => receiveValid, 
      receiveBuffer        => receiveBuffer,
      ack                  => open,

      MouseEvent           => '0',
      MouseLeft            => '0',
      MouseRight           => '0',
      MouseX               => "000000000",
      MouseY               => "000000000",
      GunX                 => "00000000",
      GunY_scanlines       => "000000000",
      GunAimOffscreen      => '0'
   );
   
   process
      file infile          : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable inLine      : LINE;
      variable para_type   : std_logic_vector(7 downto 0);
      variable para_addr   : std_logic_vector(7 downto 0);
      variable para_data   : std_logic_vector(7 downto 0);
      variable space       : character;
   begin
      
      wait for 10 us;
         
      file_open(f_status, infile, "R:\pad_test_duck.txt", read_mode);
      
      while (not endfile(infile)) loop
         
         readline(infile,inLine);
         
         HREAD(inLine, para_type);
         Read(inLine, space);
         HREAD(inLine, para_addr);
         Read(inLine, space);
         HREAD(inLine, para_data);
         
         if (para_type = x"08") then
            selected <= '0';
            wait until rising_edge(clk1x);
            selected <= '1';
            wait until rising_edge(clk1x);
         end if;
         
         if (para_type = x"09") then
            actionNext    <= '1';
            transmitting  <= '1';
            transmitValue <= para_addr;
            wait until rising_edge(clk1x);
            actionNext    <= '0';
            transmitting  <= '0';
            wait until rising_edge(clk1x);
         end if;
         
         wait until rising_edge(clk1x);
         wait until rising_edge(clk1x);
         wait until rising_edge(clk1x);
      end loop;
      
      file_close(infile);
      
      wait for 1 us;
      
      if (cmdCount >= 0) then
         report "DONE" severity failure;
      end if;
      
   end process;
   
   goutput : if 1 = 1 generate
      signal outputCnt : unsigned(31 downto 0) := (others => '0'); 
   begin
      process
         constant WRITETIME            : std_logic := '1';
         
         file outfile                  : text;
         variable f_status             : FILE_OPEN_STATUS;
         variable line_out             : line;
            
         variable newoutputCnt         : unsigned(31 downto 0);
      begin
   
         file_open(f_status, outfile, "R:\\debug_pad_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\debug_pad_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);

            newoutputCnt := outputCnt;
            
            if (selected = '0') then
               write(line_out, string'("RESETCONTROLLER: 00 0000"));
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if;    

            if (actionNext = '1') then
               wait until rising_edge(clk1x);
               write(line_out, string'("TRANSFER: "));
               write(line_out, to_hstring(transmitValue));
               write(line_out, string'(" 00")); 
               if (receiveValid = '1') then
                  write(line_out, to_hstring(receiveBuffer));
               else
                  write(line_out, string'("FF")); 
               end if;
               writeline(outfile, line_out);
               newoutputCnt := newoutputCnt + 1;
            end if;              

            outputCnt <= newoutputCnt;
           
         end loop;
         
      end process;
   
   end generate goutput;
   
end architecture;


