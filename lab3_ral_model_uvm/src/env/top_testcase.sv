// *****************************************
// u_vsqr definition
// *****************************************
class u_vsqr extends uvm_sequencer;
    `uvm_component_utils(u_vsqr)
    u_sequencer      p_u_sqr;
    u_bus_sequencer  p_bus_sqr;
    u_reg_model      p_rm;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// *****************************************
// base_test definition
// *****************************************
class base_test extends uvm_test;
	`uvm_component_utils(base_test)

	u_env 		env;
	u_vsqr 		v_sqr;
	u_reg_model rm;
	u_adapter 	reg_sqr_adapter;

	function new (string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env 	= u_env::type_id::create("env", this);
		v_sqr	= u_vsqr::type_id::create("v_sqr", this);
		rm      = u_reg_model::type_id::create("rm", this);
		rm.configure(null, "");
		rm.build();
		rm.lock_model();
		rm.reset();
		reg_sqr_adapter= new ("reg_sqr_adapter");
		env.p_rm= this.rm;
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		v_sqr.p_u_sqr  = env.i_agt.sqr;
		v_sqr.p_bus_sqr= env.bus_agt.sqr;
		v_sqr.p_rm     = this.rm;
		rm.default_map.set_sequencer(env.bus_agt.sqr, reg_sqr_adapter);
		rm.default_map.set_auto_predict(1);
	endfunction

	function void report_phase(uvm_phase phase);
		uvm_report_server server;
   		int err_num;
   
   		super.report_phase(phase);
   		server = get_report_server();
   		err_num = server.get_severity_count(UVM_ERROR);

   		if (err_num != 0) begin
      		$display("TEST CASE FAILED");
   		end else begin
      		$display("TEST CASE PASSED");
   		end
	endfunction
endclass

class case0_sequence extends uvm_sequence #(u_transaction);
   u_transaction m_trans;

   function  new(string name= "case0_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
      repeat (10) begin
         `uvm_do(m_trans)
      end
   endtask

   `uvm_object_utils(case0_sequence)
endclass

class case0_cfg_vseq extends uvm_sequence;
   `uvm_object_utils(case0_cfg_vseq)
   `uvm_declare_p_sequencer(u_vsqr)
   
   function new(string name= "case0_cfg_vseq");
      super.new(name);
   endfunction 
   
   virtual task body();
      uvm_status_e   status;
      uvm_reg_data_t value;
      if(starting_phase != null) 
         starting_phase.raise_objection(this);
      p_sequencer.p_rm.invert.read(status, value, UVM_FRONTDOOR);
      `uvm_info("case0_cfg_vseq", $sformatf("invert's initial value is %0h", value), UVM_LOW)
      p_sequencer.p_rm.invert.write(status, 1, UVM_FRONTDOOR);
      p_sequencer.p_rm.invert.read(status, value, UVM_FRONTDOOR);
      `uvm_info("case0_cfg_vseq", $sformatf("after set, invert's value is %0h", value), UVM_LOW)
      if(starting_phase != null) 
         starting_phase.drop_objection(this);
   endtask
endclass

class case0_vseq extends uvm_sequence;
   	`uvm_object_utils(case0_vseq)
   	`uvm_declare_p_sequencer(u_vsqr)
   
   	function  new(string name= "case0_vseq");
      	super.new(name);
   	endfunction 
   
   	virtual task body();
      	case0_sequence dseq;
      	uvm_status_e   status;
      	uvm_reg_data_t value;
      	if (starting_phase != null) 
         	starting_phase.raise_objection(this);
      	#10000;
      	dseq = case0_sequence::type_id::create("dseq");
      	dseq.start(p_sequencer.p_u_sqr);
      
      	if (starting_phase != null) 
         	starting_phase.drop_objection(this);
   	endtask
endclass

// *****************************************
// u_case0 definition
// *****************************************
class u_case0 extends base_test;
    `uvm_component_utils(u_case0)
    function new(string name = "u_case0", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_object_wrapper)::set(this, 
                                           "v_sqr.configure_phase", 
                                           "default_sequence", 
                                           case0_cfg_vseq::type_id::get());
        uvm_config_db#(uvm_object_wrapper)::set(this, 
                                           "v_sqr.main_phase", 
                                           "default_sequence", 
                                           case0_vseq::type_id::get());
    endfunction
endclass
