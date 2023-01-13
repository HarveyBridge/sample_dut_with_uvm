// *****************************************
// agent component definition
// *****************************************
interface u_if(input bit clk, input bit rst_n);
    logic [7:0] data;
    logic valid;
endinterface

class u_transaction extends uvm_sequence_item;
    rand bit[47:0] dmac;
    rand bit[47:0] smac;
    rand bit[15:0] ether_type;
    rand byte      pload[];
    rand bit[31:0] crc;

    constraint pload_cons{
        pload.size >= 46;
        pload.size <= 1500;
    }

    function bit[31:0] calc_crc();
        return 32'h0;
    endfunction

    function void post_randomize();
        crc = calc_crc;
    endfunction

    `uvm_object_utils_begin(u_transaction)
        `uvm_field_int(dmac, UVM_ALL_ON)
        `uvm_field_int(smac, UVM_ALL_ON)
        `uvm_field_int(ether_type, UVM_ALL_ON)
        `uvm_field_array_int(pload, UVM_ALL_ON)
        `uvm_field_int(crc, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name= "u_transaction");
        super.new();
    endfunction
endclass

class u_sequencer extends uvm_sequencer #(u_transaction);
    `uvm_component_utils(u_sequencer)
    function new (string name= "u_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

class u_monitor extends uvm_monitor;
    `uvm_component_utils(u_monitor)

    virtual u_if vif;
    uvm_analysis_port #(u_transaction) ap;

    function new(string name= "u_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual u_if)::get(this, "", "vif", vif))
            `uvm_fatal("u_monitor", "virtual interface must be set for vif!!!")
        ap= new("ap", this);
    endfunction

    task main_phase(uvm_phase phase);
        u_transaction tr;

        while (1) begin
            tr= new("tr");
            collect_one_pkt(tr);
            ap.write(tr);
        end
    endtask

    task collect_one_pkt(u_transaction tr);
        byte unsigned data_q[$];
        byte unsigned data_array[];
        logic [7:0] data;
        logic valid = 0;
        int data_size;
       
        while (1) begin
            @(posedge vif.clk);
            if (vif.valid) break;
        end
       
        //`uvm_info("my_monitor", "begin to collect one pkt", UVM_LOW);
        while (vif.valid) begin
            data_q.push_back(vif.data);
            @(posedge vif.clk);
        end
        data_size  = data_q.size();   
        data_array = new[data_size];
        for (int i= 0; i < data_size; i++) begin
            data_array[i] = data_q[i]; 
        end
        tr.pload = new[data_size - 18]; //da sa, e_type, crc
        data_size = tr.unpack_bytes(data_array) / 8; 
        //`uvm_info("my_monitor", "end collect one pkt", UVM_LOW);
    endtask
endclass

class u_driver extends uvm_driver #(u_transaction);
    `uvm_component_utils(u_driver)
    virtual u_if vif;

    function new (string name= "u_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual u_if)::get(this, "", "vif", vif))
            `uvm_fatal("my_driver", "virtual interface must be set for vif!!!")
    endfunction

    task main_phase(uvm_phase phase);
        vif.valid <= 1'b0;
        vif.data  <= 8'b0;
        while (!vif.rst_n)
            @(posedge vif.clk);

        while (1) begin
            seq_item_port.get_next_item(req);
            driver_one_pkt(req);
            seq_item_port.item_done();
        end
    endtask

    task driver_one_pkt(u_transaction tr);
        byte unsigned data_q[];
        int           data_size;

        data_size= tr.pack_bytes(data_q)/8;
        repeat (3) @(posedge vif.clk);
        for (int i= 0; i < data_size; i++) begin
            @(posedge vif.clk);
            vif.valid <= 1'b1;
            vif.data  <= data_q[i];
        end
        @(posedge vif.clk);
        vif.valid <= 1'b0;
    endtask
endclass
