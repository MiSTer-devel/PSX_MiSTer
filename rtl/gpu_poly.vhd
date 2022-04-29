library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pGPU.all;

entity gpu_poly is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      REPRODUCIBLEGPUTIMING: in  std_logic;
      textureFilter        : in  std_logic;
      
      error                : out std_logic;
      
      DrawPixelsMask       : in  std_logic;
      interlacedDrawing    : in  std_logic;
      activeLineLSB        : in  std_logic;
      drawingOffsetX       : in  signed(10 downto 0);
      drawingOffsetY       : in  signed(10 downto 0);
      drawingAreaLeft      : in  unsigned(9 downto 0);
      drawingAreaRight     : in  unsigned(9 downto 0);
      drawingAreaTop       : in  unsigned(8 downto 0);
      drawingAreaBottom    : in  unsigned(8 downto 0);
      
      drawModeRec          : out unsigned(11 downto 0);
      drawModeNew          : out std_logic := '0';
      drawmode_dithering   : in  std_logic := '0';
      
      div1                 : inout div_type; 
      div2                 : inout div_type; 
      div3                 : inout div_type; 
      div4                 : inout div_type; 
      div5                 : inout div_type; 
      div6                 : inout div_type; 
      
      pipeline_busy        : in  std_logic;
      pipeline_stall       : in  std_logic;
      pipeline_new         : out std_logic := '0';
      pipeline_texture     : out std_logic := '0';
      pipeline_transparent : out std_logic := '0';
      pipeline_rawTexture  : out std_logic := '0';
      pipeline_dithering   : out std_logic := '0';
      pipeline_x           : out unsigned(9 downto 0) := (others => '0');
      pipeline_y           : out unsigned(8 downto 0) := (others => '0');
      pipeline_cr          : out unsigned(7 downto 0) := (others => '0');
      pipeline_cg          : out unsigned(7 downto 0) := (others => '0');
      pipeline_cb          : out unsigned(7 downto 0) := (others => '0');
      pipeline_u           : out unsigned(7 downto 0) := (others => '0');
      pipeline_v           : out unsigned(7 downto 0) := (others => '0');
      
      proc_idle            : in  std_logic;
      fifo_Valid           : in  std_logic;
      fifo_data            : in  std_logic_vector(31 downto 0);
      requestFifo          : out std_logic := '0';
      done                 : out std_logic := '0';
      CmdDone              : out std_logic := '0';
      
      requestVRAMEnable    : out std_logic;
      requestVRAMXPos      : out unsigned(9 downto 0);
      requestVRAMYPos      : out unsigned(8 downto 0);
      requestVRAMSize      : out unsigned(10 downto 0);
      requestVRAMIdle      : in  std_logic;
      requestVRAMDone      : in  std_logic;
      
      textPalNew           : out std_logic := '0';
      textPalX             : out unsigned(9 downto 0) := (others => '0');   
      textPalY             : out unsigned(8 downto 0) := (others => '0'); 
      
      vramLineEna          : out std_logic;
      vramLineAddr         : out unsigned(9 downto 0)
   );
end entity;

architecture arch of gpu_poly is
   
   type tState is
   (
      IDLE,
      REQUESTCOLOR,
      REQUESTPOS,
      REQUESTTEXTURE,
      ISSUE,
      SORTVERTICES,
      CALCBOUNDARY1,
      CALCBOUNDARY2,
      CALCCOLOR1,
      CALCCOLOR2,
      CALCCOLOR3,
      CALCCOLOR4,
      CALCTEXTURE1,
      CALCTEXTURE2,
      CALCTEXTURE3,
      CALCTEXTURE4,
      PREPAREHALF,
      PREPAREDECMODE,
      PREPARELINE,
      REQUESTLINE,
      READWAIT,
      PROCPIXELS,
      WAITIMING
   );
   signal state     : tState := IDLE;
   
   signal mulStep             : integer range 0 to 7;
   
   signal drawTiming          : unsigned(31 downto 0);
   signal targetTiming        : unsigned(31 downto 0);
   
   signal rec_shading         : std_logic := '0';
   signal rec_quad            : std_logic := '0';
   signal rec_texture         : std_logic := '0';
   signal rec_transparency    : std_logic := '0';
   signal rec_rawTexture      : std_logic := '0';
   signal rec_dithering       : std_logic := '0';
   
   type tVertex is record
      x         : integer range -2048 to 2047; 
      y         : integer range -2048 to 2047;    
      r         : unsigned(7 downto 0);
      g         : unsigned(7 downto 0);
      b         : unsigned(7 downto 0);
      u         : unsigned(7 downto 0);
      v         : unsigned(7 downto 0);
   end record;
   type tRecVertexArray is array(0 to 3) of tVertex;
   signal rec_vertices        : tRecVertexArray := (others => (0, 0, (others => '0') , (others => '0') , (others => '0') , (others => '0') , (others => '0')));

   signal rec_index           : integer range 0 to 3;
   
   signal rec_textPalX        : unsigned(9 downto 0) := (others => '0');   
   signal rec_textPalY        : unsigned(8 downto 0) := (others => '0');

   signal quadFirst           : std_logic := '0';
   signal nextQuad            : std_logic := '0';
   
   type tworkVertexArray is array(0 to 2) of tVertex;
   signal vt                  : tworkVertexArray;
   signal coreVertex          : integer range 0 to 2;
   signal vo                  : integer range 0 to 1;
   signal vp                  : integer range 0 to 1;
   signal denom               : integer range -16777216 to 16777215;
   
   signal rightFacing         : integer range 0 to 1;
   signal baseCoord           : signed(44 downto 0) := (others => '0');
   signal baseStep            : signed(44 downto 0) := (others => '0');
   signal boundCoordUs        : signed(44 downto 0) := (others => '0');
   signal boundCoordLs        : signed(44 downto 0) := (others => '0');
   
   signal firsthalf           : std_logic := '0';
   signal secondhalf          : std_logic := '0';
   
   signal diffX10             : signed(12 downto 0);
   signal diffX21             : signed(12 downto 0);
   signal diffY10             : signed(12 downto 0);
   signal diffY21             : signed(12 downto 0);
   
   signal diffR10             : signed(8 downto 0);
   signal diffR21             : signed(8 downto 0);
   signal diffG10             : signed(8 downto 0);
   signal diffG21             : signed(8 downto 0);
   signal diffB10             : signed(8 downto 0);
   signal diffB21             : signed(8 downto 0);
   
   signal diffU10             : signed(8 downto 0);
   signal diffU21             : signed(8 downto 0);
   signal diffV10             : signed(8 downto 0);
   signal diffV21             : signed(8 downto 0);

   signal dxR                 : unsigned(31 downto 0) := (others => '0'); 
   signal dyR                 : unsigned(31 downto 0) := (others => '0'); 
   signal dxG                 : unsigned(31 downto 0) := (others => '0'); 
   signal dyG                 : unsigned(31 downto 0) := (others => '0');
   signal dxB                 : unsigned(31 downto 0) := (others => '0'); 
   signal dyB                 : unsigned(31 downto 0) := (others => '0');
   signal dxU                 : unsigned(31 downto 0) := (others => '0'); 
   signal dyU                 : unsigned(31 downto 0) := (others => '0');
   signal dxV                 : unsigned(31 downto 0) := (others => '0'); 
   signal dyV                 : unsigned(31 downto 0) := (others => '0');

   signal base_R              : unsigned(31 downto 0) := (others => '0');   
   signal base_G              : unsigned(31 downto 0) := (others => '0');   
   signal base_B              : unsigned(31 downto 0) := (others => '0');   
   signal base_U              : unsigned(31 downto 0) := (others => '0');   
   signal base_V              : unsigned(31 downto 0) := (others => '0'); 

   signal muldiv1In1          : signed(8 downto 0);
   signal muldiv1In2          : signed(12 downto 0);
   signal muldivResult1       : signed(21 downto 0) := (others => '0'); 
   signal muldivResult1clk    : signed(21 downto 0) := (others => '0');      
   
   signal muldiv2In1          : signed(8 downto 0);
   signal muldiv2In2          : signed(12 downto 0);
   signal muldivResult2       : signed(21 downto 0) := (others => '0'); 
   signal muldivResult2clk    : signed(21 downto 0) := (others => '0');    
   
   signal mulIn1              : unsigned(31 downto 0);
   signal mulIn2              : unsigned(31 downto 0);
   signal mulResult32         : unsigned(31 downto 0) := (others => '0'); 
   signal mulResult32clk      : unsigned(31 downto 0) := (others => '0'); 

   signal work_R              : unsigned(31 downto 0) := (others => '0');   
   signal work_G              : unsigned(31 downto 0) := (others => '0');   
   signal work_B              : unsigned(31 downto 0) := (others => '0');   
   signal work_U              : unsigned(31 downto 0) := (others => '0');   
   signal work_V              : unsigned(31 downto 0) := (others => '0'); 

   signal vo_diff             : integer range -4096 to 4095;
   signal vp_diff             : integer range -4096 to 4095;
   
   signal vo_diff_base        : signed(44 downto 0) := (others => '0');
   signal vp_diff_base        : signed(44 downto 0) := (others => '0');

   signal yCoord              : integer range -2048 to 2047; 
   signal yBound              : integer range -2048 to 2047; 
   signal xStart              : signed(44 downto 0) := (others => '0');
   signal xStepStart          : signed(44 downto 0) := (others => '0');
   signal xEnd                : signed(44 downto 0) := (others => '0');
   signal xStepEnd            : signed(44 downto 0) := (others => '0');
   signal decMode             : integer range 0 to 1;
   
   signal xPos                : signed(11 downto 0) := (others => '0'); 
   signal yPos                : signed(10 downto 0) := (others => '0'); 
   signal xStop               : signed(11 downto 0) := (others => '0'); 
   signal xSize               : unsigned(10 downto 0) := (others => '0'); 

   signal firstPixel          : std_logic;   
   
   signal filter_on           : std_logic;
   signal filter_maxU         : unsigned(7 downto 0);
   signal filter_maxV         : unsigned(7 downto 0);
   
   signal timeout             : integer range 0 to 1048575 := 0;
   
begin 

   requestFifo <= '1' when (state = REQUESTCOLOR or state = REQUESTPOS or state = REQUESTTEXTURE) else '0';
   
   requestVRAMEnable <= '1'                        when (state = REQUESTLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else '0';
   requestVRAMXPos   <= unsigned(xPos(9 downto 0)) when (state = REQUESTLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   requestVRAMYPos   <= unsigned(yPos(8 downto 0)) when (state = REQUESTLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   requestVRAMSize   <= xSize                      when (state = REQUESTLINE and requestVRAMIdle = '1' and pipeline_stall = '0') else (others => '0');
   
   vramLineEna  <= '1' when (state = PROCPIXELS) else '0';
   vramLineAddr <= unsigned(xPos(9 downto 0)) when (state = PROCPIXELS) else (others => '0');
   
   
   
   
   imul9s1 : entity work.mul9s
   port map 
   (
      mul1     => muldiv1In1,
      mul2     => muldiv1In2,
      result   => muldivResult1
   );
   
   imul9s2 : entity work.mul9s
   port map 
   (
      mul1     => muldiv2In1,
      mul2     => muldiv2In2,
      result   => muldivResult2
   );
     
   muldiv1In1 <= diffU10 when (state = CALCTEXTURE2 and mulStep = 0) else
                 diffU21 when (state = CALCTEXTURE2 and mulStep = 1) else
                 diffV10 when (state = CALCTEXTURE2 and mulStep = 2) else
                 diffV21 when (state = CALCTEXTURE2 and mulStep = 3) else
                 diffR10 when (mulStep = 0) else
                 diffR21 when (mulStep = 1) else
                 diffG10 when (mulStep = 2) else
                 diffG21 when (mulStep = 3) else
                 diffB10 when (mulStep = 4) else
                 diffB21;
                 
   muldiv1In2 <= diffY21 when (state = CALCTEXTURE2 and mulStep = 0) else
                 diffX10 when (state = CALCTEXTURE2 and mulStep = 1) else
                 diffY21 when (state = CALCTEXTURE2 and mulStep = 2) else
                 diffX10 when (state = CALCTEXTURE2 and mulStep = 3) else
                 diffY21 when (mulStep = 0) else
                 diffX10 when (mulStep = 1) else
                 diffY21 when (mulStep = 2) else
                 diffX10 when (mulStep = 3) else
                 diffY21 when (mulStep = 4) else
                 diffX10;
   
   muldiv2In1 <= diffU21 when (state = CALCTEXTURE2 and mulStep = 0) else
                 diffU10 when (state = CALCTEXTURE2 and mulStep = 1) else
                 diffV21 when (state = CALCTEXTURE2 and mulStep = 2) else
                 diffV10 when (state = CALCTEXTURE2 and mulStep = 3) else
                 diffR21 when (mulStep = 0) else
                 diffR10 when (mulStep = 1) else
                 diffG21 when (mulStep = 2) else
                 diffG10 when (mulStep = 3) else
                 diffB21 when (mulStep = 4) else
                 diffB10;
                 
   muldiv2In2 <= diffY10 when (state = CALCTEXTURE2 and mulStep = 0) else
                 diffX21 when (state = CALCTEXTURE2 and mulStep = 1) else
                 diffY10 when (state = CALCTEXTURE2 and mulStep = 2) else
                 diffX21 when (state = CALCTEXTURE2 and mulStep = 3) else
                 diffY10 when (mulStep = 0) else
                 diffX21 when (mulStep = 1) else
                 diffY10 when (mulStep = 2) else
                 diffX21 when (mulStep = 3) else
                 diffY10 when (mulStep = 4) else
                 diffX21;
   
   imul32u : entity work.mul32u
   port map 
   (
      mul1     => mulIn1,
      mul2     => mulIn2,
      result   => mulResult32
   );
   
   mulIn1 <= dxU when (state = CALCTEXTURE4 and mulStep = 0) else
             dxV when (state = CALCTEXTURE4 and mulStep = 1) else
             dyU when (state = CALCTEXTURE4 and mulStep = 2) else
             dyV when (state = CALCTEXTURE4 and mulStep = 3) else
             dxR when (mulStep = 0) else 
             dxG when (mulStep = 1) else 
             dxB when (mulStep = 2) else 
             dyR when (mulStep = 3) else 
             dyG when (mulStep = 4) else 
             dyB;
             
   mulIn2 <= unsigned(to_signed(-vt(coreVertex).x, 32)) when (state = CALCTEXTURE4 and mulStep = 0) else
             unsigned(to_signed(-vt(coreVertex).x, 32)) when (state = CALCTEXTURE4 and mulStep = 1) else
             unsigned(to_signed(-vt(coreVertex).y, 32)) when (state = CALCTEXTURE4 and mulStep = 2) else
             unsigned(to_signed(-vt(coreVertex).y, 32)) when (state = CALCTEXTURE4 and mulStep = 3) else
             unsigned(to_signed(-vt(coreVertex).x, 32)) when (mulStep = 0) else 
             unsigned(to_signed(-vt(coreVertex).x, 32)) when (mulStep = 1) else 
             unsigned(to_signed(-vt(coreVertex).x, 32)) when (mulStep = 2) else 
             unsigned(to_signed(-vt(coreVertex).y, 32)) when (mulStep = 3) else 
             unsigned(to_signed(-vt(coreVertex).y, 32)) when (mulStep = 4) else 
             unsigned(to_signed(-vt(coreVertex).y, 32));
   
   process (clk2x)
      variable xrec12   : signed(11 downto 0);
      variable yrec12   : signed(11 downto 0);
      variable cull     : std_logic;    
      variable xMax     : integer;
      variable dx1      : signed(44 downto 0);
      variable dx2      : signed(44 downto 0);
      variable dx3      : signed(44 downto 0);
      variable dy1      : signed(12 downto 0);
      variable dy2      : signed(12 downto 0);
      variable dy3      : signed(12 downto 0);
      variable calc1    : signed(44 downto 0);
      variable calc2    : signed(44 downto 0);
      variable calc3    : signed(44 downto 0);
      variable calc4    : signed(44 downto 0);
      variable stop     : std_logic;
      variable skip     : std_logic; 
      variable uFilter  : unsigned(20 downto 0);
      variable vFilter  : unsigned(20 downto 0);
   begin
      if rising_edge(clk2x) then
         
         if (reset = '1') then
         
            state <= IDLE;
         
         elsif (ce = '1') then
         
            done                 <= '0';
            CmdDone              <= '0';

            drawModeNew          <= '0';
            
            textPalNew           <= '0';
            textPalX             <= (others => '0');
            textPalY             <= (others => '0');
            
            pipeline_new         <= '0';
            pipeline_texture     <= '0';
            pipeline_transparent <= '0';
            pipeline_rawTexture  <= '0';
            pipeline_dithering   <= '0';
            pipeline_x           <= (others => '0');
            pipeline_y           <= (others => '0');
            pipeline_cr          <= (others => '0');
            pipeline_cg          <= (others => '0');
            pipeline_cb          <= (others => '0');
            pipeline_u           <= (others => '0');
            pipeline_v           <= (others => '0');
            
            div1.start           <= '0';
            div2.start           <= '0';
            div3.start           <= '0';
            div4.start           <= '0';
            div5.start           <= '0';
            div6.start           <= '0';
            
            if (state /= CALCCOLOR2 and state /= CALCTEXTURE2) then
               div1.dividend        <= (others => '0');
               div2.dividend        <= (others => '0');
               div3.dividend        <= (others => '0');
               div4.dividend        <= (others => '0');
               div5.dividend        <= (others => '0');
               div6.dividend        <= (others => '0');
            end if;
            
            div1.divisor         <= (others => '0');
            div2.divisor         <= (others => '0');
            div3.divisor         <= (others => '0');
            div4.divisor         <= (others => '0');
            div5.divisor         <= (others => '0');
            div6.divisor         <= (others => '0');
            
            if (state /= IDLE) then
               drawTiming <= drawTiming + 1;
            end if;
            
            error <= '0';
            if (state = IDLE) then
               timeout <= 0;
            elsif (timeout < 1048575) then
               timeout  <= timeout + 1;
            else
               error <= '1';
               state <= IDLE;
               done  <= '1';
            end if;
         
            case (state) is
            
               when IDLE =>
                  drawTiming   <= (others => '0');
                  targetTiming <= to_unsigned(500, 32);
                  firstPixel   <= '1';
                  filter_maxU  <= x"00";
                  filter_maxV  <= x"00";
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "001") then
                     state             <= REQUESTPOS;
                     rec_index         <= 0;
                     rec_shading       <= fifo_data(28);
                     rec_quad          <= fifo_data(27);
                     quadFirst         <= fifo_data(27);
                     rec_texture       <= fifo_data(26);
                     rec_transparency  <= fifo_data(25);
                     rec_rawTexture    <= fifo_data(24);
                     rec_dithering     <= fifo_data(28) or (fifo_data(26) and (not fifo_data(24)));
                     for i in 0 to 3 loop
                        rec_vertices(i).r <= unsigned(fifo_data( 7 downto  0));
                        rec_vertices(i).g <= unsigned(fifo_data(15 downto  8));
                        rec_vertices(i).b <= unsigned(fifo_data(23 downto 16));
                     end loop;
                  end if;
                              
               when REQUESTCOLOR =>
                  drawTiming   <= (others => '0');
                  if (fifo_Valid = '1') then
                     state             <= REQUESTPOS;
                     rec_vertices(rec_index).r <= unsigned(fifo_data( 7 downto  0));
                     rec_vertices(rec_index).g <= unsigned(fifo_data(15 downto  8));
                     rec_vertices(rec_index).b <= unsigned(fifo_data(23 downto 16));
                  end if;   
                  
               when REQUESTPOS =>
                  drawTiming   <= (others => '0');
                  if (fifo_Valid = '1') then
                     if (drawingOffsetX < 0) then
                        xrec12                    := resize(drawingOffsetX, 12) + signed('0' & fifo_data(10 downto  0));
                        rec_vertices(rec_index).x <= to_integer(xrec12(10 downto 0));
                     else
                        rec_vertices(rec_index).x <= to_integer(resize(signed(fifo_data(10 downto  0)),12) + resize(drawingOffsetX, 12));
                     end if;
                     
                     if (drawingOffsetY < 0) then
                        yrec12                    := resize(drawingOffsetY, 12) + signed('0' & fifo_data(26 downto 16));    
                        rec_vertices(rec_index).y <= to_integer(yrec12(10 downto 0));
                     else
                        rec_vertices(rec_index).y <= to_integer(resize(signed(fifo_data(26 downto 16)),12) + resize(drawingOffsetY, 12));
                     end if;
                     
                     if (rec_texture = '1') then
                        state    <= REQUESTTEXTURE;  
                     elsif ((rec_quad = '1' and rec_index = 3) or (rec_quad = '0' and rec_index = 2)) then
                        state    <= ISSUE; 
                        CmdDone  <= '1';                        
                     else
                        rec_index <= rec_index +1;
                        if (rec_shading = '1') then
                           state  <= REQUESTCOLOR;
                        else
                           state  <= REQUESTPOS;
                        end if;
                     end if;
                  end if;
                  
               when REQUESTTEXTURE =>
                  drawTiming   <= (others => '0');
                  if (fifo_Valid = '1') then
                     rec_vertices(rec_index).u <= unsigned(fifo_data( 7 downto  0));
                     rec_vertices(rec_index).v <= unsigned(fifo_data(15 downto  8));
                     if (unsigned(fifo_data( 7 downto  0)) > filter_maxU) then filter_maxU <= unsigned(fifo_data( 7 downto  0)); end if;
                     if (unsigned(fifo_data(15 downto  8)) > filter_maxV) then filter_maxV <= unsigned(fifo_data(15 downto  8)); end if;
                     if (rec_index = 0) then
                        rec_textPalX  <= unsigned(fifo_data(21 downto 16)) & "0000";
                        rec_textPalY  <= unsigned(fifo_data(30 downto 22));
                     end if;
                     if (rec_index = 1) then
                        drawModeRec   <= unsigned(fifo_data(27 downto 16));
                        drawModeNew   <= '1';
                     end if;
                     if (rec_index = 2) then
                        textPalX    <= rec_textPalX;
                        textPalY    <= rec_textPalY;
                        textPalNew  <= '1';
                     end if;
                     
                     if ((rec_quad = '1' and rec_index = 3) or (rec_quad = '0' and rec_index = 2)) then
                        state    <= ISSUE;  
                        CmdDone  <= '1'; 
                     else
                        rec_index <= rec_index +1;
                        if (rec_shading = '1') then
                           state  <= REQUESTCOLOR;
                        else
                           state  <= REQUESTPOS;
                        end if;
                     end if;
                  end if;
            
               when ISSUE =>
                  state    <= SORTVERTICES;
                  nextQuad <= '0';
                  if (rec_quad = '0' or quadFirst = '1') then
                     vt(0) <= rec_vertices(0);
                     vt(1) <= rec_vertices(1);
                     vt(2) <= rec_vertices(2);
                     quadFirst <= '0';
                     if (rec_quad = '1') then
                        nextQuad <= '1';
                     end if;
                  else
                     vt(0) <= rec_vertices(2);
                     vt(1) <= rec_vertices(1);
                     vt(2) <= rec_vertices(3);
                  end if;
                  if (drawingAreaLeft > drawingAreaRight or drawingAreaTop > drawingAreaBottom) then
                     if (REPRODUCIBLEGPUTIMING = '1') then
                        state <= WAITIMING;
                     else
                        state <= IDLE;
                        done  <= '1';
                     end if;
                  end if; 

               when SORTVERTICES =>
                  state     <= CALCBOUNDARY1;
                  firsthalf <= '1';
                  if (vt(0).y <= vt(2).y and vt(2).y <= vt(1).y) then -- 0 2 1
                     vt(0) <= vt(0);
                     vt(1) <= vt(2);
                     vt(2) <= vt(1);
                  elsif (vt(1).y <= vt(0).y and vt(0).y <= vt(2).y) then -- 1 0 2
                     vt(0) <= vt(1);
                     vt(1) <= vt(0);
                     vt(2) <= vt(2);
                  elsif (vt(1).y <= vt(2).y and vt(2).y <= vt(0).y) then -- 1 2 0
                     vt(0) <= vt(1);
                     vt(1) <= vt(2);
                     vt(2) <= vt(0);
                  elsif (vt(2).y <= vt(0).y and vt(0).y <= vt(1).y) then -- 2 0 1
                     vt(0) <= vt(2);
                     vt(1) <= vt(0);
                     vt(2) <= vt(1);
                  elsif (vt(2).y <= vt(1).y and vt(1).y <= vt(0).y) then -- 2 1 0
                     vt(0) <= vt(2);
                     vt(1) <= vt(1);
                     vt(2) <= vt(0);
                  end if; -- 0 1 2 requires no resorting
               
               
               when CALCBOUNDARY1 =>
                  state <= CALCBOUNDARY2;
                  
                  xMax := abs(vt(0).x - vt(1).x);
                  if (abs(vt(0).x - vt(2).x) > xMax) then xMax := abs(vt(0).x - vt(2).x); end if;
                  if (abs(vt(1).x - vt(2).x) > xMax) then xMax := abs(vt(1).x - vt(2).x); end if;
                  if (rec_transparency = '1' or rec_texture = '1') then 
                     targetTiming <= targetTiming + (vt(2).y + 1 - vt(0).y) * xMax * 4;
                  else
                     targetTiming <= targetTiming + (vt(2).y + 1 - vt(0).y) * xMax * 2;
                  end if;
                  
                  coreVertex <= 0;
                  vo         <= 0;
                  vp         <= 0;
                  if (vt(1).x <= vt(0).x) then
                     coreVertex <= 1;
                     vo         <= 1;
                     if(vt(2).x <= vt(1).x) then
                        coreVertex <= 2;
                        vp         <= 1;
                     end if;
                  elsif (vt(2).x < vt(0).x) then
                     coreVertex <= 2;
                     vo         <= 1;
                     vp         <= 1;
                  end if;
                  
                  denom <= ((vt(1).x - vt(0).x) * (vt(2).y - vt(1).y)) - ((vt(2).x - vt(1).x) * (vt(1).y - vt(0).y));
                  
                  baseCoord <= (to_signed(vt(0).x, 13) & x"00000000") + x"100000000" - 2048;
                  
                  dy1 := (to_signed(vt(2).y, 13) - to_signed(vt(0).y, 13));
                  dx1 := (to_signed(vt(2).x, 13) - to_signed(vt(0).x, 13)) & x"00000000";
                  if    (dx1 < 0) then dx1 := dx1 - (dy1 - 1); 
                  elsif (dx1 > 0) then dx1 := dx1 + (dy1 - 1); end if;
                  div1.start     <= '1';
                  div1.dividend  <= dx1;
                  div1.divisor   <= x"000" & dy1;
                  
                  dy2 := (to_signed(vt(1).y, 13) - to_signed(vt(0).y, 13));
                  dx2 := (to_signed(vt(1).x, 13) - to_signed(vt(0).x, 13)) & x"00000000";
                  if    (dx2 < 0) then dx2 := dx2 - (dy2 - 1); 
                  elsif (dx2 > 0) then dx2 := dx2 + (dy2 - 1); end if;
                  div2.start     <= '1';
                  div2.dividend  <= dx2;
                  div2.divisor   <= x"000" & dy2;
                  
                  dy3 := (to_signed(vt(2).y, 13) - to_signed(vt(1).y, 13));
                  dx3 := (to_signed(vt(2).x, 13) - to_signed(vt(1).x, 13)) & x"00000000";
                  if    (dx3 < 0) then dx3 := dx3 - (dy3 - 1); 
                  elsif (dx3 > 0) then dx3 := dx3 + (dy3 - 1); end if;
                  div3.start     <= '1';
                  div3.dividend  <= dx3;
                  div3.divisor   <= x"000" & dy3;
                  
                  -- culling of large polygons
                  cull := '0';
                  if (vt(0).y = vt(2).y)                 then cull := '1'; end if;
                  if (abs(vt(2).x - vt(0).x) >= 16#400#) then cull := '1'; end if;
                  if (abs(vt(2).x - vt(1).x) >= 16#400#) then cull := '1'; end if;
                  if (abs(vt(1).x - vt(0).x) >= 16#400#) then cull := '1'; end if;
                  if (abs(vt(2).y - vt(0).y) >= 16#200#) then cull := '1'; end if;
                  
                  if (cull = '1') then
                     div1.start <= '0';
                     div2.start <= '0';
                     div3.start <= '0';
                     if (nextQuad = '1') then 
                        state <= ISSUE;
                     else
                        if (REPRODUCIBLEGPUTIMING = '1') then
                           state <= WAITIMING;
                        else
                           state <= IDLE;
                           done  <= '1';
                        end if;
                     end if;
                  end if;
                  
               
               when CALCBOUNDARY2 =>
                  baseStep     <= div1.quotient;
                  
                  rightFacing <= 0;
                  if (vt(1).y = vt(0).y) then
                     boundCoordUs <= (others => '0');
                     if (vt(1).x > vt(0).x) then rightFacing <= 1; end if;
                  else
                     if (div2.quotient > div1.quotient) then rightFacing <= 1; end if;
                     boundCoordUs <= div2.quotient;
                  end if;
                  
                  if (vt(2).y = vt(1).y) then
                     boundCoordLs <= (others => '0');
                  else
                     boundCoordLs <= div3.quotient;
                  end if;
                  
                  vo_diff <= vt(vo).y - vt(0).y;
                  vp_diff <= vt(1 + vp).y - vt(0).y;
                  
                  vo_diff_base <= resize(vo_diff * baseStep, 45);
                  vp_diff_base <= resize(vp_diff * baseStep, 45);
                  
                  base_R <= x"000" & vt(coreVertex).r & x"800";
                  base_G <= x"000" & vt(coreVertex).g & x"800";
                  base_B <= x"000" & vt(coreVertex).b & x"800";
                  base_U <= x"000" & vt(coreVertex).u & x"800";
                  base_V <= x"000" & vt(coreVertex).v & x"800";
                  
                  diffX10 <= to_signed(vt(1).x - vt(0).x, 13);
                  diffX21 <= to_signed(vt(2).x - vt(1).x, 13);
                  diffY10 <= to_signed(vt(1).y - vt(0).y, 13);
                  diffY21 <= to_signed(vt(2).y - vt(1).y, 13);
                  
                  if (div1.done = '1') then
                     if (denom = 0) then
                        if (nextQuad = '1') then 
                           state <= ISSUE;
                        else
                           if (REPRODUCIBLEGPUTIMING = '1') then
                              state <= WAITIMING;
                           else
                              state <= IDLE;
                              done  <= '1';
                           end if;
                        end if;
                     elsif (rec_shading = '1') then
                        state <= CALCCOLOR1;
                     elsif (rec_texture = '1') then
                        state <= CALCTEXTURE1;
                     else
                        state <= PREPAREHALF;
                     end if;
                  end if;
               
               when CALCCOLOR1 =>
                  mulStep <= 0;
                  state   <= CALCCOLOR2;
                  diffR10 <=  ('0' & signed(vt(1).r)) - ('0' & signed(vt(0).r));
                  diffR21 <=  ('0' & signed(vt(2).r)) - ('0' & signed(vt(1).r));
                  diffG10 <=  ('0' & signed(vt(1).g)) - ('0' & signed(vt(0).g));
                  diffG21 <=  ('0' & signed(vt(2).g)) - ('0' & signed(vt(1).g));
                  diffB10 <=  ('0' & signed(vt(1).b)) - ('0' & signed(vt(0).b));
                  diffB21 <=  ('0' & signed(vt(2).b)) - ('0' & signed(vt(1).b));
               
               when CALCCOLOR2 =>
                  mulStep <= mulStep + 1;
                  div1.divisor   <= to_signed(denom, 25);
                  div2.divisor   <= to_signed(denom, 25);
                  div3.divisor   <= to_signed(denom, 25);
                  div4.divisor   <= to_signed(denom, 25);
                  div5.divisor   <= to_signed(denom, 25);
                  div6.divisor   <= to_signed(denom, 25);
                  case (mulStep) is
                     when 0 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2;
                     when 1 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2; div1.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";
                     when 2 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2; div2.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";  
                     when 3 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2; div3.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";
                     when 4 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2; div4.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";
                     when 5 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2; div5.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";
                     when 6 =>                                                             
                        div6.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";
                        state  <= CALCCOLOR3;
                        div1.start     <= '1';
                        div2.start     <= '1';
                        div3.start     <= '1';
                        div4.start     <= '1';
                        div5.start     <= '1';
                        div6.start     <= '1';
                     when others => null;
                  end case;
               
               when CALCCOLOR3 =>
                  dxR <= unsigned(div1.quotient(31 downto 0));
                  dyR <= unsigned(div2.quotient(31 downto 0));
                  dxG <= unsigned(div3.quotient(31 downto 0));
                  dyG <= unsigned(div4.quotient(31 downto 0));
                  dxB <= unsigned(div5.quotient(31 downto 0));
                  dyB <= unsigned(div6.quotient(31 downto 0));
                  mulStep <= 0;
                  if (div1.done = '1') then
                     state <= CALCCOLOR4;
                  end if;
                  
               when CALCCOLOR4 =>
                  mulStep <= mulStep + 1;
                  case (mulStep) is
                     when 0 => mulResult32clk <= mulResult32;
                     when 1 => mulResult32clk <= mulResult32; base_R <= base_R + mulResult32clk;
                     when 2 => mulResult32clk <= mulResult32; base_G <= base_G + mulResult32clk;   
                     when 3 => mulResult32clk <= mulResult32; base_B <= base_B + mulResult32clk;
                     when 4 => mulResult32clk <= mulResult32; base_R <= base_R + mulResult32clk;
                     when 5 => mulResult32clk <= mulResult32; base_G <= base_G + mulResult32clk;
                     when 6 =>                                               
                        base_B <= base_B + mulResult32clk;
                        if (rec_texture = '1') then
                           state <= CALCTEXTURE1;
                        else
                           state <= PREPAREHALF;
                        end if;
                     when others => null;
                  end case;
                  
               when CALCTEXTURE1 =>
                  mulStep <= 0;
                  state   <= CALCTEXTURE2;
                  diffU10 <=  ('0' & signed(vt(1).u)) - ('0' & signed(vt(0).u));
                  diffU21 <=  ('0' & signed(vt(2).u)) - ('0' & signed(vt(1).u));
                  diffV10 <=  ('0' & signed(vt(1).v)) - ('0' & signed(vt(0).v));
                  diffV21 <=  ('0' & signed(vt(2).v)) - ('0' & signed(vt(1).v));
                  
               when CALCTEXTURE2 =>
                  mulStep <= mulStep + 1;
                  div1.divisor   <= to_signed(denom, 25);
                  div2.divisor   <= to_signed(denom, 25);
                  div3.divisor   <= to_signed(denom, 25);
                  div4.divisor   <= to_signed(denom, 25);
                  case (mulStep) is
                     when 0 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2;
                     when 1 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2; div1.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";
                     when 2 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2; div2.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";  
                     when 3 => muldivResult1clk <= muldivResult1; muldivResult2clk <= muldivResult2; div3.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";
                     when 4 =>                                                             
                        div4.dividend <= resize(muldivResult1clk - muldivResult2clk, 33) & x"000";
                        state  <= CALCTEXTURE3;
                        div1.start     <= '1';
                        div2.start     <= '1';
                        div3.start     <= '1';
                        div4.start     <= '1';
                     when others => null;
                  end case;
               
               when CALCTEXTURE3 =>
                  dxU <= unsigned(div1.quotient(31 downto 0));
                  dyU <= unsigned(div2.quotient(31 downto 0));
                  dxV <= unsigned(div3.quotient(31 downto 0));
                  dyV <= unsigned(div4.quotient(31 downto 0));
                  mulStep <= 0;
                  if (div1.done = '1') then
                     state <= CALCTEXTURE4;
                  end if;
                  
               when CALCTEXTURE4 =>
                  mulStep <= mulStep + 1;
                  case (mulStep) is
                     when 0 => mulResult32clk <= mulResult32;
                     when 1 => mulResult32clk <= mulResult32; base_U <= base_U + mulResult32clk;
                     when 2 => mulResult32clk <= mulResult32; base_V <= base_V + mulResult32clk;   
                     when 3 => mulResult32clk <= mulResult32; base_U <= base_U + mulResult32clk;
                     when 4 =>                                               
                        base_V <= base_V + mulResult32clk;
                        state <= PREPAREHALF;
                     when others => null;
                  end case;
                  
               when PREPAREHALF =>
                  state <= PREPARELINE;
                  if (firsthalf = '1') then
                     firsthalf  <= '0';
                     secondhalf <= '1';
                     yCoord     <= vt(vo).y;
                     yBound     <= vt(1-vo).y;
                     calc1      := (to_signed(vt(vo).x, 13) & x"00000000") + x"100000000" - 2048;
                     calc2      := baseCoord + vo_diff_base;
                     if (rightFacing = 0) then
                        xStart     <= calc1;
                        xStepStart <= boundCoordUs;
                        xEnd       <= calc2;
                        xStepEnd   <= baseStep;
                     else
                        xStart     <= calc2;
                        xStepStart <= baseStep;
                        xEnd       <= calc1;
                        xStepEnd   <= boundCoordUs;
                     end if;
                     decMode    <= vo;
                     if (vo = 1) then
                        state <= PREPAREDECMODE;
                     end if;
                  else
                     secondhalf <= '0';
                     yCoord     <= vt(1 + vp).y;
                     yBound     <= vt(2 - vp).y;
                     calc3      := (to_signed(vt(1 + vp).x, 13) & x"00000000") + x"100000000" - 2048;
                     calc4      := baseCoord + vp_diff_base;
                     if (rightFacing = 0) then
                        xStart     <= calc3;
                        xStepStart <= boundCoordLs;
                        xEnd       <= calc4;
                        xStepEnd   <= baseStep;
                     else
                        xStart     <= calc4;
                        xStepStart <= baseStep;
                        xEnd       <= calc3;
                        xStepEnd   <= boundCoordLs;
                     end if;
                     decMode    <= vp;
                     if (vp = 1) then
                        state <= PREPAREDECMODE;
                     end if;
                  end if;
                  
                  filter_on <= '0';
                  if (textureFilter = '1' and rec_dithering = '1' and drawmode_dithering = '1' and (dxV /= 0 or dyU /= 0)) then
                     filter_on <= '1';
                  end if;
                  
               when PREPAREDECMODE =>
                  state  <= PREPARELINE;
                  yCoord <= yCoord - 1;
                  xStart <= xStart - xStepStart;
                  xEnd   <= xEnd   - xStepEnd;
                  
               when PREPARELINE =>
                  if (xStart(43 downto 32) < 0) then
                     xPos  <= (others => '0');
                  else
                     xPos  <= xStart(43 downto 32);
                  end if;
                  yPos  <= to_signed(yCoord, 11);
                  xStop <= xEnd(43 downto 32);
                  if (xStart(43 downto 32) < 0 and xEnd(43 downto 32) > 1023) then
                     xSize <= to_unsigned(1024, 11);
                  elsif (xStart(43 downto 32) >= 0 and xEnd(43 downto 32) > 1023) then
                     xSize <= to_unsigned(1024, 11) - unsigned(xStart(41 downto 32));
                  else 
                     xSize <= ('0' & (unsigned(xEnd(41 downto 32)) - unsigned(xStart(41 downto 32)))) + 1;
                  end if;
               
                  if (rec_transparency = '1' or DrawPixelsMask = '1') then
                     state <= REQUESTLINE;
                  else
                     state <= PROCPIXELS;
                  end if;
                  
-- check required to prevent simulation errors for multiplying negative value with unsigned
-- synthesis translate_off
                  if (yCoord >= 0) then
-- synthesis translate_on
                  if (rec_shading = '1') then
                     if (xStart(43 downto 32) < 0) then
                        work_R <= base_R + resize(dyR * yCoord, 32);
                        work_G <= base_G + resize(dyG * yCoord, 32);
                        work_B <= base_B + resize(dyB * yCoord, 32);
                     else
                        work_R <= base_R + resize(dxR * to_integer(xStart(43 downto 32)), 32) + resize(dyR * yCoord, 32);
                        work_G <= base_G + resize(dxG * to_integer(xStart(43 downto 32)), 32) + resize(dyG * yCoord, 32);
                        work_B <= base_B + resize(dxB * to_integer(xStart(43 downto 32)), 32) + resize(dyB * yCoord, 32);
                     end if;
                  else
                     work_R <= base_R;
                     work_G <= base_G;
                     work_B <= base_B;
                  end if;
                  
                  if (rec_texture = '1') then
                     if (xStart(43 downto 32) < 0) then
                        work_U <= base_U + resize(dyU * yCoord, 32);
                        work_V <= base_V + resize(dyV * yCoord, 32);
                     else
                        work_U <= base_U + resize(dxU * to_integer(xStart(43 downto 32)), 32) + resize(dyU * yCoord, 32);
                        work_V <= base_V + resize(dxV * to_integer(xStart(43 downto 32)), 32) + resize(dyV * yCoord, 32);
                     end if;
                  else
                     work_U <= base_U;
                     work_V <= base_V;
                  end if;
-- synthesis translate_off
                  end if;
-- synthesis translate_on
                  
                  
                  stop := '0';
                  skip := '0';
                  
                  if (xStart(43 downto 32) = xEnd(43 downto 32)) then
                     skip := '1';
                  end if;
                  
                  if (to_integer(xStart(43 downto 32)) > drawingAreaRight) then
                     skip := '1';
                  end if;                  
                  
                  if (xEnd(43 downto 32) <= 0) then
                     skip := '1';
                  end if;
                  
                  if (interlacedDrawing = '1' and (activeLineLSB = to_signed(yCoord, 12)(0))) then
                     skip := '1';
                  end if;
                  
                  if (decMode = 1) then
                     if (to_signed(yCoord, 11) < to_integer(drawingAreaTop))    then stop := '1'; end if;
                     if (to_signed(yCoord, 11) > to_integer(drawingAreaBottom)) then skip := '1'; end if;
                  else
                     if (to_signed(yCoord, 11) > to_integer(drawingAreaBottom)) then stop := '1'; end if;
                     if (to_signed(yCoord, 11) < to_integer(drawingAreaTop))    then skip := '1'; end if;
                  end if;
                  
                  if (skip = '1') then
                     state  <= PREPARELINE;
                     if (decMode = 1) then
                        yCoord <= yCoord - 1;
                        xStart <= xStart - xStepStart;
                        xEnd   <= xEnd   - xStepEnd;
                     else
                        yCoord <= yCoord + 1;
                        xStart <= xStart + xStepStart;
                        xEnd   <= xEnd   + xStepEnd;
                     end if;
                  end if;
                  
                  if (decMode = 1) then
                     if (yCoord < yBound) then stop := '1'; end if;
                  else
                     if (yCoord >= yBound) then stop := '1'; end if;
                  end if;
                  
                  if (stop = '1') then
                     if (secondhalf = '1') then
                        state <= PREPAREHALF;
                     else
                        if (nextQuad = '1') then 
                           state <= ISSUE;
                        else
                           if (REPRODUCIBLEGPUTIMING = '1') then
                              state <= WAITIMING;
                           else
                              state <= IDLE;
                              done  <= '1';
                           end if;
                        end if;
                     end if;
                  end if;
                       
               when REQUESTLINE =>
                  if (pipeline_stall = '0' and requestVRAMIdle = '1') then
                     state  <= READWAIT;
                  end if;
                  
               when READWAIT =>
                  if (requestVRAMDone = '1') then
                     state <= PROCPIXELS;
                  end if;
               
               when PROCPIXELS =>
                  if (pipeline_stall = '0' and (firstPixel = '0' or pipeline_busy = '0')) then
                     firstPixel <= '0';
                     
                     xPos  <= xPos + 1;
                     
                     if (rec_shading = '1') then
                        work_R <= work_R + dxR;
                        work_G <= work_G + dxG;
                        work_B <= work_B + dxB;
                     end if;
                     
                     if (rec_texture = '1') then
                        work_U <= work_U + dxU;
                        work_V <= work_V + dxV;
                     end if;
                     
                     if (xPos + 1 >= xStop) then
                        if (decMode = 1) then
                           yCoord <= yCoord - 1;
                           xStart <= xStart - xStepStart;
                           xEnd   <= xEnd   - xStepEnd;
                           state  <= PREPARELINE;
                        else
                           yCoord <= yCoord + 1;
                           xStart <= xStart + xStepStart;
                           xEnd   <= xEnd   + xStepEnd;
                           state  <= PREPARELINE;
                        end if;
                     end if; 
                     
                     if (xPos >= to_integer(drawingAreaLeft) and xPos <= to_integer(drawingAreaRight)) then
                        pipeline_new         <= '1';
                        pipeline_texture     <= rec_texture;
                        pipeline_transparent <= rec_transparency;
                        pipeline_rawTexture  <= rec_rawTexture;
                        pipeline_dithering   <= rec_dithering;
                        pipeline_x           <= unsigned(xPos(9 downto 0));
                        pipeline_y           <= unsigned(yPos(8 downto 0));
                        pipeline_cr          <= work_R(19 downto 12);
                        pipeline_cg          <= work_G(19 downto 12);
                        pipeline_cb          <= work_B(19 downto 12);
                        pipeline_u           <= work_U(19 downto 12);
                        pipeline_v           <= work_V(19 downto 12);
                        
                        if (filter_on = '1') then
                           if    (xPos(0) = '0' and yPos(0) = '0') then uFilter := resize(work_U(19 downto 0), 21) + 16#400#; vFilter := resize(work_V(19 downto 0), 21) + 16#000#;
                           elsif (xPos(0) = '1' and yPos(0) = '0') then uFilter := resize(work_U(19 downto 0), 21) + 16#800#; vFilter := resize(work_V(19 downto 0), 21) + 16#C00#;
                           elsif (xPos(0) = '0' and yPos(0) = '1') then uFilter := resize(work_U(19 downto 0), 21) + 16#C00#; vFilter := resize(work_V(19 downto 0), 21) + 16#800#;
                           else                                         uFilter := resize(work_U(19 downto 0), 21) + 16#000#; vFilter := resize(work_V(19 downto 0), 21) + 16#400#;
                           end if;
                           
                           if (uFilter(20 downto 12) <= ('0' & filter_maxU)) then pipeline_u <= uFilter(19 downto 12); end if;
                           if (vFilter(20 downto 12) <= ('0' & filter_maxV)) then pipeline_v <= vFilter(19 downto 12); end if;
                        end if;
                        
                     end if;
                  end if;
                      
               when WAITIMING =>
                  if (clk2xIndex = '0' and drawTiming + 4 >= targetTiming) then
                     state <= IDLE;
                     done  <= '1';
                  end if;
                      
            end case;
         
         end if;
         
      end if;
   end process;


end architecture;


   