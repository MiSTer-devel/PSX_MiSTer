library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity gpu_fillVram is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      REPRODUCIBLEGPUTIMING: in  std_logic;
      
      interlacedDrawing    : in  std_logic;
      activeLineLSB        : in  std_logic;
      
      proc_idle            : in  std_logic;
      fifo_Valid           : in  std_logic;
      fifo_data            : in  std_logic_vector(31 downto 0);
      requestFifo          : out std_logic := '0';
      done                 : out std_logic := '0';
      CmdDone              : out std_logic := '0';
      
      pixelStall           : in  std_logic;
      pixelColor           : out std_logic_vector(15 downto 0);
      pixelAddr            : out unsigned(19 downto 0);
      pixelWrite           : out std_logic
   );
end entity;

architecture arch of gpu_fillVram is
   
   type tState is
   (
      IDLE,
      REQUESTWORD2,
      REQUESTWORD3,
      WRITING,
      WAITING
   );
   signal state   : tState := IDLE;
      
   signal color   : std_logic_vector(14 downto 0);
   signal x1      : unsigned(9 downto 0);
   signal y1      : unsigned(8 downto 0);   
   signal widt    : unsigned(10 downto 0);
   signal heig    : unsigned(8 downto 0);
   
   signal x       : unsigned(10 downto 0);
   signal y       : unsigned(8 downto 0);
   
   signal timer   : integer;
   signal timeCnt : integer;
  
begin 

   requestFifo <= '1' when (state = REQUESTWORD2 or state = REQUESTWORD3) else '0';

   -- fill VRAM
   process (clk2x)
      variable row     : unsigned(8 downto 0);
      variable col     : unsigned(10 downto 0);
      variable lineEnd : std_logic;
   begin
      if rising_edge(clk2x) then

         if (reset = '1') then
         
            state <= IDLE;
         
         elsif (ce = '1') then
         
            pixelColor <= (others => '0');
            pixelAddr  <= (others => '0');
            pixelWrite <= '0';
            
            done       <= '0';
            CmdDone    <= '0';
         
            case (state) is
            
               when IDLE =>
                  timer <= 0;
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 24) = x"02") then
                     state <= REQUESTWORD2;
                     color( 4 downto  0) <= fifo_data( 7 downto  3);
                     color( 9 downto  5) <= fifo_data(15 downto 11);
                     color(14 downto 10) <= fifo_data(23 downto 19);
                  end if;
            
               when REQUESTWORD2 =>
                  if (fifo_Valid = '1') then
                     state <= REQUESTWORD3;  
                     x1    <= unsigned(fifo_data( 9 downto  4) & x"0");
                     y1    <= unsigned(fifo_data(24 downto 16));
                  end if;
            
               when REQUESTWORD3 =>
                  if (fifo_Valid = '1') then
                     CmdDone <= '1';
                     state   <= WRITING;
                     widt    <= resize(unsigned(fifo_data( 9 downto  0)), 11) + 15;
                     widt(3 downto 0) <= x"0";
                     heig    <= unsigned(fifo_data(24 downto 16));
                     x       <= (others => '0');
                     y       <= (others => '0');
                     if (unsigned(fifo_data( 9 downto  0)) = 0 or unsigned(fifo_data(24 downto 16)) = 0) then
                        state <= IDLE;
                        done  <= '1';
                     end if;
                  end if;
               
               when WRITING =>
                  timer   <= timer + 1;
                  timeCnt <= 46 + to_integer(widt * heig);
                  if (pixelStall = '0') then
                  
                     lineEnd := '0';
                  
                     if (interlacedDrawing = '0' or (activeLineLSB /= y(0))) then
                     
                        row := y1 + y;
                        col := x1 + x;
      
                        pixelWrite <= '1';
                        pixelAddr  <= row & col(9 downto 0) & '0';
                        pixelColor <= '0' & color;
                        
                        if (x + 4 < widt) then
                           x <= x + 4;
                        else
                           lineEnd := '1';
                        end if;
                     
                     else
                        
                        lineEnd := '1';
                        
                     end if;
                     
                     if (lineEnd = '1') then
                        x <= (others => '0');
                        if (y + 1 < heig) then
                           y <= y + 1;
                        else
                           if (REPRODUCIBLEGPUTIMING = '1') then
                              state <= WAITING;
                           else
                              state <= IDLE;
                              done  <= '1';
                           end if;
                        end if;
                     end if;
                        
                  end if;
                  
               when WAITING =>
                  timer <= timer + 1;
                  if (timer + 1 >= timeCnt) then
                     state <= IDLE;
                     done  <= '1';
                  end if;
            
            end case;
         
         end if;
         
      end if;
   end process; 


end architecture;





