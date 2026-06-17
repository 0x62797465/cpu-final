`include "../src/types.svh"

module decode_tb;
    reg clk = 0;
    always #10 clk = ~clk;
    reg [31:0] prev_fetch_addr = 0;
    reg reset = 0;
    uop_t [1:0] uops;
    uop_t [1:0] uops_correct;
    reg jmp;
    reg [31:0] new_pc;
    int fd;
    int fd_valid;
    int sys_res;
    string line;
    reg [1:0] [31:0] instructions;
    decode dut (.clk(clk), .instructions(instructions), .uops(uops), 
        .CPU_RESET_n(reset), .stall(1'b0), .prev_fetch_addr(prev_fetch_addr),
        .n_valid(1'b0), .jmp(jmp), .new_pc(new_pc), .flush(1'b0)); // sane defaults
    
    task reset_stage();
        instructions = '0;
        reset = '0;
        @(posedge clk);
        reset = 1'b1;
    endtask

    initial begin
        fd_valid = $fopen("testcases/decode/expected_uops_d.txt", "r"); // known good output
        fd = $fopen("testcases/decode/test_instr_d.txt", "r"); // hardcoded hex instructions
        reset_stage();
        while ($fgets(line, fd)) begin // use every line
            sys_res = $sscanf(line, "%h %h", instructions[0], instructions[1]); // convert to two usable instructions
            sys_res = $fgets(line, fd_valid); // use every line
            sys_res = $sscanf(line, "%h %h", uops_correct[0], uops_correct[1]); // convert to two usable uops
            @(posedge clk) // wait for a clock cycle+1 to read after decoder decodes
            @(negedge clk)
            prev_fetch_addr = prev_fetch_addr + 8;
            assert (uops_correct[0] == uops[0]) // validate
                else $fatal(1, "%b does not match expected %b", uops[0], uops_correct[0]);
            assert (uops_correct[1] == uops[1])
                else $fatal(1, "%b does not match expected %b", uops[1], uops_correct[1]);
            end
        $finish; // end cleanly
    end
endmodule
