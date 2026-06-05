.PHONY: sim clean

RTL = rtl/gpu_pkg.sv \
      rtl/compute_core.sv \
      rtl/control_unit.sv \
      rtl/gpu_top.sv

sim: sim/gpu_tb.sv $(RTL)
	 iverilog -g2012 -o gpu.vvp $(RTL) sim/gpu_tb.sv
	 vvp gpu.vvp

clean:
	rm -f gpu.vvp gpu_tb.vcd
