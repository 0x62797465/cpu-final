`include "../src/types.svh"

module decode_tb;
    reg clk = 0;
    always #10 clk = ~clk;
    reg [31:0] prev_fetch_addr = 0;
    uop_t [1:0] uops = 0;
    uop_t [1:0] uops_correct = 0;
    int fd;
    int fd_valid;
    string line;
    reg [1:0] [31:0] instructions;
    decode dut (.clk(clk), .instructions(instructions), .uops(uops), 
        .CPU_RESET_n(1'b1), .stall(1'b0), .prev_fetch_addr(prev_fetch_addr)); // sane defaults
    initial begin
        fd_valid = $fopen("testcases/decode/expected_uops_d.txt", "r"); // known good output
        fd = $fopen("testcases/decode/test_instr_d.txt", "r"); // hardcoded hex instructions
        while ($fgets(line, fd)) begin // use every line
            $sscanf(line, "%h %h", instructions[0], instructions[1]); // convert to two usable instructions
            $fgets(line, fd_valid); // use every line
            $sscanf(line, "%h %h", uops_correct[0], uops_correct[1]); // convert to two usable uops
            @(posedge clk) // wait for a clock cycle+1 to read after decoder decodes
            #1;
            prev_fetch_addr = prev_fetch_addr + 8;
            assert (uops_correct[0] == uops[0]) // validate
                else $fatal("%b does not match expected %b", uops[0], uops_correct[0]);
            assert (uops_correct[1] == uops[1])
                else $fatal("%b does not match expected %b", uops[1], uops_correct[1]);
            end
        $finish; // end cleanly
    end
endmodule
