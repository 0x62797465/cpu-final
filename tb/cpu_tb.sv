module cpu_tb;
    reg clk   = '0;
    reg reset = '1;
    always #10 clk = ~clk;
    
    int file_size;
    int fd, fd_test;
    string line;
    string test_name;
    reg [31:0] expected_x15;
    int i = 0;

    reg UART_TX = 0;
    reg UART_RX = 0;

    cpu dut (
        .CLOCK_50_B5B(clk),
        .CPU_RESET_n(reset),
        .UART_RX(UART_RX),
        .UART_TX(UART_TX)
    );
    reg [7:0] chr;
    reg chr_ready;
    reg tm_ready;
    char_out out (
        .chr(chr),
        .chr_ready(chr_ready),
        .clk(clk),
        .CPU_RESET_n(reset),
        .tm_ready(tm_ready),
        .UART_TX(UART_RX)
    );

    reg [3:0] [7:0] file_size_reg;
    reg [7:0] buff;
    task test_programs();
        fd_test = $fopen("testcases/cpu/tests.txt", "r");
        while ($fgets(line, fd_test)) begin
            chr_ready = 0;
            $sscanf(line, "%s %h", test_name, expected_x15);
            reset = 0;
            @(posedge clk);
            @(negedge clk);
            fd = $fopen({"testcases/cpu/", test_name}, "rb");
            $fseek(fd, 0, 2);
            file_size = $ftell(fd);
            $fclose(fd);
            fd = $fopen({"testcases/cpu/", test_name}, "rb");
            i = 0;
            @(posedge clk);
            @(negedge clk);
            reset = 1;
            @(posedge clk);
            @(negedge clk);    
            file_size_reg = file_size;
            for (int a = 0; a < 4; a++) begin
                while (1) begin
                    @(posedge clk);
                    if (tm_ready) begin
                        chr = file_size_reg[a];
                        chr_ready = 1'b1;
                        break;
                    end
                end
                @(posedge clk);
                @(negedge clk);
                while (1) begin
                    if (!tm_ready) begin
                        @(posedge clk);
                        chr_ready = 1'b0;
                        break;
                    end
                end
                while (1) begin
                    @(posedge clk);
                    if (tm_ready)
                        break;
                end
            end
            while ($fread(buff, fd)) begin
                while (1) begin
                    @(posedge clk);
                    if (tm_ready) begin
                        chr = buff;
                        chr_ready <= 1'b1;
                        break;
                    end
                end
                @(posedge clk);
                @(negedge clk);
                chr_ready <= 1'b0;
                while (1) begin
                    @(posedge clk);
                    if (tm_ready)
                        break;
                end
            end

            $fclose(fd);


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
        $fclose(fd_test);
    endtask

    initial begin
        test_programs();
        $finish();
    end
endmodule