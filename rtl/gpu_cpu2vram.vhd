library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity gpu_cpu2vram is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      drawer_reset         : in  std_logic;
      
      DrawPixelsMask       : in  std_logic;
      SetMask              : in  std_logic;
      errorMASK            : out std_logic;
      
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

architecture arch of gpu_cpu2vram is
   
   type tState is
   (
      IDLE,
      REQUESTWORD2,
      REQUESTWORD3,
      WRITING
   );
   signal state : tState := IDLE;
   
   signal copyDstX     : unsigned(9 downto 0);
   signal copyDstY     : unsigned(8 downto 0);   
   signal copySizeX    : unsigned(10 downto 0);
   signal copySizeY    : unsigned(9 downto 0);
                       
   signal x            : unsigned(10 downto 0);
   signal y            : unsigned(9 downto 0);
   
   signal fifo_Valid_1 : std_logic;
   signal fifo_data_1  : std_logic_vector(15 downto 0);
  
begin 

   requestFifo <= '1' when (state = REQUESTWORD2 or state = REQUESTWORD3 ) else
                  '1' when (state = WRITING and pixelStall = '0' and fifo_Valid = '0' and ((x + 1 < copySizeX) or (y + 1 < copySizeY) or fifo_Valid_1 = '0')) else 
                  '0';

   process (clk2x)
      variable row : unsigned(8 downto 0);
      variable col : unsigned(9 downto 0);
   begin
      if rising_edge(clk2x) then
         
         errorMASK <= '0';
         if (state /= IDLE and DrawPixelsMask = '1') then
            errorMASK <= '1';
         end if;
         
         if (reset = '1') then
         
            state <= IDLE;
         
         elsif (ce = '1') then
         
            pixelColor   <= (others => '0');
            pixelAddr    <= (others => '0');
            pixelWrite   <= '0';
            
            done         <= '0';
            CmdDone      <= '0';
            
            fifo_Valid_1 <= '0';
         
            case (state) is
            
               when IDLE =>
                  
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "101") then
                     state <= REQUESTWORD2;
                  end if;
            
               when REQUESTWORD2 =>
                  if (fifo_Valid = '1') then
                     state    <= REQUESTWORD3;  
                     copyDstX <= unsigned(fifo_data( 9 downto  0));
                     copyDstY <= unsigned(fifo_data(24 downto 16));
                  end if;
            
               when REQUESTWORD3 =>
                  if (fifo_Valid = '1') then
                     CmdDone    <= '1';
                     state      <= WRITING;
                     copySizeX  <= '0' & unsigned(fifo_data( 9 downto  0));
                     copySizeY  <= '0' & unsigned(fifo_data(24 downto 16));
                     x          <= (others => '0');
                     y          <= (others => '0');
                     if (unsigned(fifo_data( 9 downto  0)) = 0) then copySizeX <= to_unsigned(16#400#, 11); end if;
                     if (unsigned(fifo_data(24 downto 16)) = 0) then copySizeY <= to_unsigned(16#200#, 10); end if;
                  end if;
                  
               when WRITING => 
                  if (fifo_Valid = '1') then
                     fifo_Valid_1 <= fifo_Valid;
                     fifo_data_1  <= fifo_data(31 downto 16);
                  end if;
               
                  -- todo: AND/OR masking
               
                  if (fifo_Valid = '1' or fifo_Valid_1 = '1') then
                     row := copyDstY + y(8 downto 0);
                     col := copyDstX + x(9 downto 0);
      
                     pixelWrite <= '1';
                     pixelAddr  <= row & col & '0';
                     if (fifo_Valid = '1') then
                        pixelColor <= fifo_data(15 downto 0);
                     else
                        pixelColor <= fifo_data_1;
                     end if;
                     
                     if (SetMask = '1') then
                        pixelColor(15) <= '1';
                     end if;
                     
                     if (x + 1 < copySizeX) then
                        x <= x + 1;
                     else
                        x <= (others => '0');
                        if (y + 1 < copySizeY) then
                           y <= y + 1;
                        else
                           state <= IDLE;
                           done  <= '1';
                        end if;
                     end if;
                  end if;
            
            end case;
            
            if (drawer_reset = '1') then
               state <= IDLE;
               if (state /= IDLE) then
                  done  <= '1'; 
               end if;
            end if;
         
         end if;
         
      end if;
   end process; 


end architecture;





