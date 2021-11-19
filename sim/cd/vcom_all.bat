
vcom -93 -quiet -work  sim/tb ^
../system/src/tb/globals.vhd

vcom -93 -quiet -work  sim/mem ^
../../rtl/SyncFifo.vhd ^
../../rtl/SyncFifoFallThrough.vhd ^
../../rtl/SyncRam.vhd

vcom -2008 -quiet -work sim/psx ^
../../rtl/dpram.vhd ^
../../rtl/cd_top.vhd

vcom -quiet -work sim/tb ^
../system/src/tb/sdram_model.vhd ^
src/tb/tb.vhd

