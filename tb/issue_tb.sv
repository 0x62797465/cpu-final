`include "../src/types.svh"

module issue_tb;
    int fd, fd_expected;
    int i;
    int ignore_sys_res;
    string line, line_expected;
    reg [263:0] expected_out;
    reg clk;
    reg reset = '1;
    uop_t [1:0] uops_renamed;
    reg [63:0] p_reg_ready;
    reg [3:0] head;

    reg last_cycle_stall_reason;
    uop_t alu_1_uop;
    uop_t alu_2_uop;
    uop_t agu_uop;
    reg should_unstall;
    reg alu_1_valid;
    reg alu_2_valid;
    reg agu_valid;
    reg agu_ready;
    reg why_stall;
    always #10 clk = ~clk;

    issue dut (.clk(clk), .CPU_RESET_n(reset), .uops_renamed(uops_renamed), .agu_ready(agu_ready),
        .p_reg_ready(p_reg_ready), .head(head), .alu_1_uop(alu_1_uop), .alu_2_uop(alu_2_uop), 
        .alu_1_valid(alu_1_valid), .alu_2_valid(alu_2_valid), .agu_uop(agu_uop),
        .agu_valid(agu_valid), .stall_backwards(stall_backwards), .flush(1'b0));

    task reset_stage();
        reset = 0;
        @(posedge clk);
        reset = 1;
    endtask

    task shouldstall(); // prevents un-needed stalling
        assert (!((stall_backwards && should_unstall) && // if we should unstall this cycle and we have not
        !(($countones(dut.alu_uops_fl) <= 5) || // if we should be stalling 
        ((dut.mem_tail+1) == (dut.mem_head)) || ((dut.mem_tail==dut.mem_head && 
            |dut.mem_issue_queue[dut.mem_head])))))  
            else
                $write("Stalled without reason; amount free ALU %d MEM %d %d last cycle's stall reason (1 means ALU) %b\n", $countones(dut.alu_uops_fl), dut.mem_tail, dut.mem_head, last_cycle_stall_reason);
        if (stall_backwards) begin
            if ((($countones(dut.alu_uops_fl) <= 5) || // if we should be stalling 
            ((dut.mem_tail+1) == (dut.mem_head)) || ((dut.mem_tail==dut.mem_head && 
            |dut.mem_issue_queue[dut.mem_head]))))
                should_unstall <= 1'b0;
            else
                should_unstall <= 1'b1;
        end else 
            should_unstall <= 1'b0;
        last_cycle_stall_reason <= ($countones(dut.alu_uops_fl) <= 5);
    endtask
    // test stall ALU (full IQ)
    task test_full_ALU_IQ();
        fd = $fopen("testcases/issue/alu_stall.txt", "r");
        fd_expected = $fopen("testcases/issue/alu_stall_expected.txt", "r");
        while ($fgets(line, fd) && $fgets(line_expected, fd_expected)) begin
            shouldstall();
            ignore_sys_res = $sscanf(line, "%h %h", uops_renamed[0], uops_renamed[1]);
            ignore_sys_res = $sscanf(line_expected, "%h", expected_out);
            agu_ready <= '0;
            @(posedge clk)
            #1
            assert (expected_out == {alu_1_uop, alu_2_uop, alu_1_valid, alu_2_valid, agu_uop, agu_valid, stall_backwards})
                else 
                    $fatal("Output does not match expected, expected: %h output: %h\n", expected_out, {alu_1_uop, alu_2_uop, alu_1_valid, alu_2_valid, agu_uop, agu_valid, stall_backwards});
            if (stall_backwards) begin
                for (int a = 0; a < 8; a = a + 1) begin
                    if ((!dut.alu_uops_fl[a])) begin 
                        if (dut.alu_issue_queue[a].src1_valid) begin
                            p_reg_ready[dut.alu_issue_queue[a].src1_reg] <= 1'b1;
                        end 
                        if (dut.alu_issue_queue[a].src2_valid) begin
                            p_reg_ready[dut.alu_issue_queue[a].src2_reg] <= 1'b1;
                        end
                        break;
                    end
                end
            end
        end
    endtask

    task test_basic(); // triggers ALU stall, both mem stall types, and tries to emulate what the CPU will do (not too acuratly, but enough to where functionality should be shown)
        fd = $fopen("testcases/issue/basic.txt", "r");
        fd_expected = $fopen("testcases/issue/basic_expected.txt", "r");
        i = $fgets(line, fd);
        agu_ready <= '0;
        while (i) begin // && $fgets(line_expected, fd_expected)) begin
            shouldstall();
            if (!stall_backwards) begin
                ignore_sys_res = $sscanf(line, "%h %h", uops_renamed[0], uops_renamed[1]);
                i = $fgets(line, fd); // an iq too high?
            end
            ignore_sys_res = $fgets(line_expected, fd_expected);
            ignore_sys_res = $sscanf(line_expected, "%h", expected_out);
            @(negedge clk)

            why_stall = ($countones(dut.alu_uops_fl) <= 5);

            assert (expected_out == {alu_1_uop, alu_2_uop, alu_1_valid, alu_2_valid, 
            agu_uop, agu_valid, agu_ready, stall_backwards, 
            why_stall})
                else 
                    $fatal(1, "Output does not match expected, expected: %b output: %b\n",
                     expected_out, {alu_1_uop, alu_2_uop, alu_1_valid, alu_2_valid, 
                    agu_uop, agu_valid, agu_ready, stall_backwards, 
                    why_stall});
            
            // sets to one if stalling because ALU
            if (agu_valid) begin
                agu_ready <= 1'b0;
            end
            if (stall_backwards && !why_stall) begin // marks needed regs as ready and says "hey the agu is available"
                if ((dut.mem_issue_queue[dut.mem_head].rob_id-head)) begin
                    if (dut.mem_issue_queue[dut.mem_head].src1_valid) begin
                        p_reg_ready[dut.mem_issue_queue[dut.mem_head].src1_reg] <= 1'b1;
                    end 
                    if (dut.mem_issue_queue[dut.mem_head].src2_valid) begin
                        p_reg_ready[dut.mem_issue_queue[dut.mem_head].src2_reg] <= 1'b1;
                    end       
                end
                agu_ready <= 1'b1;
            end

            if (stall_backwards && why_stall) begin
                for (int a = 0; a < 8; a = a + 1) begin
                    if ((!dut.alu_uops_fl[a])) begin
                        if (dut.alu_issue_queue[a].src1_valid) begin
                            p_reg_ready[dut.alu_issue_queue[a].src1_reg] <= 1'b1;
                        end 
                        if (dut.alu_issue_queue[a].src2_valid) begin
                            p_reg_ready[dut.alu_issue_queue[a].src2_reg] <= 1'b1;
                        end
                        break;
                    end
                end
            end
        end
    endtask
    
    initial begin
        reset_stage();
        test_full_ALU_IQ();
        reset_stage();
        test_basic();
        $finish();
    end
endmodule
