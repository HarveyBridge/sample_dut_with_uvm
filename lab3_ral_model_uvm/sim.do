vlib work 
set UVM_HOME    C:/ModelSim/modeltech64_10.1c/verilog_src/uvm-1.1
set UVM_DPI_DIR C:/ModelSim/modeltech64_10.1c/verilog_src/uvm-1.1/lib
set SRC         C:/github_official/sample_dut_with_uvm/lab3_ral_model_uvm/src
vlog +incdir+$UVM_HOME/src +incdir+$SRC/env -L mtiAvm -L mtiOvm -L mtiUvm -L mtiUPF $UVM_HOME/src/uvm_pkg.sv $SRC/dut.sv $SRC/top_tb.sv
vsim -c +UVM_TESTNAME=u_case0 -sv_lib $UVM_DPI_DIR/uvm_dpi work.top_tb work.dut
view wave *
run -all
