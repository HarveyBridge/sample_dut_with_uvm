// *****************************************
// agent component definition
// *****************************************
interface u_bus_if(input bit clk, input bit rst_n);
    logic         bus_cmd_valid;
    logic         bus_op;
    logic [15:0]  bus_addr;
    logic [15:0]  bus_wr_data;
    logic [15:0]  bus_rd_data;
endinterface

typedef enum{BUS_RD, BUS_WR} u_bus_op_e;
class u_bus_transaction extends uvm_sequence_item;
    rand bit[15:0] rd_data;
    rand bit[15:0] wr_data;
    rand bit[15:0] addr;

    rand u_bus_op_e  bus_op;

    `uvm_object_utils_begin(u_bus_transaction)
        `uvm_field_int(rd_data, UVM_ALL_ON)
        `uvm_field_int(wr_data, UVM_ALL_ON)
        `uvm_field_int(addr   , UVM_ALL_ON)
        `uvm_field_enum(u_bus_op_e, bus_op, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "u_bus_transaction");
        super.new();
    endfunction
endclass

class u_bus_sequencer extends uvm_sequencer #(u_bus_transaction);
    `uvm_component_utils(u_bus_sequencer)
    function new (string name= "u_bus_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

class u_bus_monitor extends uvm_monitor;
    `uvm_component_utils(u_bus_monitor)

    virtual u_bus_if vif;
    uvm_analysis_port #(u_bus_transaction) ap;

    function new(string name= "u_bus_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual u_bus_if)::get(this, "", "vif", vif))
            `uvm_fatal("u_bus_monitor", "virtual interface must be set for vif!!!")
        ap= new("ap", this);
    endfunction

    task main_phase(uvm_phase phase);
        u_bus_transaction tr;

        while (1) begin
            tr= new("tr");
            collect_one_pkt(tr);
            ap.write(tr);
        end
    endtask

    task collect_one_pkt(u_bus_transaction tr);
        while (1) begin
            @(posedge vif.clk);
            if (vif.bus_cmd_valid) break;
        end
        tr.bus_op= ((vif.bus_op == 0) ? BUS_RD : BUS_WR);
        tr.addr= vif.bus_addr;
        tr.wr_data= vif.bus_wr_data;
        @(posedge vif.clk);
        tr.rd_data= vif.bus_rd_data;

        `uvm_info("u_bus_monitor", "begin to collect one pkt", UVM_LOW);
    endtask
endclass

class u_bus_driver extends uvm_driver #(u_bus_transaction);
    `uvm_component_utils(u_bus_driver)
    virtual u_bus_if vif;

    function new (string name= "u_bus_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual u_bus_if)::get(this, "", "vif", vif))
            `uvm_fatal("u_bus_driver", "virtual interface must be set for vif!!!")
    endfunction

    task run_phase(uvm_phase phase); // ???
        vif.bus_cmd_valid   <= 1'b0;
        vif.bus_op          <= 1'b0;
        vif.bus_addr        <= 15'b0;
        vif.bus_wr_data     <= 15'b0;
        while (!vif.rst_n)
            @(posedge vif.clk);

        while (1) begin
            seq_item_port.get_next_item(req);
            driver_one_pkt(req);
            seq_item_port.item_done();
        end
    endtask

    task driver_one_pkt(u_bus_transaction tr);
        `uvm_info("bus_driver", "begin to drive one pkt", UVM_LOW);
        repeat(1) @(posedge vif.clk);
   
        vif.bus_cmd_valid   <= 1'b1;
        vif.bus_op          <= ((tr.bus_op == BUS_RD) ? 0 : 1);
        vif.bus_addr        = tr.addr;
        vif.bus_wr_data     <= ((tr.bus_op == BUS_RD) ? 0 : tr.wr_data);

        @(posedge vif.clk);
        vif.bus_cmd_valid   <= 1'b0;
        vif.bus_op          <= 1'b0;
        vif.bus_addr        <= 15'b0;
        vif.bus_wr_data       <= 15'b0;

        @(posedge vif.clk);
        if (tr.bus_op == BUS_RD) begin
            tr.rd_data = vif.bus_rd_data;   
            //$display("@%0t, rd_data is %0h", $time, tr.rd_data);
        end
    endtask
endclass

