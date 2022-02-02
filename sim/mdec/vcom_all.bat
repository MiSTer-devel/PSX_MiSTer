vcom -93 -quiet -work  sim/mem ^
../../rtl/SyncFifo.vhd ^
../../rtl/SyncFifoFallThrough.vhd ^
../../rtl/SyncRam.vhd

vcom -2008 -quiet -work sim/psx ^
../../rtl/dpram.vhd ^
../../rtl/mdec.vhd

vcom -quiet -work sim/tb ^
../system/src/tb/tb_savestates.vhd ^
src/tb/tb.vhd

