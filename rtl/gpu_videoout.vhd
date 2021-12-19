library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity gpu_videoout is
   port 
   (
      clk2x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      videoout_on          : in  std_logic;
      
      fpscountOn           : in  std_logic;
      fpscountBCD          : in  unsigned(7 downto 0);      
      
      cdSlow               : in  std_logic;
      
      errorOn              : in  std_logic;
      errorEna             : in  std_logic;
      errorCode            : in  unsigned(3 downto 0);
      
      fetch                : in  std_logic;
      lineIn               : in  unsigned(8 downto 0);
      lineInNext           : in  unsigned(8 downto 0);
      nextHCount           : in  integer range 0 to 4095;
      DisplayWidth         : in  unsigned(9 downto 0);
      DisplayOffsetX       : in  unsigned(9 downto 0);
      DisplayOffsetY       : in  unsigned(8 downto 0);
      GPUSTAT_HorRes2      : in  std_logic;
      GPUSTAT_HorRes1      : in  std_logic_vector(1 downto 0);
      GPUSTAT_ColorDepth24 : in  std_logic;
      interlacedMode       : in  std_logic;
      
      requestVRAMEnable    : out std_logic := '0';
      requestVRAMXPos      : out unsigned(9 downto 0);
      requestVRAMYPos      : out unsigned(8 downto 0);
      requestVRAMSize      : out unsigned(10 downto 0);
      requestVRAMIdle      : in  std_logic;
      requestVRAMDone      : in  std_logic;
      
      vram_DOUT            : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY      : in  std_logic;
      
      video_ce             : buffer std_logic := '0';
      video_r              : out std_logic_vector(7 downto 0);
      video_g              : out std_logic_vector(7 downto 0);
      video_b              : out std_logic_vector(7 downto 0);
      video_hblank         : out std_logic := '1';
      video_hsync          : out std_logic := '0'
   );
end entity;

architecture arch of gpu_videoout is
   
   type tState is
   (
      WAITNEWLINE,
      REQUEST,
      WAITREAD
   );
   signal state : tState := WAITNEWLINE;
   
   signal reqPosX       : unsigned(9 downto 0);
   signal reqPosY       : unsigned(8 downto 0);
   signal reqSize       : unsigned(10 downto 0);
   signal lineAct       : unsigned(8 downto 0);
   signal fillAddr      : unsigned(8 downto 0) := (others => '0');
   signal store         : std_logic := '0';
      
   -- output   
   signal readAddr      : unsigned(10 downto 0) := (others => '0');
   signal pixelRead     : std_logic_vector(15 downto 0);
   signal pixelData_R   : std_logic_vector(7 downto 0);
   signal pixelData_G   : std_logic_vector(7 downto 0);
   signal pixelData_B   : std_logic_vector(7 downto 0);
   
   signal lineDisp      : unsigned(8 downto 0);
   signal clkDiv        : integer range 5 to 12 := 5; 
   signal clkCnt        : integer range 0 to 12 := 0;
   signal xpos          : integer range 0 to 1023 := 0;
   signal xmax          : integer range 0 to 1023;
   
   signal hsync_start   : integer range 0 to 4095;
   signal hsync_end     : integer range 0 to 4095;
   
   type tReadState is
   (
      IDLE,
      READ16,
      READ24_0,
      READ24_8,
      READ24_16,
      READ24_24
   );
   signal readstate     : tReadState := IDLE;
   signal readstate24   : tReadState := READ24_0;
   
   signal fetchNext : std_logic := '0';
   
   -- overlay
   signal fpstext             : unsigned(15 downto 0);
   signal overlay_fps_data    : std_logic_vector(23 downto 0);
   signal overlay_fps_ena     : std_logic;
   
   signal overlay_cd_data     : std_logic_vector(23 downto 0);
   signal overlay_cd_ena      : std_logic;
   
   signal errortext           : unsigned(7 downto 0);
   signal overlay_error_data  : std_logic_vector(23 downto 0);
   signal overlay_error_ena   : std_logic;
   
begin 

   requestVRAMEnable <= '1'     when (state = REQUEST and requestVRAMIdle = '1') else '0';
   requestVRAMXPos   <= reqPosX when (state = REQUEST and requestVRAMIdle = '1') else (others => '0');
   requestVRAMYPos   <= reqPosY when (state = REQUEST and requestVRAMIdle = '1') else (others => '0');
   requestVRAMSize   <= reqSize when (state = REQUEST and requestVRAMIdle = '1') else (others => '0');

   
   -- vram reading
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         if (reset = '1') then
         
            state   <= WAITNEWLINE;
            lineAct <= (others => '0');
         
         elsif (ce = '1') then
         
            case (state) is
            
               when WAITNEWLINE =>
                  if (videoout_on = '1' and lineInNext /= lineAct and fetch = '1') then
                     state     <= REQUEST;
                     lineAct   <= lineInNext;
                     reqPosX   <= DisplayOffsetX;
                     reqPosY   <= lineInNext + DisplayOffsetY;
                     fillAddr  <= lineInNext(0) & x"00";
                     if (interlacedMode = '1') then
                        fillAddr(8) <= lineInNext(1);
                     end if;
                     if (GPUSTAT_ColorDepth24 = '1') then
                        reqSize <= resize(DisplayWidth, 11) + resize(DisplayWidth(9 downto 1), 11);
                     else
                        reqSize <= '0' & DisplayWidth;
                     end if;
                  end if;

               when REQUEST =>
                  if (requestVRAMIdle = '1') then
                     state <= WAITREAD;
                     store <= '1';
                  end if;
                  
               when WAITREAD =>
                  if (vram_DOUT_READY = '1') then
                     fillAddr <= fillAddr + 1;
                  end if;
                  if (requestVRAMDone = '1') then
                     state <= WAITNEWLINE; 
                     store <= '0';
                  end if;
            
            end case;
         
         end if;
         
      end if;
   end process; 
   
   ilineram: entity work.dpram_dif
   generic map 
   ( 
      addr_width_a  => 9,
      data_width_a  => 64,
      addr_width_b  => 11,
      data_width_b  => 16
   )
   port map
   (
      clock       => clk2x,
      
      address_a   => std_logic_vector(fillAddr),
      data_a      => vram_DOUT,
      wren_a      => (vram_DOUT_READY and store),
      
      address_b   => std_logic_vector(readAddr),
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => pixelRead
   );
   
   -- timing generation reading
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         video_ce <= '0';
         
         if (reset = '1') then
         
            clkCnt       <= 0;
            video_hblank <= '1';
            lineDisp     <= (others => '0');
            readstate    <= IDLE;
         
         elsif (ce = '1') then
         
            if (GPUSTAT_HorRes2 = '1') then
               clkDiv  <= 9; -- 368
            else
               case (GPUSTAT_HorRes1) is
                  when "00" => clkDiv <= 12; -- 256;
                  when "01" => clkDiv <= 10; -- 320;
                  when "10" => clkDiv <= 6;  -- 512;
                  when "11" => clkDiv <= 5;  -- 640;
                  when others => null;
               end case;
            end if;
            
            if (clkCnt < (clkDiv - 1)) then
               clkCnt <= clkCnt + 1;
            else
               clkCnt    <= 0;
               video_ce  <= '1';
               if (xpos < 1023) then
                  xpos <= xpos + 1;
               end if;
               if (xpos > 0 and xpos <= xmax) then
                  video_hblank <= '0';
                  if (overlay_error_ena = '1') then
                     video_r      <= overlay_error_data( 7 downto 0);
                     video_g      <= overlay_error_data(15 downto 8);
                     video_b      <= overlay_error_data(23 downto 16);
                  elsif (overlay_cd_ena = '1') then
                     video_r      <= overlay_cd_data( 7 downto 0);
                     video_g      <= overlay_cd_data(15 downto 8);
                     video_b      <= overlay_cd_data(23 downto 16);
                  elsif (overlay_fps_ena = '1') then
                     video_r      <= overlay_fps_data( 7 downto 0);
                     video_g      <= overlay_fps_data(15 downto 8);
                     video_b      <= overlay_fps_data(23 downto 16);
                  else
                     video_r      <= pixelData_R;
                     video_g      <= pixelData_G;
                     video_b      <= pixelData_B;
                  end if;
               else
                  video_hblank <= '1';
                  if (video_hblank = '0') then
                     hsync_start <= (nextHCount / 2) + (26 * clkDiv);
                     hsync_end   <= (nextHCount / 2) + (2 * clkDiv);
                  end if;
               end if;
            end if;
            
            if (lineIn /= lineDisp) then
               lineDisp <= lineIn;
               readAddr <= lineIn(0) & "00" & x"00";
               if (interlacedMode = '1') then
                  readAddr(10) <= lineIn(1);
               end if;
               xpos     <= 0;
               xmax     <= to_integer(DisplayWidth);
            end if;
            
            if (nextHCount = hsync_start) then video_hsync <= '1'; end if;
            if (nextHCount = hsync_end  ) then video_hsync <= '0'; end if;
         
            case (readstate) is
            
               when IDLE =>
                  if (clkCnt >= (clkDiv - 1) and xpos < xmax) then
                     if (GPUSTAT_ColorDepth24 = '1') then
                        readAddr  <= readAddr + 1;
                        if (xpos = 0 or readstate24 = READ24_0) then
                           readstate <= READ24_0;
                        else
                           readstate <= READ24_8;
                        end if;
                     else
                        readstate <= READ16;
                     end if;
                  end if;

               when READ16 =>
                  readstate   <= IDLE;
                  readAddr    <= readAddr + 1;
                  pixelData_R <= pixelRead( 4 downto  0) & pixelRead( 4 downto 2);
                  pixelData_G <= pixelRead( 9 downto  5) & pixelRead( 9 downto 7);
                  pixelData_B <= pixelRead(14 downto 10) & pixelRead(14 downto 12);
                  
               when READ24_0 =>
                  readstate   <= READ24_16;
                  pixelData_R <= pixelRead( 7 downto  0);
                  pixelData_G <= pixelRead(15 downto  8);
                 
               when READ24_8 =>
                  readstate   <= READ24_24;
                  pixelData_R <= pixelRead(15 downto  8);
                  
               when READ24_16 =>
                  readstate   <= IDLE;
                  readstate24 <= READ24_8;
                  pixelData_B <= pixelRead( 7 downto  0);
            
                when READ24_24 =>
                  readstate   <= IDLE;
                  readstate24 <= READ24_0;
                  readAddr    <= readAddr + 1;
                  pixelData_G <= pixelRead( 7 downto  0);
                  pixelData_B <= pixelRead(15 downto  8);
            
            end case;
         
         end if;
         
      end if;
   end process; 
   
   
   -- overlays
   fpstext( 7 downto 0) <= resize(fpscountBCD(3 downto 0), 8) + 16#30#;
   fpstext(15 downto 8) <= resize(fpscountBCD(7 downto 4), 8) + 16#30#;
   
   ioverlayFPS : entity work.gpu_overlay
   generic map
   (
      COLS                   => 2,
      BACKGROUNDON           => '1',
      RGB_BACK               => x"FFFFFF",
      RGB_FRONT              => x"0000FF",
      OFFSETX                => 4,
      OFFSETY                => 4
   )
   port map
   (
      clk                    => clk2x,
      ce                     => video_ce,
      ena                    => fpscountOn,                    
      i_pixel_out_x          => xpos,
      i_pixel_out_y          => to_integer(lineDisp),
      o_pixel_out_data       => overlay_fps_data,
      o_pixel_out_ena        => overlay_fps_ena,
      textstring             => fpstext
   );
   
   ioverlayCD : entity work.gpu_overlay
   generic map
   (
      COLS                   => 2,
      BACKGROUNDON           => '1',
      RGB_BACK               => x"FFFFFF",
      RGB_FRONT              => x"0000FF",
      OFFSETX                => 4,
      OFFSETY                => 24
   )
   port map
   (
      clk                    => clk2x,
      ce                     => video_ce,
      ena                    => cdSlow,                    
      i_pixel_out_x          => xpos,
      i_pixel_out_y          => to_integer(lineDisp),
      o_pixel_out_data       => overlay_cd_data,
      o_pixel_out_ena        => overlay_cd_ena,
      textstring             => x"4344"
   );
   
   errortext <= resize(errorCode(3 downto 0), 8) + 16#30#;
   ioverlayError : entity work.gpu_overlay
   generic map
   (
      COLS                   => 2,
      BACKGROUNDON           => '1',
      RGB_BACK               => x"FFFFFF",
      RGB_FRONT              => x"0000FF",
      OFFSETX                => 4,
      OFFSETY                => 44
   )
   port map
   (
      clk                    => clk2x,
      ce                     => video_ce,
      ena                    => errorOn and errorEna,                    
      i_pixel_out_x          => xpos,
      i_pixel_out_y          => to_integer(lineDisp),
      o_pixel_out_data       => overlay_error_data,
      o_pixel_out_ena        => overlay_error_ena,
      textstring             => x"45" & errortext
   );


end architecture;





