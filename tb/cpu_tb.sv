module cpu_tb;
    reg clk   = '0;
    reg reset = '1;
    always #10 clk = ~clk;
    
    int fd, fd_test;
    string line;
    string test_name;
    reg [31:0] expected_x15;
    int i = 0;

    cpu dut (.CLOCK_50_B5B(clk), .CPU_RESET_n(reset));

    reg [31:0] buff;
    task test_programs();

        fd_test = $fopen("testcases/cpu/tests.txt", "r");
        while ($fgets(line, fd_test)) begin
            $sscanf(line, "%s %h", test_name, expected_x15);
            reset = 0;
            @(posedge clk);
            @(negedge clk);
            fd = $fopen({"testcases/cpu/", test_name}, "rb");
            for (int i = 0; i < 8192; i++) begin
                dut.mem[i] = '0;
                dut.agu.mem[i] = '0;
                i++;
            end
            i = 0;
            while ($fread(buff, fd)) begin
                dut.mem[i] = {buff[7:0], buff[15:8], buff[23:16], buff[31:24]};
                dut.agu.mem[i] = {buff[7:0], buff[15:8], buff[23:16], buff[31:24]};
                i++;
            end


            @(posedge clk);
            @(negedge clk);
            reset = 1;
            for (int i = 0; i < 5000; i++) begin
                @(posedge clk);
                if (dut.p_regs[dut.a_reg_state[31]] == 31'hef)
                    break;
                for (int a = 0; a < 32; a++) begin
                    //$write("%d: %h ; ", a, dut.p_regs[dut.a_reg_state[a]]);
                end
                //$write("halt: %b", dut.halt);
                //$write("\n");
            end
            $write("%s took %h cycles %h jumps %h misspredictions\n", test_name, dut.cycle_count, dut.jump_count, dut.misspred_count);
            assert (dut.p_regs[dut.a_reg_state[15]] == expected_x15)
                else $fatal(1, "Expected value %h does NOT match %h!\n", expected_x15, dut.p_regs[dut.a_reg_state[15]]);
        end
    endtask

    initial begin
        test_programs();
        $finish();
    end
endmodule