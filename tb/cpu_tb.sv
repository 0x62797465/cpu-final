module cpu_tb;
    reg clk   = '0;
    reg reset = '1;
    always #10 clk = ~clk;
    
    int fd;
    int i = 0;

    cpu dut (.CLOCK_50_B5B(clk), .CPU_RESET_n(reset));

    reg [31:0] buff;
    task test_program();
        reset = 0;
        @(posedge clk);
        @(negedge clk);
        fd = $fopen("testcases/cpu/factor.bin", "rb");
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
            for (int a = 0; a < 32; a++) begin
                $write("%d: %h ; ", a, dut.p_regs[dut.a_reg_state[a]]);
            end
            $write("halt: %b", dut.halt);
            $write("\n");
        end
    endtask

    initial begin
        test_program();
        $finish();
    end
endmodule