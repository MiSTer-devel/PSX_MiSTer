-----------------------------------------------------------------
--------------- Export Package  --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pexport is

   type tExportRegs is array(0 to 31) of unsigned(31 downto 0);
   signal regs                   : tExportRegs;

   type cpu_export_type is record
      regs           : tExportRegs;
      pc             : unsigned(31 downto 0);
      opcode         : unsigned(31 downto 0);
      cause          : unsigned(31 downto 0);
   end record;
  
end package;

-----------------------------------------------------------------
--------------- Export module    --------------------------------
-----------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
use STD.textio.all;

use work.pexport.all;

entity export is
   port 
   (
      clk               : in std_logic;
      ce                : in std_logic;
      reset             : in std_logic;
         
      new_export        : in std_logic;
      export_cpu        : in cpu_export_type;    
         
      export_irq        : in unsigned(15 downto 0);
         
      export_gtm        : in unsigned(11 downto 0);
      export_line       : in unsigned(11 downto 0);
      export_gpus       : in unsigned(31 downto 0);
      export_gobj       : in unsigned(15 downto 0);
      
      export_t_current0 : in unsigned(15 downto 0);
      export_t_current1 : in unsigned(15 downto 0);
      export_t_current2 : in unsigned(15 downto 0);
      
      export_8          : in std_logic_vector(7 downto 0);
      export_16         : in std_logic_vector(15 downto 0);
      export_32         : in std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of export is
     
   signal newticks               : unsigned(11 downto 0) := (others => '0');
   signal totalticks             : unsigned(31 downto 0) := (others => '0');
   signal cyclenr                : unsigned(31 downto 0) := x"00000001";
                  
   signal reset_1                : std_logic := '0';
   signal export_reset           : std_logic := '0';
   signal exportnow              : std_logic;
            
   signal export_cpu_last        : cpu_export_type := ((others => (others => '0')), (others => '0'), (others => '0'), (others => '0'));   
         
   signal export_irq_last        : unsigned(15 downto 0) := (others => '0');
            
   signal export_gtm_last        : unsigned(11 downto 0) := (others => '0');
   signal export_line_last       : unsigned(11 downto 0) := (others => '0');
   signal export_gpus_last       : unsigned(31 downto 0) := (others => '0');
   signal export_gobj_last       : unsigned(15 downto 0) := (others => '0');
   signal export_t_current0_last : unsigned(15 downto 0) := (others => '0');
   signal export_t_current1_last : unsigned(15 downto 0) := (others => '0');
   signal export_t_current2_last : unsigned(15 downto 0) := (others => '0');
   
   function to_lower(c: character) return character is
      variable l: character;
   begin
       case c is
        when 'A' => l := 'a';
        when 'B' => l := 'b';
        when 'C' => l := 'c';
        when 'D' => l := 'd';
        when 'E' => l := 'e';
        when 'F' => l := 'f';
        when 'G' => l := 'g';
        when 'H' => l := 'h';
        when 'I' => l := 'i';
        when 'J' => l := 'j';
        when 'K' => l := 'k';
        when 'L' => l := 'l';
        when 'M' => l := 'm';
        when 'N' => l := 'n';
        when 'O' => l := 'o';
        when 'P' => l := 'p';
        when 'Q' => l := 'q';
        when 'R' => l := 'r';
        when 'S' => l := 's';
        when 'T' => l := 't';
        when 'U' => l := 'u';
        when 'V' => l := 'v';
        when 'W' => l := 'w';
        when 'X' => l := 'x';
        when 'Y' => l := 'y';
        when 'Z' => l := 'z';
        when others => l := c;
    end case;
    return l;
   end to_lower;
   
   function to_lower(s: string) return string is
     variable lowercase: string (s'range);
   begin
     for i in s'range loop
        lowercase(i):= to_lower(s(i));
     end loop;
     return lowercase;
   end to_lower;
     
begin  
 
-- synthesis translate_off
   process(clk)
   begin
      if rising_edge(clk) then
         if (reset = '1') then
            totalticks <= (others => '0');
            newticks   <= (others => '0');
         elsif (ce = '1') then
            totalticks <= totalticks + 1;
            newticks   <= newticks + 1;
            if (exportnow = '1') then
               newticks   <= x"001";
            end if;
         end if;
         reset_1 <= reset;
      end if;
   end process;
   
   export_reset <= '1' when (reset = '0' and reset_1 = '1') else '0';
   
   exportnow <=  new_export;

   process
   
      file outfile: text;
      file outfile_irp: text;
      variable f_status: FILE_OPEN_STATUS;
      variable line_out : line;
      variable recordcount : integer := 0;
      
      constant filenamebase               : string := "R:\\debug_sim";
      variable filename_current           : string(1 to 25);
      
   begin
   
      filename_current := filenamebase & "00000000.txt";
   
      file_open(f_status, outfile, filename_current, write_mode);
      file_close(outfile);
      file_open(f_status, outfile, filename_current, append_mode); 
      
      while (true) loop
         wait until rising_edge(clk);
         if (reset = '1') then
            cyclenr <= x"00000001";
            filename_current := filenamebase & "00000000.txt";
            file_close(outfile);
            file_open(f_status, outfile, filename_current, write_mode);
            file_close(outfile);
            file_open(f_status, outfile, filename_current, append_mode);
         end if;
         
         if (exportnow = '1') then
         
            write(line_out, string'("# "));
            write(line_out, to_lower(to_hstring(totalticks - 1)) & " ");
            
            write(line_out, string'("# "));
            write(line_out, to_lower(to_hstring(newticks)) & " ");
            
            write(line_out, string'("PC "));
            write(line_out, to_lower(to_hstring(export_cpu.pc)) & " ");
            
            write(line_out, string'("OP "));
            write(line_out, to_lower(to_hstring(export_cpu.opcode)) & " ");
            
            for i in 0 to 31 loop
               if (export_cpu.regs(i) /= export_cpu_last.regs(i)) then
                  write(line_out, string'("R"));
                  if (i < 10) then 
                     write(line_out, string'("0"));
                  end if;
                  write(line_out, to_lower(to_string(i)));
                  write(line_out, string'(" "));
                  write(line_out, to_lower(to_hstring(export_cpu.regs(i))) & " ");
               end if;
            end loop; 

            if (export_cpu.cause /= export_cpu_last.cause)   then write(line_out, string'("CAUSE "));  write(line_out, to_lower(to_hstring(export_cpu.cause)) & " "); end if;
            
            if (export_irq /= export_irq_last)   then write(line_out, string'("IRQ "));  write(line_out, to_lower(to_hstring(export_irq)) & " "); end if;
            
            if (export_gtm /= export_gtm_last)   then write(line_out, string'("GTM "));  write(line_out, to_lower(to_hstring(export_gtm)) & " "); end if;
            if (export_line /= export_line_last) then write(line_out, string'("LINE ")); write(line_out, to_lower(to_hstring(export_line)) & " "); end if;
            if (export_gpus /= export_gpus_last) then write(line_out, string'("GPUS ")); write(line_out, to_lower(to_hstring(export_gpus)) & " "); end if;
            if (export_gobj /= export_gobj_last) then write(line_out, string'("GOBJ ")); write(line_out, to_lower(to_hstring(export_gobj)) & " "); end if;
            
            if (export_t_current0 /= export_t_current0_last) then write(line_out, string'("T0 ")); write(line_out, to_lower(to_hstring(export_t_current0)) & " "); end if;
            if (export_t_current1 /= export_t_current1_last) then write(line_out, string'("T1 ")); write(line_out, to_lower(to_hstring(export_t_current1)) & " "); end if;
            if (export_t_current2 /= export_t_current2_last) then write(line_out, string'("T2 ")); write(line_out, to_lower(to_hstring(export_t_current2)) & " "); end if;


            writeline(outfile, line_out);
            
            cyclenr     <= cyclenr + 1;
            
            if (cyclenr mod 10000000 = 0) then
               filename_current := filenamebase & to_hstring(cyclenr) & ".txt";
               file_close(outfile);
               file_open(f_status, outfile, filename_current, write_mode);
               file_close(outfile);
               file_open(f_status, outfile, filename_current, append_mode);
            end if;
            
            export_cpu_last         <= export_cpu;
            export_irq_last         <= export_irq;
            export_gtm_last         <= export_gtm;
            export_line_last        <= export_line;
            export_gpus_last        <= export_gpus;
            export_gobj_last        <= export_gobj;
            export_t_current0_last  <= export_t_current0;
            export_t_current1_last  <= export_t_current1;
            export_t_current2_last  <= export_t_current2;
            
         end if;
            
      end loop;
      
   end process;
-- synthesis translate_on

end architecture;





