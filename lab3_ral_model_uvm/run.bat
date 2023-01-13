set UVM_HOME=C:/ModelSim/modeltech64_10.1c/verilog_src/uvm-1.1
set UVM_DPI_DIR=%UVM_HOME%/lib/uvm_dpi
set SRC=C:/verification/program/lab3_ral_model/myself/src
set RUN_ALL=-do "run -all; quit"

if "%~1" == "" (
    set test_case=base_test
) else (
    set test_case=%1
)
echo "Test Case Name: "%test_case%

vlib work 
vlog -f filelist.f -L mtiAvm -L mtiOvm -L mtiUvm -L mtiUPF
pause
vsim -c +UVM_TESTNAME=%test_case% -sv_lib %UVM_DPI_DIR% work.top_tb  %RUN_ALL%
vsim -c +UVM_TESTNAME=%test_case% -sv_lib %UVM_DPI_DIR% work.top_tb  %RUN_ALL% > vsim.log