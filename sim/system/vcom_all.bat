
vcom -93 -quiet -work  sim/tb ^
src/tb/globals.vhd

vcom -93 -quiet -work  sim/mem ^
../../rtl/SyncFifo.vhd ^
../../rtl/SyncRam.vhd

vcom -quiet -work  sim/rs232 ^
src/rs232/rs232_receiver.vhd ^
src/rs232/rs232_transmitter.vhd ^
src/rs232/tbrs232_receiver.vhd ^
src/rs232/tbrs232_transmitter.vhd

vcom -quiet -work sim/procbus ^
src/procbus/proc_bus.vhd ^
src/procbus/testprocessor.vhd

vcom -quiet -work sim/reg_map ^
src/reg_map/reg_tb.vhd

vcom -2008 -quiet -work sim/psx ^
../../rtl/proc_bus.vhd ^
../../rtl/dpram.vhd ^
../../rtl/export.vhd ^
../../rtl/divider.vhd ^
../../rtl/pGPU.vhd ^
../../rtl/gpu_fillVram.vhd ^
../../rtl/gpu_cpu2vram.vhd ^
../../rtl/gpu_vram2vram.vhd ^
../../rtl/gpu_line.vhd ^
../../rtl/gpu_rect.vhd ^
../../rtl/gpu_poly.vhd ^
../../rtl/gpu_pixelpipeline.vhd ^
../../rtl/gpu.vhd ^
../../rtl/irq.vhd ^
../../rtl/joypad.vhd ^
../../rtl/cpu.vhd ^
../../rtl/memorymux.vhd ^
../../rtl/psx_top.vhd ^
../../rtl/psx_mister.vhd 

vlog -sv -quiet -work sim/psx ^
../../rtl/ddram.sv

vcom -quiet -work sim/tb ^
src/tb/stringprocessor.vhd ^
src/tb/tb_interpreter.vhd ^
src/tb/ddrram_model.vhd ^
src/tb/sdram_model.vhd ^
src/tb/framebuffer.vhd ^
src/tb/tb.vhd

