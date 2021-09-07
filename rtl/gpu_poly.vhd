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
      
      div1                 : inout div_type; 
      div2                 : inout div_type; 
      div3                 : inout div_type; 
      div4                 : inout div_type; 
      div5                 : inout div_type; 
      div6                 : inout div_type; 
      
      pipeline_stall       : in  std_logic;
      pipeline_new         : out std_logic := '0';
      pipeline_texture     : out std_logic := '0';
      pipeline_transparent : out std_logic := '0';
      pipeline_rawTexture  : out std_logic := '0';
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
      
      requestVRAMEnable    : out std_logic;
      requestVRAMXPos      : out unsigned(9 downto 0);
      requestVRAMYPos      : out unsigned(8 downto 0);
      requestVRAMSize      : out unsigned(10 downto 0);
      requestVRAMIdle      : in  std_logic;
      requestVRAMDone      : in  std_logic;
      
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
      CALCCOLOR5,
      CALCTEXTURE1,
      CALCTEXTURE2,
      CALCTEXTURE3,
      CALCTEXTURE4,
      CALCTEXTURE5,
      PREPAREHALF,
      PREPAREDECMODE,
      PREPARELINE,
      REQUESTLINE,
      READWAIT,
      PROCPIXELS
   );
   signal state     : tState := IDLE;
   
   signal rec_shading         : std_logic := '0';
   signal rec_quad            : std_logic := '0';
   signal rec_texture         : std_logic := '0';
   signal rec_transparency    : std_logic := '0';
   signal rec_rawTexture      : std_logic := '0';
   
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

   signal work_R              : unsigned(31 downto 0) := (others => '0');   
   signal work_G              : unsigned(31 downto 0) := (others => '0');   
   signal work_B              : unsigned(31 downto 0) := (others => '0');   
   signal work_U              : unsigned(31 downto 0) := (others => '0');   
   signal work_V              : unsigned(31 downto 0) := (others => '0'); 

   signal vo_diff             : integer range -4096 to 4095;
   signal vp_diff             : integer range -4096 to 4095;

   signal yCoord              : integer range -2048 to 2047; 
   signal yBound              : integer range -2048 to 2047; 
   signal xStart              : signed(44 downto 0) := (others => '0');
   signal xStepStart          : signed(44 downto 0) := (others => '0');
   signal xEnd                : signed(44 downto 0) := (others => '0');
   signal xStepEnd            : signed(44 downto 0) := (others => '0');
   signal decMode             : integer range 0 to 1;
   
   signal xPos                : signed(11 downto 0) := (others => '0'); 
   signal yPos                : signed(11 downto 0) := (others => '0'); 
   signal xStop               : signed(11 downto 0) := (others => '0'); 
   signal xSize               : unsigned(10 downto 0) := (others => '0'); 
   
begin 

   requestFifo <= '1' when (state = REQUESTCOLOR or state = REQUESTPOS or state = REQUESTTEXTURE) else '0';
   
   requestVRAMEnable <= '1'                        when (state = REQUESTLINE and pipeline_stall = '0') else '0';
   requestVRAMXPos   <= unsigned(xPos(9 downto 0)) when (state = REQUESTLINE and pipeline_stall = '0') else (others => '0');
   requestVRAMYPos   <= unsigned(yPos(8 downto 0)) when (state = REQUESTLINE and pipeline_stall = '0') else (others => '0');
   requestVRAMSize   <= xSize                      when (state = REQUESTLINE and pipeline_stall = '0') else (others => '0');
   
   vramLineEna  <= '1' when (state = PROCPIXELS) else '0';
   vramLineAddr <= unsigned(xPos(9 downto 0)) when (state = PROCPIXELS) else (others => '0');
   
   process (clk2x)
      variable dx1   : signed(44 downto 0);
      variable dx2   : signed(44 downto 0);
      variable dx3   : signed(44 downto 0);
      variable dy1   : signed(12 downto 0);
      variable dy2   : signed(12 downto 0);
      variable dy3   : signed(12 downto 0);
      variable calc1 : signed(44 downto 0);
      variable calc2 : signed(44 downto 0);
      variable calc3 : signed(44 downto 0);
      variable calc4 : signed(44 downto 0);
      variable stop  : std_logic;
      variable skip  : std_logic;
   begin
      if rising_edge(clk2x) then
         
         if (reset = '1') then
         
            state <= IDLE;
         
         elsif (ce = '1') then
         
            done                 <= '0';

            drawModeNew          <= '0';
            
            pipeline_new         <= '0';
            pipeline_texture     <= '0';
            pipeline_transparent <= '0';
            pipeline_rawTexture  <= '0';
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
            
            div1.dividend        <= (others => '0');
            div2.dividend        <= (others => '0');
            div3.dividend        <= (others => '0');
            div4.dividend        <= (others => '0');
            div5.dividend        <= (others => '0');
            div6.dividend        <= (others => '0');
            
            div1.divisor         <= (others => '0');
            div2.divisor         <= (others => '0');
            div3.divisor         <= (others => '0');
            div4.divisor         <= (others => '0');
            div5.divisor         <= (others => '0');
            div6.divisor         <= (others => '0');
         
            case (state) is
            
               when IDLE =>
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "001") then
                     state             <= REQUESTPOS;
                     rec_index         <= 0;
                     rec_shading       <= fifo_data(28);
                     rec_quad          <= fifo_data(27);
                     quadFirst         <= fifo_data(27);
                     rec_texture       <= fifo_data(26);
                     rec_transparency  <= fifo_data(25);
                     rec_rawTexture    <= fifo_data(24);
                     for i in 0 to 3 loop
                        rec_vertices(i).r <= unsigned(fifo_data( 7 downto  0));
                        rec_vertices(i).g <= unsigned(fifo_data(15 downto  8));
                        rec_vertices(i).b <= unsigned(fifo_data(23 downto 16));
                     end loop;
                  end if;
                              
               when REQUESTCOLOR =>
                  if (fifo_Valid = '1') then
                     state             <= REQUESTPOS;
                     rec_vertices(rec_index).r <= unsigned(fifo_data( 7 downto  0));
                     rec_vertices(rec_index).g <= unsigned(fifo_data(15 downto  8));
                     rec_vertices(rec_index).b <= unsigned(fifo_data(23 downto 16));
                  end if;   
                  
               when REQUESTPOS =>
                  if (fifo_Valid = '1') then
                     rec_vertices(rec_index).x <= to_integer(resize(signed(fifo_data(10 downto  0)),12) + resize(drawingOffsetX, 12));
                     rec_vertices(rec_index).y <= to_integer(resize(signed(fifo_data(26 downto 16)),12) + resize(drawingOffsetY, 12));
                     
                     if (rec_texture = '1') then
                        state    <= REQUESTTEXTURE;  
                     elsif ((rec_quad = '1' and rec_index = 3) or (rec_quad = '0' and rec_index = 2)) then
                        state    <= ISSUE;  
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
                  if (fifo_Valid = '1') then
                     rec_vertices(rec_index).u <= unsigned(fifo_data( 7 downto  0));
                     rec_vertices(rec_index).v <= unsigned(fifo_data(15 downto  8));
                     if (rec_index = 0) then
                        rec_textPalX  <= unsigned(fifo_data(21 downto 16)) & "0000";
                        rec_textPalY  <= unsigned(fifo_data(30 downto 22));
                     end if;
                     if (rec_index = 1) then
                        drawModeRec   <= unsigned(fifo_data(27 downto 16));
                        drawModeNew   <= '1';
                     end if;
                     
                     if ((rec_quad = '1' and rec_index = 3) or (rec_quad = '0' and rec_index = 2)) then
                        state    <= ISSUE;  
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
                     state <= IDLE;
                     done  <= '1';
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
               
               when CALCBOUNDARY2 =>
                  baseStep     <= div1.quotient;
                  
                  rightFacing <= 0;
                  if (vt(1).y = vt(0).y) then
                     boundCoordUs <= (others => '0');
                     if (vt(1).x = vt(0).x) then rightFacing  <= 1; end if;
                  else
                     if (div2.quotient > baseStep) then rightFacing  <= 1; end if;
                     boundCoordUs <= div2.quotient;
                  end if;
                  
                  if (vt(2).y = vt(1).y) then
                     boundCoordLs <= (others => '0');
                  else
                     boundCoordLs <= div3.quotient;
                  end if;
                  
                  vo_diff <= vt(vo).y - vt(0).y;
                  vp_diff <= vt(1 + vp).y - vt(0).y;
                  
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
                           state <= IDLE;
                           done  <= '1';
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
                  state <= CALCCOLOR2;
                  diffR10 <=  ('0' & signed(vt(1).r)) - ('0' & signed(vt(0).r));
                  diffR21 <=  ('0' & signed(vt(2).r)) - ('0' & signed(vt(1).r));
                  diffG10 <=  ('0' & signed(vt(1).g)) - ('0' & signed(vt(0).g));
                  diffG21 <=  ('0' & signed(vt(2).g)) - ('0' & signed(vt(1).g));
                  diffB10 <=  ('0' & signed(vt(1).b)) - ('0' & signed(vt(0).b));
                  diffB21 <=  ('0' & signed(vt(2).b)) - ('0' & signed(vt(1).b));
               
               when CALCCOLOR2 =>
                  state <= CALCCOLOR3;
               
                  div1.start     <= '1';
                  div1.dividend  <= resize((diffR10 * diffY21) - (diffR21 * diffY10), 33) & x"000";
                  div1.divisor   <= to_signed(denom, 25);
                  
                  div2.start     <= '1';
                  div2.dividend  <= resize((diffR21 * diffX10) - (diffR10 * diffX21), 33) & x"000";
                  div2.divisor   <= to_signed(denom, 25);
                  
                  div3.start     <= '1';
                  div3.dividend  <= resize((diffG10 * diffY21) - (diffG21 * diffY10), 33) & x"000";
                  div3.divisor   <= to_signed(denom, 25);
                                    
                  div4.start     <= '1';
                  div4.dividend  <= resize((diffG21 * diffX10) - (diffG10 * diffX21), 33) & x"000";
                  div4.divisor   <= to_signed(denom, 25);
                  
                  div5.start     <= '1';
                  div5.dividend  <= resize((diffB10 * diffY21) - (diffB21 * diffY10), 33) & x"000";
                  div5.divisor   <= to_signed(denom, 25);
                                    
                  div6.start     <= '1';
                  div6.dividend  <= resize((diffB21 * diffX10) - (diffB10 * diffX21), 33) & x"000";
                  div6.divisor   <= to_signed(denom, 25);
               
               when CALCCOLOR3 =>
                  dxR <= unsigned(div1.quotient(31 downto 0));
                  dyR <= unsigned(div2.quotient(31 downto 0));
                  dxG <= unsigned(div3.quotient(31 downto 0));
                  dyG <= unsigned(div4.quotient(31 downto 0));
                  dxB <= unsigned(div5.quotient(31 downto 0));
                  dyB <= unsigned(div6.quotient(31 downto 0));
                  if (div1.done = '1') then
                     state <= CALCCOLOR4;
                  end if;
                  
               when CALCCOLOR4 =>
                  state <= CALCCOLOR5;
                  base_R <= base_R - resize(dxR * vt(coreVertex).x, 32);
                  base_G <= base_G - resize(dxG * vt(coreVertex).x, 32);
                  base_B <= base_B - resize(dxB * vt(coreVertex).x, 32);
                     
               when CALCCOLOR5 =>
                  base_R <= base_R - resize(dyR * vt(coreVertex).y, 32);
                  base_G <= base_G - resize(dyG * vt(coreVertex).y, 32);
                  base_B <= base_B - resize(dyB * vt(coreVertex).y, 32);
                  if (rec_texture = '1') then
                     state <= CALCTEXTURE1;
                  else
                     state <= PREPAREHALF;
                  end if;
                  
               when CALCTEXTURE1 =>
                  diffU10 <=  ('0' & signed(vt(1).u)) - ('0' & signed(vt(0).u));
                  diffU21 <=  ('0' & signed(vt(2).u)) - ('0' & signed(vt(1).u));
                  diffV10 <=  ('0' & signed(vt(1).v)) - ('0' & signed(vt(0).v));
                  diffV21 <=  ('0' & signed(vt(2).v)) - ('0' & signed(vt(1).v));
                  state <= CALCTEXTURE2;
                  
               when CALCTEXTURE2 =>
                  state <= CALCTEXTURE3;
                  
                  div1.start     <= '1';
                  div1.dividend  <= resize((diffU10 * diffY21) - (diffU21 * diffY10), 33) & x"000";
                  div1.divisor   <= to_signed(denom, 25);
                                    
                  div2.start     <= '1';
                  div2.dividend  <= resize((diffU21 * diffX10) - (diffU10 * diffX21), 33) & x"000";
                  div2.divisor   <= to_signed(denom, 25);
                                    
                  div3.start     <= '1';
                  div3.dividend  <= resize((diffV10 * diffY21) - (diffV21 * diffY10), 33) & x"000";
                  div3.divisor   <= to_signed(denom, 25);
                                    
                  div4.start     <= '1';
                  div4.dividend  <= resize((diffV21 * diffX10) - (diffV10 * diffX21), 33) & x"000";
                  div4.divisor   <= to_signed(denom, 25);
               
               when CALCTEXTURE3 =>
                  dxU <= unsigned(div1.quotient(31 downto 0));
                  dyU <= unsigned(div2.quotient(31 downto 0));
                  dxV <= unsigned(div3.quotient(31 downto 0));
                  dyV <= unsigned(div4.quotient(31 downto 0));
                  if (div1.done = '1') then
                     state <= CALCTEXTURE4;
                  end if;
                  
               when CALCTEXTURE4 =>
                  state <= CALCTEXTURE5;
                  base_U <= base_U - resize(dxU * vt(coreVertex).x, 32);
                  base_V <= base_V - resize(dxV * vt(coreVertex).x, 32);
               
               when CALCTEXTURE5 =>
                  state <= PREPAREHALF;
                  base_U <= base_U - resize(dyU * vt(coreVertex).y, 32);
                  base_V <= base_V - resize(dyV * vt(coreVertex).y, 32);
                  
               when PREPAREHALF =>
                  state <= PREPARELINE;
                  if (firsthalf = '1') then
                     firsthalf  <= '0';
                     secondhalf <= '1';
                     yCoord     <= vt(vo).y;
                     yBound     <= vt(1-vo).y;
                     calc1      := (to_signed(vt(vo).x, 13) & x"00000000") + x"100000000" - 2048;
                     calc2      := baseCoord + resize(vo_diff * baseStep, 45);
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
                     calc4      := baseCoord + resize(vp_diff * baseStep, 45);
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
                  
               when PREPAREDECMODE =>
                  state  <= PREPARELINE;
                  yCoord <= yCoord - 1;
                  xStart <= xStart - xStepStart;
                  xEnd   <= xEnd   - xStepEnd;
                  
               when PREPARELINE =>
                  xPos  <= xStart(43 downto 32);
                  yPos  <= to_signed(yCoord, 12);
                  xStop <= xEnd(43 downto 32);
                  if (xStart(43 downto 32) < 0 and xEnd(43 downto 32) > 1023) then
                     xSize <= to_unsigned(1024, 11);
                  elsif (xStart(43 downto 32) >= 0 and xEnd(43 downto 32) > 1023) then
                     xSize <= to_unsigned(1024, 11) - unsigned(xStart(41 downto 32));
                  else 
                     xSize <= ('0' & (unsigned(xEnd(41 downto 32)) - unsigned(xStart(41 downto 32)))) + 1;
                  end if;
               
                  if (rec_transparency = '1') then
                     state <= REQUESTLINE;
                  else
                     state <= PROCPIXELS;
                  end if;
                  
                  if (rec_shading = '1') then
                     work_R <= base_R + resize(dxR * to_integer(xStart(43 downto 32)), 32) + resize(dyR * yCoord, 32);
                     work_G <= base_G + resize(dxG * to_integer(xStart(43 downto 32)), 32) + resize(dyG * yCoord, 32);
                     work_B <= base_B + resize(dxB * to_integer(xStart(43 downto 32)), 32) + resize(dyB * yCoord, 32);
                  else
                     work_R <= base_R;
                     work_G <= base_G;
                     work_B <= base_B;
                  end if;
                  
                  if (rec_texture = '1') then
                     work_U <= base_U + resize(dxU * to_integer(xStart(43 downto 32)), 32) + resize(dyU * yCoord, 32);
                     work_V <= base_V + resize(dxV * to_integer(xStart(43 downto 32)), 32) + resize(dyV * yCoord, 32);
                  else
                     work_U <= base_U;
                     work_V <= base_V;
                  end if;
                  
                  stop := '0';
                  skip := '0';
                  
                  if (xStart(43 downto 32) = xEnd(43 downto 32)) then
                     skip := '1';
                  end if;
                  
                  if (to_integer(xStart(43 downto 32)) > drawingAreaRight) then
                     skip := '1';
                  end if;
                  
                  if (interlacedDrawing = '1' and (activeLineLSB = to_signed(yCoord, 12)(0))) then
                     skip := '1';
                  end if;
                  
                  if (decMode = 1) then
                     if (yCoord < drawingAreaTop)    then stop := '1'; end if;
                     if (yCoord > drawingAreaBottom) then skip := '1'; end if;
                  else
                     if (yCoord > drawingAreaBottom) then stop := '1'; end if;
                     if (yCoord < drawingAreaTop)    then skip := '1'; end if;
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
                           state <= IDLE;
                           done  <= '1';
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
                  if (pipeline_stall = '0') then
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
                        pipeline_x           <= unsigned(xPos(9 downto 0));
                        pipeline_y           <= unsigned(yPos(8 downto 0));
                        pipeline_cr          <= work_R(19 downto 12);
                        pipeline_cg          <= work_G(19 downto 12);
                        pipeline_cb          <= work_B(19 downto 12);
                        pipeline_u           <= work_U(19 downto 12);
                        pipeline_v           <= work_V(19 downto 12);
                     end if;
                  end if;
                       
            end case;
         
         end if;
         
      end if;
   end process;


end architecture;


   