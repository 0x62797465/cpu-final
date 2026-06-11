`include "../src/types.svh"

module rename_tb;
    int fd;
    int fd_expected;
    string line;
    string line_expected;

    reg clk = '0;
    reg reset = '0;
    reg [3:0] head = '0;
    uop_t [1:0] uops = '0;
    reg [63:0] f_list_freed = '0; 
    
    reg [63:0] f_list_allocated = '0;
    uop_t [1:0] renamed = '0;
    rob_ent_t [1:0] rob_entries = '0;
    reg [3:0] tail = '0;
    reg stall_backwards = '0;

    reg [63:0] f_list = {{63{1'b1}}, 1'b0}; // what regs are free
    reg [31:0] [5:0] rename_table = '0; // what register maps to what physical register

    reg [414:0] expected_out = '0;
    int a, b;

    always #10 clk = ~clk;

    rename dut (.clk(clk), .CPU_RESET_n(reset), .stall(1'b0), .head(head), .uops(uops),
        .f_list_freed(f_list_freed), .f_list_allocated(f_list_allocated),
        .renamed(renamed), .rob_entries(rob_entries), .tail(tail),
        .stall_backwards(stall_backwards));

    task dump_state();
        $write("clk: %b\ncpu reset (negated): %b\nhead: %h\nuops: %b\n%b\nf_list_freed: %b\n",
            clk, reset, head, uops[0], uops[1], f_list_freed);
        $write("f_list: %b\nf_list_allocated: %b\nrenamed (uops): %b\n%b\nrob_entries: %b\n%b\ntail: %h\nstall_backwards: %b\n",
            f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1],
            tail, stall_backwards);
        $write("RAT: ");
        for (a = 0; a < 32; a = a + 1) begin
            $write("%h: %h ", a, dut.rename_table[a]);
        end
        $write("\n");
    endtask

    task reset_stage();
        f_list = {{63{1'b1}}, 1'b0}; 
        reset = 0;
        @(posedge clk);
        reset = 1;
    endtask

    task check_flist(); // prevents double allocation
        assert (!(|(~f_list & f_list_allocated))) // Allocated registers don't try to allocate already allocated registers
            else begin 
                dump_state();
                $fatal("Rename tried to allocate already allocated physical register");
            end
        f_list ^= f_list_allocated; // update state
    endtask


    task check_rat(); // prevents dual pointers
        for (a = 0; a < 32; a = a + 1) begin // *never synthesized* so optimization shouldn't be a big concern
            for (b = 0; b < 32; b = b + 1) begin
                assert (!((dut.rename_table[a] == dut.rename_table[b]) && (a != b) && (dut.rename_table[b] != 0)))
                    else begin
                        dump_state();
                        $fatal("Both %h and %h point to %h in the RAT", a, b, dut.rename_table[b]);
                    end
            end
        end
    endtask

    task test_basic();
        fd = $fopen("testcases/rename/basic.txt", "r");
        fd_expected = $fopen("testcases/rename/basic_expected.txt", "r");
        while ($fgets(line, fd)) begin
            $fgets(line_expected, fd_expected);
            $sscanf(line, "%h %h", uops[0], uops[1]);
            $sscanf(line_expected, "%h", expected_out);
            @(posedge clk);
            #1;
            check_flist();
            check_rat();
            //$write("%h\n",  {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards});
            assert (expected_out == {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards})
                else begin
                    dump_state();
                    $fatal("State does not match for basic!\n");
                end
        end
    endtask

    task test_stall();
        fd = $fopen("testcases/rename/stall.txt", "r");
        fd_expected = $fopen("testcases/rename/stall_expected.txt", "r");
        while ($fgets(line, fd)) begin
            $fgets(line_expected, fd_expected);
            $sscanf(line, "%b %b", uops[0], uops[1]);
            $sscanf(line_expected, "%b", expected_out);
            @(posedge clk);
            #1;
            check_flist();
            check_rat();
            //$write("%b\n",  {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards});
            assert (expected_out == {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards})
                else begin
                    dump_state();
                    $fatal("State does not match for stall!\n");
                end
            if (stall_backwards) begin
                f_list_freed = 6'b111110;
                f_list ^= f_list_freed;
                @(posedge clk);
                #1;
                f_list_freed = 1'b0;
                $fgets(line_expected, fd_expected);
                $sscanf(line_expected, "%b", expected_out);
                //$write("%b\n",  {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards});
                assert (expected_out == {f_list, f_list_allocated, renamed[0], renamed[1], rob_entries[0], rob_entries[1], tail, stall_backwards})
                    else begin
                        dump_state();
                        $fatal("State does not match for stall (stall edge case)!\n");
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

