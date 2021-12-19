require("vsim_comm")
require("luareg")

function SplitFilename(strFilename)
   -- Returns the Path, Filename, and Extension as 3 values
   return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
end

function FindArray(array, pattern_in)

   pattern = {}

   for i = 1, #pattern_in do
      pattern[i] = string.sub(pattern_in, i, i)
   end

   local success = 0
   for i = 1, #array do
      if (array[i] == pattern[success + 1]) then
         success = success + 1
      else
         success = 0
      end
  
      if (#pattern == success) then
         return true
      end
   end
   
   return false
end

gba_savegame_path = ""
gba_loadsavegame = false

function transmit_rom(filename, baseaddress, transmit_dwords)

   -- load filecontent as binary
   local filecontent_char = {}

   local filecontent = {}
   local index = 0
   local input = io.open(filename, "rb")
   local dwordsum = 0
   local dwordpos = 0
   local byteindex = 0
   while true do
      local byte = input:read(1)
      if not byte then 
            if (dwordpos > 0) then
               filecontent[index] = dwordsum
            end
         break 
      end
      filecontent_char[#filecontent_char + 1] = string.char(string.byte(byte))
      --dwordsum = dwordsum + (string.byte(byte) * (2^((3 - dwordpos) * 8)))  -- little endian
      dwordsum = dwordsum + (string.byte(byte) * (2^((dwordpos) * 8))) -- big endian
      dwordpos = dwordpos + 1
      byteindex = byteindex + 1
      if (dwordpos == 4) then
         filecontent[index] = dwordsum
         index = index + 1
         if (transmit_dwords ~= nil) then
            if (index == transmit_dwords) then
               break
            end
         end
         dwordpos = 0
         dwordsum = 0
      end
   end
   input:close()
   
   print("Transmitting ROM: "..filename)

   --print(string.format("%08X", filecontent[0]))
   
   reg_set_file(filename, baseaddress, 0, 0)

end

