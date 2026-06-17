`include "../src/types.svh"

module retire_tb;
    reg reset = 0;
    rob_ent_t [1:0] rob_entries;
    reg rob_ent_val [1:0];
    post_ex_uop_t [2:0] ex_uops;

    reg [63:0] f_list_freed;
    reg [3:0] head;
    reg [31:0] [5:0] a_reg_state;
    reg [31:0] new_pc;
    reg flush;
    reg halt;
    reg [3:0] retire_rob_id;

    reg clk = 0;
    always #10 clk = ~clk;
    
    retire dut (.clk(clk), .reset(reset), .rob_entries(rob_entries),
        .rob_ent_val(rob_ent_val), .ex_uops(ex_uops), .head(head),
        .a_reg_state(a_reg_state), .new_pc(new_pc), .flush(flush), 
        .halt(halt), .f_list_freed(f_list_freed),
        .retire_rob_valid(retire_rob_valid));

    task reset_stage();
    endtask;
endmodule