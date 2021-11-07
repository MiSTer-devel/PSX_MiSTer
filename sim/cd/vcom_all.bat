vcom -93 -quiet -work  sim/mem ^
../../rtl/SyncFifo.vhd ^
../../rtl/SyncFifoFallThrough.vhd ^
../../rtl/SyncRam.vhd

vcom -2008 -quiet -work sim/psx ^
../../rtl/dpram.vhd ^
../../rtl/testiso.vhd ^
../../rtl/cd_top.vhd

vcom -quiet -work sim/tb ^
src/tb/tb.vhd

