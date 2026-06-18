`include "../src/types.svh"

// Not the best testbench ever
// but it's so heavily intertwined
// with the other modules that
// it's hard to implement anything
// good.

module retire_tb;
    reg reset = 0;
    rob_ent_t [1:0] rob_entries;
    reg [1:0] rob_ent_val;
    post_ex_uop_t [2:0] ex_uops;

    reg [63:0] f_list_freed;
    reg [3:0] head;
    reg [31:0] [5:0] a_reg_state;
    reg [31:0] new_pc;
    reg flush;
    reg halt;
    reg [3:0] retire_rob_id;

    rob_ent_t tmp_rob_ent;
    reg clk = 0;
    always #10 clk = ~clk;
    
    retire dut (.clk(clk), .reset(reset), .rob_entries(rob_entries),
        .rob_ent_val(rob_ent_val), .ex_uops(ex_uops), .head(head),
        .a_reg_state(a_reg_state), .new_pc(new_pc), .flush(flush), 
        .halt(halt), .f_list_freed(f_list_freed),
        .retire_rob_valid(retire_rob_valid), .retire_rob_id(retire_rob_id));

    task reset_stage();
        reset = 0;
        @(posedge clk);
        reset = 1;
    endtask;

    // tests if we correctly halt if a faulted instruction is retiring
    task test_halt();
        reset_stage();
        assert (!halt)
            else $fatal(1, "Halted for no reason\n");
        rob_ent_val[0] = 1'b1;
        rob_ent_val[1] = 1'b0;
        tmp_rob_ent = '0;
        tmp_rob_ent.faulted = 1'b1;
        rob_entries[0] = tmp_rob_ent;
        ex_uops = '0;
        @(posedge clk);
        @(negedge clk);
        rob_ent_val[0] = 1'b0;
        ex_uops[0].valid = 1'b1;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        assert (halt)
            else $fatal(1, "Did not halt when needed\n");
        reset_stage();
        assert (!halt)
            else $fatal(1, "Halted for no reason\n");
        rob_ent_val[0] = 1'b1;
        rob_ent_val[1] = 1'b0;
        tmp_rob_ent = '0;
        rob_entries[0] = tmp_rob_ent;
        ex_uops = '0;
        @(posedge clk);
        @(negedge clk);
        rob_ent_val[0] = 1'b0;
        ex_uops[0].faulted = 1'b1;
        ex_uops[0].valid = 1'b1;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        assert (halt)
            else $fatal(1, "Did not halt when needed\n");
    endtask

    task test_store();
        reset_stage();
        rob_ent_val[0] = 1'b1;
        rob_ent_val[1] = 1'b0;
        tmp_rob_ent = '0;
        tmp_rob_ent.store = 1'b1;
        rob_entries[0] = tmp_rob_ent;
        ex_uops = '0;
        @(posedge clk);
        @(negedge clk);
        rob_ent_val[0] = 1'b0;
        ex_uops[0].valid = 1'b1;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        assert (retire_rob_valid && (retire_rob_id == 0))
            else $fatal(1, "Did not halt when needed\n");
    endtask

    initial begin
        test_halt();
        test_store();
        $finish;
    end
endmodule