library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;  

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity SyncRamDualByteEnable is
   generic 
   (
      is_simu     : std_logic;
      is_cyclone5 : std_logic := '0';
      BYTE_WIDTH  : natural := 8;
      ADDR_WIDTH  : natural := 6;
      BYTES       : natural := 4
   );
   port 
   (
      clk        : in std_logic;
      
      addr_a     : in natural range 0 to 2**ADDR_WIDTH - 1;
      datain_a0  : in std_logic_vector((BYTE_WIDTH-1) downto 0);
      datain_a1  : in std_logic_vector((BYTE_WIDTH-1) downto 0);
      datain_a2  : in std_logic_vector((BYTE_WIDTH-1) downto 0);
      datain_a3  : in std_logic_vector((BYTE_WIDTH-1) downto 0);
      dataout_a  : out std_logic_vector((BYTES*BYTE_WIDTH-1) downto 0);
      we_a       : in std_logic := '1';
      be_a       : in  std_logic_vector (BYTES - 1 downto 0);
		            
      addr_b     : in natural range 0 to 2**ADDR_WIDTH - 1;
      datain_b0  : in std_logic_vector((BYTE_WIDTH-1) downto 0);
      datain_b1  : in std_logic_vector((BYTE_WIDTH-1) downto 0);
      datain_b2  : in std_logic_vector((BYTE_WIDTH-1) downto 0);
      datain_b3  : in std_logic_vector((BYTE_WIDTH-1) downto 0);
      dataout_b  : out std_logic_vector((BYTES*BYTE_WIDTH-1) downto 0);
      we_b       : in std_logic := '1';
      be_b       : in  std_logic_vector (BYTES - 1 downto 0)
   );
end;

architecture rtl of SyncRamDualByteEnable is
	--  build up 2D array to hold the memory
	type word_t is array (0 to BYTES-1) of std_logic_vector(BYTE_WIDTH-1 downto 0);
	type ram_t is array (0 to 2 ** ADDR_WIDTH - 1) of word_t;

	signal ram : ram_t := (others => (others => (others => '0')));
	signal q1_local : word_t;
	signal q2_local : word_t;  

begin

   gsynth : if is_simu = '0' and is_cyclone5 = '0' generate
   begin
      -- Reorganize the read data from the RAM to match the output
      unpack: for i in 0 to BYTES - 1 generate    
         dataout_a(BYTE_WIDTH*(i+1) - 1 downto BYTE_WIDTH*i) <= q1_local(i);
         dataout_b(BYTE_WIDTH*(i+1) - 1 downto BYTE_WIDTH*i) <= q2_local(i);    
      end generate unpack;
   
      process(clk)
      begin
         if(rising_edge(clk)) then 
            if(we_a = '1') then
               -- edit this code if using other than four bytes per word
               if(be_a(0) = '1') then
                  ram(addr_a)(0) <= datain_a0;
               end if;
               if be_a(1) = '1' then
                  ram(addr_a)(1) <= datain_a1;
               end if;
               if be_a(2) = '1' then
                  ram(addr_a)(2) <= datain_a2;
               end if;
               if be_a(3) = '1' then
                  ram(addr_a)(3) <= datain_a3;
               end if;
            end if;
            q1_local <= ram(addr_a);
         end if;
      end process;
   
      process(clk)
      begin
         if(rising_edge(clk)) then 
            if(we_b = '1') then
                  -- edit this code if using other than four bytes per word
               if(be_b(0) = '1') then
                  ram(addr_b)(0) <= datain_b0;
               end if;
               if be_b(1) = '1' then
                  ram(addr_b)(1) <= datain_b1;
               end if;
               if be_b(2) = '1' then
                  ram(addr_b)(2) <= datain_b2;
               end if;
               if be_b(3) = '1' then
                  ram(addr_b)(3) <= datain_b3;
               end if;
            end if;
            q2_local <= ram(addr_b);
         end if;
      end process;  
   end generate;
        
   gsynth_cyclone5 : if is_simu = '0' and is_cyclone5 = '1' generate
      signal data_a : std_logic_vector((BYTES*BYTE_WIDTH-1) downto 0);
      signal data_b : std_logic_vector((BYTES*BYTE_WIDTH-1) downto 0);
      
      signal addr_a_slv : std_logic_vector(ADDR_WIDTH-1 downto 0);
      signal addr_b_slv : std_logic_vector(ADDR_WIDTH-1 downto 0);
      
   begin
      
      data_a <= datain_a3 & datain_a2 & datain_a1 & datain_a0;
      data_b <= datain_b3 & datain_b2 & datain_b1 & datain_b0;
      
      addr_a_slv <= std_logic_vector(to_unsigned(addr_a, ADDR_WIDTH));
      addr_b_slv <= std_logic_vector(to_unsigned(addr_b, ADDR_WIDTH));
      
      altsyncram_component : altsyncram
      GENERIC MAP (
         address_reg_b => "CLOCK1",
         clock_enable_input_a => "NORMAL",
         clock_enable_input_b => "NORMAL",
         clock_enable_output_a => "BYPASS",
         clock_enable_output_b => "BYPASS",
         indata_reg_b => "CLOCK1",
         intended_device_family => "Cyclone V",
         lpm_type => "altsyncram",
         numwords_a => 2**ADDR_WIDTH,
         numwords_b => 2**ADDR_WIDTH,
         operation_mode => "BIDIR_DUAL_PORT",
         outdata_aclr_a => "NONE",
         outdata_aclr_b => "NONE",
         outdata_reg_a => "UNREGISTERED",
         outdata_reg_b => "UNREGISTERED",
         power_up_uninitialized => "FALSE",
         read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
         read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
         init_file => " ", 
         widthad_a => ADDR_WIDTH,
         widthad_b => ADDR_WIDTH,
         width_a => BYTES*BYTE_WIDTH,
         width_b => BYTES*BYTE_WIDTH,
         width_byteena_a => 4,
         width_byteena_b => 4,
         wrcontrol_wraddress_reg_b => "CLOCK1"
      )
      PORT MAP (
         address_a => addr_a_slv,
         address_b => addr_b_slv,
         clock0 => clk,
         clock1 => clk,
         clocken0 => '1',
         clocken1 => '1',
         data_a => data_a,
         data_b => data_b,
         wren_a => we_a,
         wren_b => we_b,
         q_a => dataout_a,
         q_b => dataout_b,
         byteena_a => be_a,
         byteena_b => be_b
      );

   end generate;
   
   gsimu : if is_simu = '1' generate
   begin
      -- Reorganize the read data from the RAM to match the output
      unpack: for i in 0 to BYTES - 1 generate    
         dataout_a(BYTE_WIDTH*(i+1) - 1 downto BYTE_WIDTH*i) <= q1_local(i);
         dataout_b(BYTE_WIDTH*(i+1) - 1 downto BYTE_WIDTH*i) <= q2_local(i);    
      end generate unpack;
   
   
      process(clk)
      begin
         if(rising_edge(clk)) then 
            if(we_a = '1') then
               -- edit this code if using other than four bytes per word
               if(be_a(0) = '1') then
                  ram(addr_a)(0) <= datain_a0;
               end if;
               if be_a(1) = '1' then
                  ram(addr_a)(1) <= datain_a1;
               end if;
               if be_a(2) = '1' then
                  ram(addr_a)(2) <= datain_a2;
               end if;
               if be_a(3) = '1' then
                  ram(addr_a)(3) <= datain_a3;
               end if;
            end if;
            q1_local <= ram(addr_a);
   
            if(we_b = '1') then
                  -- edit this code if using other than four bytes per word
               if(be_b(0) = '1') then
                  ram(addr_b)(0) <= datain_b0;
               end if;
               if be_b(1) = '1' then
                  ram(addr_b)(1) <= datain_b1;
               end if;
               if be_b(2) = '1' then
                  ram(addr_b)(2) <= datain_b2;
               end if;
               if be_b(3) = '1' then
                  ram(addr_b)(3) <= datain_b3;
               end if;
            end if;
            q2_local <= ram(addr_b);
         end if;
      end process;  
   end generate;
  
end rtl;