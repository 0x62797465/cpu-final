`include "../src/types.svh"

module rename_tb;
    int fd;
    int fd_expected;
    int ignore_sys_res;
    string line;
    string line_expected;

    reg [31:0] [5:0] a_reg_state = '0;
    reg clk;
    reg reset;
    reg [3:0] head;
    uop_t [1:0] uops;
    reg [63:0] f_list_freed; 
    reg [1:0] rob_ent_val;

    reg [63:0] f_list_allocated;
    uop_t [1:0] renamed;
    rob_ent_t [1:0] rob_entries;
    reg [3:0] tail;
    reg stall_backwards;

    reg [63:0] f_list = {{63{1'b1}}, 1'b0}; // what regs are free
    reg [31:0] [5:0] rename_table; // what register maps to what physical register

    reg [414:0] expected_out;
    int a, b;

    always #10 clk = ~clk;

    rename dut (.clk(clk), .CPU_RESET_n(reset), .stall(1'b0), .head(head), .uops(uops),
        .f_list_freed(f_list_freed), .f_list_allocated(f_list_allocated),
        .renamed(renamed), .rob_entries(rob_entries), .tail(tail),
        .stall_backwards(stall_backwards), .rob_ent_val(rob_ent_val), 
        .a_reg_state(a_reg_state), .flush(1'b0));

    task reset_stage();
        f_list = {{63{1'b1}}, 1'b0}; 
        reset = 0;
        @(posedge clk);
        reset = 1;
    endtask

    task check_flist(); // prevents double allocation
        assert (!(|(~f_list & f_list_allocated))) // Allocated registers don't try to allocate already allocated registers
            else begin 
                $fatal(1, "Rename tried to allocate already allocated physical register");
            end
        f_list ^= f_list_allocated; // update state
    endtask


    task check_rat(); // prevents dual pointers
        for (a = 0; a < 32; a = a + 1) begin // *never synthesized* so optimization shouldn't be a big concern
            for (b = 0; b < 32; b = b + 1) begin
                assert (!((dut.rename_table[a] == dut.rename_table[b]) && (a != b) && (dut.rename_table[b] != 0)))
                    else begin
                        $fatal(1, "Both %h and %h point to %h in the RAT", a, b, dut.rename_table[b]);
                    end
            end
        end
    endtask

    task test_basic();
        fd = $fopen("testcases/rename/basic.txt", "r");
        fd_expected = $fopen("testcases/rename/basic_expected.txt", "r");
        while ($fgets(line, fd)) begin
            ignore_sys_res = $fgets(line_expected, fd_expected);
            ignore_sys_res = $sscanf(line, "%h %h", uops[0], uops[1]);
            ignore_sys_res = $sscanf(line_expected, "%h", expected_out);
            @(posedge clk);
            #1;
            check_flist();
            check_rat();
            //$write("%h\n",  {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards});
            assert (expected_out == {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards})
                else begin
                    $fatal(1, "State does not match for basic!\n");
                end
        end
    endtask

    task test_stall();
        fd = $fopen("testcases/rename/stall.txt", "r");
        fd_expected = $fopen("testcases/rename/stall_expected.txt", "r");
        while ($fgets(line, fd)) begin
            ignore_sys_res = $fgets(line_expected, fd_expected);
            ignore_sys_res = $sscanf(line, "%b %b", uops[0], uops[1]);
            ignore_sys_res = $sscanf(line_expected, "%b", expected_out);
            @(posedge clk);
            #1;
            check_flist();
            check_rat();
            //$write("%b\n",  {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards});
            assert (expected_out == {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards})
                else begin
                    $fatal(1, "State does not match for stall!\n");
                end
            if (stall_backwards) begin
                f_list_freed = 6'b111110;
                f_list ^= f_list_freed;
                @(posedge clk);
                #1;
                f_list_freed = 1'b0;
                ignore_sys_res = $fgets(line_expected, fd_expected);
                ignore_sys_res = $sscanf(line_expected, "%b", expected_out);
                //$write("%b\n",  {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards});
                assert (expected_out == {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards})
                    else begin
                        $fatal(1, "State does not match for stall (stall edge case)!\n");
                    end
            end
        end
    endtask

    initial begin
        reset_stage();
        test_basic();
        reset_stage();
        test_stall();
        $finish;
    end 
endmodule

