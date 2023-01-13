// *****************************************
// agent definition
// *****************************************
class u_agent extends uvm_agent;
    `uvm_component_utils(u_agent)
    u_sequencer sqr;
    u_driver    drv;
    u_monitor   mon;

    uvm_analysis_port #(u_transaction) ap;
    function new(string name= "u_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (is_active == UVM_ACTIVE) begin
            sqr= u_sequencer::type_id::create("seq", this);
            drv= u_driver::type_id::create("drv", this);
        end
        mon= u_monitor::type_id::create("mon", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
        ap= mon.ap;
    endfunction
endclass

// *****************************************
// bus_agent definition
// *****************************************
class u_bus_agent extends uvm_agent;
    `uvm_component_utils(u_bus_agent)
    u_bus_sequencer sqr;
    u_bus_driver    drv;
    u_bus_monitor   mon;

    uvm_analysis_port #(u_bus_transaction) ap;
    function new(string name= "u_bus_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (is_active == UVM_ACTIVE) begin
            sqr= u_bus_sequencer::type_id::create("sqr", this);
            drv= u_bus_driver::type_id::create("drv", this);
        end
        mon= u_bus_monitor::type_id::create("mon", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
        ap= mon.ap;
    endfunction
endclass

// *****************************************
// u_model definition
// *****************************************
class u_model extends uvm_component;
    `uvm_component_utils(u_model)

    uvm_blocking_get_port #(u_transaction) port;
    uvm_analysis_port     #(u_transaction) ap;

    u_reg_model p_rm;

    function new(string name= "u_model", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        port= new("port", this);
        ap  = new("ap",   this);
    endfunction

    function void invert_tr(u_transaction tr);
        tr.dmac = tr.dmac ^ 48'hFFFF_FFFF_FFFF;
        tr.smac = tr.smac ^ 48'hFFFF_FFFF_FFFF;
        tr.ether_type = tr.ether_type ^ 16'hFFFF;
        tr.crc = tr.crc ^ 32'hFFFF_FFFF;
        for(int i= 0; i < tr.pload.size; i++)
            tr.pload[i] = tr.pload[i] ^ 8'hFF;
    endfunction

    task main_phase(uvm_phase phase);
        u_transaction tr;
        u_transaction new_tr;
        uvm_status_e status;
        uvm_reg_data_t value;

        super.main_phase(phase);
        p_rm.invert.read(status, value, UVM_FRONTDOOR);
        while(1) begin
            port.get(tr);
            new_tr= new("new_tr");
            new_tr.copy(tr);
            //`uvm_info("u_model", "get one transaction, copy and print it:", UVM_LOW)
            //new_tr.print();
            if (value)
                invert_tr(new_tr);
            ap.write(new_tr);
        end
    endtask
endclass

// *****************************************
// u_scoreboard definition
// *****************************************
class u_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(u_scoreboard)

    u_transaction expect_queue[$];
    uvm_blocking_get_port #(u_transaction) exp_port;
    uvm_blocking_get_port #(u_transaction) act_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_port= new("exp_port", this);
        act_port= new("act_port", this);
    endfunction

    task main_phase(uvm_phase phase);
        u_transaction  get_expect,  get_actual, tmp_tran;
        bit result;
 
        super.main_phase(phase);
        fork 
            while (1) begin
                exp_port.get(get_expect);
                expect_queue.push_back(get_expect);
            end

            while (1) begin
                act_port.get(get_actual);
                if (expect_queue.size() > 0) begin
                    tmp_tran = expect_queue.pop_front();
                    result = get_actual.compare(tmp_tran);
                    if (result) begin 
                        `uvm_info("u_scoreboard", "Compare SUCCESSFULLY", UVM_LOW);
                    end else begin
                        `uvm_error("u_scoreboard", "Compare FAILED");
                        $display("the expect pkt is");
                        tmp_tran.print();
                        $display("the actual pkt is");
                        get_actual.print();
                    end
                end else begin
                    `uvm_error("u_scoreboard", "Received from DUT, while Expect Queue is empty");
                    $display("the unexpected pkt is");
                    get_actual.print();
                end 
            end
        join
    endtask
endclass

// *****************************************
// u_vsqr definition
// *****************************************
class u_adapter extends uvm_reg_adapter;
    string tID = get_type_name();

    `uvm_object_utils(u_adapter)

   function new(string name="u_adapter");
      super.new(name);
   endfunction : new

   function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
      u_bus_transaction tr;
      tr = new("tr"); 
      tr.addr = rw.addr;
      tr.bus_op = (rw.kind == UVM_READ) ? BUS_RD: BUS_WR;
      if (tr.bus_op == BUS_WR)
         tr.wr_data = rw.data; 
      return tr;
   endfunction : reg2bus

   function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
      u_bus_transaction tr;
      if(!$cast(tr, bus_item)) begin
         `uvm_fatal(tID,
          "Provided bus_item is not of the correct type. Expecting bus_transaction")
          return;
      end
      rw.kind = (tr.bus_op == BUS_RD) ? UVM_READ : UVM_WRITE;
      rw.addr = tr.addr;
      rw.byte_en = 'h3;
      rw.data = (tr.bus_op == BUS_RD) ? tr.rd_data : tr.wr_data;
      rw.status = UVM_IS_OK;
   endfunction : bus2reg
endclass

// *****************************************
// env definition
// *****************************************
class u_env extends uvm_env;
    `uvm_component_utils(u_env)
    u_agent         i_agt;
    u_agent         o_agt;
    u_bus_agent     bus_agt;
    u_model         mdl;
    u_scoreboard    scb;
    u_reg_model     p_rm;

    uvm_tlm_analysis_fifo #(u_transaction) agt_scb_fifo;
    uvm_tlm_analysis_fifo #(u_transaction) agt_mdl_fifo;
    uvm_tlm_analysis_fifo #(u_transaction) mdl_scb_fifo;

    function new(string name= "u_env", uvm_component parent);
            super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i_agt  = u_agent::type_id::create("i_agt", this);
        o_agt  = u_agent::type_id::create("o_agt", this);
        bus_agt= u_bus_agent::type_id::create("bus_agt", this);
        mdl    = u_model::type_id::create("mdl", this);
        scb    = u_scoreboard::type_id::create("scb", this);

        i_agt.is_active= UVM_ACTIVE;
        o_agt.is_active= UVM_PASSIVE;
        bus_agt.is_active= UVM_ACTIVE;

        agt_scb_fifo= new("agt_scb_fifo", this);
        agt_mdl_fifo= new("agt_mdl_fifo", this);
        mdl_scb_fifo= new("mdl_scb_fifo", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // not implement
        //i_agt.ap.connect();
        //o_agt.ap.connect();
        i_agt.ap.connect(agt_mdl_fifo.analysis_export);
        mdl.port.connect(agt_mdl_fifo.blocking_get_export);
        mdl.ap.connect(mdl_scb_fifo.analysis_export);
        scb.exp_port.connect(mdl_scb_fifo.blocking_get_export);
        o_agt.ap.connect(agt_scb_fifo.analysis_export);
        scb.act_port.connect(agt_scb_fifo.blocking_get_export); 
        mdl.p_rm = this.p_rm;
    endfunction
endclass