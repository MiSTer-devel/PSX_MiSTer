
vcom -93 -quiet -work  sim/tb ^
../system/src/tb/globals.vhd

vcom -93 -quiet -work  sim/mem ^
../../rtl/ramMLAB.vhd ^
../../rtl/SyncFifo.vhd ^
../../rtl/SyncFifoFallThrough.vhd ^
../../rtl/SyncRam.vhd

vcom -2008 -quiet -work sim/psx ^
../../rtl/spu_ram.vhd ^
../../rtl/spu.vhd

vcom -93 -quiet -work sim/mem ^
../system/src/mem/dpram.vhd ^
../system/src/mem/RamMLAB.vhd

vcom -quiet -work sim/tb ^
../system/src/tb/sdram_model.vhd ^
../system/src/tb/ddrram_model.vhd ^
../system/src/tb/tb_savestates.vhd ^
../system/src/tb/sdram_model3x.vhd ^
src/tb/tb.vhd

