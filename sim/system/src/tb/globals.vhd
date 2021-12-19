library ieee;
use ieee.std_logic_1164.all;

package globals is

  signal COMMAND_FILE_ENDIAN  : std_logic;
  signal COMMAND_FILE_NAME    : string(1 to 1024);
  signal COMMAND_FILE_NAMELEN : integer;
  signal COMMAND_FILE_TARGET  : integer;
  signal COMMAND_FILE_OFFSET  : integer;
  signal COMMAND_FILE_SIZE    : integer;
  signal COMMAND_FILE_START_1 : std_logic;
  signal COMMAND_FILE_ACK_1   : std_logic;  
  signal COMMAND_FILE_START_2 : std_logic;
  signal COMMAND_FILE_ACK_2   : std_logic;
  
end package globals;