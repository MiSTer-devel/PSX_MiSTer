library ieee;
use ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all; 

entity RamMLAB is
   generic 
   (
      width           :  natural;
      width_byteena   :  natural := 1;
      widthad         :  natural
   );
   port 
   (
      inclock         : in std_logic;
      wren            : in std_logic;
      data            : in std_logic_vector(width-1 downto 0);
      wraddress       : in std_logic_vector(widthad-1 downto 0);
      rdaddress       : in std_logic_vector(widthad-1 downto 0);
      q               : out std_logic_vector(width-1 downto 0)
   );
end;

architecture rtl of RamMLAB is

begin

      ialtdpram : altdpram
      GENERIC MAP 
      (
         indata_aclr                         => "OFF",
         indata_reg                          => "INCLOCK",
         intended_device_family              => "Cyclone V",
         lpm_type                            => "altdpram",
         outdata_aclr                        => "OFF",
         outdata_reg                         => "UNREGISTERED",
         ram_block_type                      => "MLAB",
         rdaddress_aclr                      => "OFF",
         rdaddress_reg                       => "UNREGISTERED",
         rdcontrol_aclr                      => "OFF",
         rdcontrol_reg                       => "UNREGISTERED",
         read_during_write_mode_mixed_ports  => "CONSTRAINED_DONT_CARE",
         width                               => width,
         widthad                             => widthad,
         width_byteena                       => width_byteena,
         wraddress_aclr                      => "OFF",
         wraddress_reg                       => "INCLOCK",
         wrcontrol_aclr                      => "OFF",
         wrcontrol_reg                       => "INCLOCK"
      )
      PORT MAP (
         inclock    => inclock,  
         wren       => wren,     
         data       => data,     
         wraddress  => wraddress,
         rdaddress  => rdaddress,
         q          => q        
      );

end rtl;