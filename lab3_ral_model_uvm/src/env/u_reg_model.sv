// *****************************************
// u_reg_model definition
// *****************************************
class u_reg_invert extends uvm_reg;
    `uvm_object_utils(u_reg_invert)

    rand uvm_reg_field reg_data;
    function new(string name= "u_reg_invert");
        super.new(name, 16, UVM_NO_COVERAGE);
    endfunction

    function void build();
        reg_data= uvm_reg_field::type_id::create("reg_data");
        reg_data.configure(this, 1, 0, "RW", 1, 0, 1, 1, 0);
    endfunction
endclass

class u_reg_model extends uvm_reg_block;
    `uvm_object_utils(u_reg_model)

    rand u_reg_invert invert;
    function new(string name= "u_reg_model");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    function void build();
        default_map= create_map("default_map", 0, 2, UVM_BIG_ENDIAN, 0);

        invert= u_reg_invert::type_id::create("invert",, get_full_name());
        invert.configure(this, null, "");
        invert.build();
        default_map.add_reg(invert, 'h9, "RW");
    endfunction
endclass

