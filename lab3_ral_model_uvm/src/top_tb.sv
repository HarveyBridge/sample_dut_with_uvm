`timescale 1ns/1ps
`include "uvm_macros.svh"

import uvm_pkg::*;

`include "u_reg_model.sv"
`include "u_agent_component.sv"
`include "bus_agent_component.sv"
`include "top_uvm_env.sv"
`include "top_testcase.sv"

module top_tb;

reg clk;
reg rst_n;
reg[7:0] rxd;
reg rx_dv;
wire[7:0] txd;
wire tx_en;


u_if      input_if(clk, rst_n);
u_if      output_if(clk, rst_n);
u_bus_if  b_if(clk, rst_n);

dut my_dut(.clk          (clk               ),
           .rst_n        (rst_n             ),
           .bus_cmd_valid(b_if.bus_cmd_valid), 
           .bus_op       (b_if.bus_op       ), 
           .bus_addr     (b_if.bus_addr     ), 
           .bus_wr_data  (b_if.bus_wr_data  ), 
           .bus_rd_data  (b_if.bus_rd_data  ), 
           .rxd          (input_if.data     ),
           .rx_dv        (input_if.valid    ),
           .txd          (output_if.data    ),
           .tx_en        (output_if.valid   ));

initial begin
   clk = 0;
   forever begin
      #100 clk = ~clk;
   end
end

initial begin
   rst_n = 1'b0;
   #1000;
   rst_n = 1'b1;
end

initial begin
   run_test();
end

initial begin
    uvm_config_db#(virtual u_if)::set(null, "uvm_test_top.env.i_agt.drv", "vif", input_if);
    uvm_config_db#(virtual u_if)::set(null, "uvm_test_top.env.i_agt.mon", "vif", input_if);
    uvm_config_db#(virtual u_if)::set(null, "uvm_test_top.env.o_agt.mon", "vif", output_if);
    uvm_config_db#(virtual u_bus_if)::set(null, "uvm_test_top.env.bus_agt.drv", "vif", b_if);
    uvm_config_db#(virtual u_bus_if)::set(null, "uvm_test_top.env.bus_agt.mon", "vif", b_if);
end

initial begin
   $dumpfile("top_tb.vcd");
   $dumpvars(0, top_tb);
end

endmodule
