vcom -93 -quiet -work  sim/mem ^
../../rtl/SyncFifo.vhd ^
../../rtl/SyncRam.vhd

vcom -2008 -quiet -work sim/psx ^
../../rtl/gpu_fillVram.vhd ^
../../rtl/gpu_cpu2vram.vhd ^
../../rtl/gpu.vhd

vcom -quiet -work sim/tb ^
../system/src/tb/globals.vhd ^
../system/src/tb/ddrram_model.vhd ^
src/tb/tb.vhd

