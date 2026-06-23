`include "types.svh"

// This module functions as an arithmatic unit but
// also as somewhat of a decoder, since it is responsible
// for making sure operations are valid. It is also utilized
// for control flow instructions since we it also simplifies our
// pipeline since we don't want an entire seperate control
// flow unit. 

module alu (
    input               clk,
    input               CPU_RESET_n,
    input var uop_t     uop,
    input               valid,
    input reg [31:0]    src_1,
    input reg [31:0]    src_2,
    input               flush,

    output var post_ex_uop_t uop_out,
    output reg ready
);


uop_t working_uop;
reg [1:0] valid_count;
logic was_taken = '0;
reg mul;
reg [63:0] mul_res;
reg src_1_sign;
reg src_2_sign;

// working div regs
reg div;
reg [31:0] div_src1;
reg [31:0] div_src2;
reg [31:0] div_acum;
reg [4:0]  acum_ptr;

logic [31:0] src_1_unsigned;
assign src_1_unsigned = (src_1[31] & uop.op == 4'b0001) || 
    (src_1[31] & uop.op == 4'b0010) ? -src_1 : src_1;
logic [31:0] src_2_unsigned;
assign src_2_unsigned = (src_2[31] & uop.op == 4'b0001) ? -src_2 : src_2;

// should automatically use DSP block
always @(posedge clk)
    mul_res <= src_1_unsigned*src_2_unsigned;

always @(posedge clk or negedge CPU_RESET_n) begin
	if (!CPU_RESET_n) begin
        uop_out <= '0;
        valid_count <= '0;
        ready <= '1;
        mul <= '0;
        div <= '0;
    end else if (flush) begin
        uop_out <= '0;
        valid_count <= '0;
        div_acum <= '0;
        div_src1 <= '0;
        ready <= '1;
        mul <= '0;
        div <= '0;
    end else if (div) begin
        logic [31:0] tmp_acum;
        logic [31:0] tmp_rem;
        logic [63:0] tmp_div; // running out of names
        valid_count <= valid_count + valid;
        tmp_acum = div_acum;
        tmp_rem = div_src1;
        if (acum_ptr == 0 || div_src1 == 0 || div_src2 == 0) begin
            ready <= 1'b1;
            div <= 1'b0;

            uop_out.was_uart <= 1'b0;
            uop_out <= '0;
            uop_out.was_mem <= 1'b0;
            uop_out.was_jmp <= 1'b0;
            uop_out.rob_id <= working_uop.rob_id;
            uop_out.dst_val <= '0;
            uop_out.dst_reg <= working_uop.dst_reg;
            uop_out.dst_valid <= working_uop.dst_valid;
            uop_out.faulted <= working_uop.faulted;
            uop_out.valid <= 1'b1;
            uop_out.unconditional_jmp <= 1'b0;

            case (working_uop.op)
                4'b0100 : 
                    uop_out.dst_val <= (src_1_sign^src_2_sign) ? -div_acum : div_acum;
                4'b0101 :
                    uop_out.dst_val <= div_acum;
                4'b0110 :
                    uop_out.dst_val <= src_1_sign ? -div_src1 : div_src1;
                4'b0111 :
                    uop_out.dst_val <= div_src1;
            endcase
        end else begin
            for (int i = 0; i < 2; i++) begin
                tmp_div = {{32{1'b0}}, div_src2} << (acum_ptr-i);
                if (tmp_rem >= tmp_div) begin
                    tmp_acum[acum_ptr-i] = 1'b1;
                    tmp_rem = {{32{1'b0}}, tmp_rem} - tmp_div;
                end
            end

            div_src1 <= tmp_rem;
            if (acum_ptr == 1) begin
                acum_ptr <= '0;
            end else
                acum_ptr <= acum_ptr - 2;
            div_acum <= tmp_acum;
        end
    end else if (mul) begin
        logic [63:0] negative_mul_res; 
        ready <= 1'b1;
        mul <= 1'b0;
        negative_mul_res = -mul_res;

        valid_count <= valid_count + valid;
        uop_out.was_uart <= 1'b0;
        uop_out <= '0;
        uop_out.was_mem <= 1'b0;
        uop_out.was_jmp <= 1'b0;
        uop_out.rob_id <= working_uop.rob_id;
        uop_out.dst_val <= '0;
        uop_out.dst_reg <= working_uop.dst_reg;
        uop_out.dst_valid <= working_uop.dst_valid;
        uop_out.faulted <= working_uop.faulted;
        uop_out.valid <= 1'b1;
        uop_out.unconditional_jmp <= 1'b0;

        case (working_uop.op)
            4'b0000 : 
                uop_out.dst_val <= mul_res[31:0];
            4'b0001 :
                uop_out.dst_val <= (src_1_sign ^ src_2_sign) ?
                    negative_mul_res[63:32] : mul_res[63:32];
            4'b0010 : 
                uop_out.dst_val <= (src_1_sign) ?
                    negative_mul_res[63:32] : mul_res[63:32];
            4'b0011 : 
                uop_out.dst_val <= mul_res[63:32];
            default : 
                uop_out.faulted <= 1'b1;
        endcase
    end else if (valid | valid_count) begin
        working_uop <= uop;
        ready <= 1'b1;
        valid_count <= valid_count + valid - 1;
        was_taken = 0;

        uop_out.was_uart <= 1'b0;
        uop_out <= '0;
        uop_out.was_mem <= 1'b0;
        uop_out.was_jmp <= 1'b0;
        uop_out.rob_id <= uop.rob_id;
        uop_out.dst_val <= '0;
        uop_out.dst_reg <= uop.dst_reg;
        uop_out.dst_valid <= uop.dst_valid;
        uop_out.faulted <= uop.faulted;
        uop_out.valid <= 1'b1;
        uop_out.unconditional_jmp <= 1'b0;

        if (uop.op_type == 3'b111) begin // RV32M logic
            ready <= 1'b0;
            if (uop.op == 4'b0000 || uop.op == 4'b0001 
                    || uop.op == 4'b0010 || uop.op == 4'b0011) begin
                mul <= 1'b1;
                uop_out.valid <= 1'b0;
                src_1_sign <= src_1[31];
                src_2_sign <= src_2[31];
            end else if (uop.op == 4'b0101 || uop.op == 4'b0111) begin
                div_acum <= '0;
                acum_ptr <= 5'd31;
                div <= 1'b1;
                uop_out.valid <= 1'b0;
                src_1_sign <= 1'b0;
                src_2_sign <= 1'b0;
                div_src1 <= src_1;
                div_src2 <= src_2;
            end else if (uop.op == 4'b0100 || uop.op == 4'b0110) begin
                div_acum <= '0;
                acum_ptr <= 5'd31;
                div <= 1'b1;
                uop_out.valid <= 1'b0;
                src_1_sign <= src_1[31];
                src_2_sign <= src_2[31];
                div_src1 <= src_1[31] ? -src_1 : src_1;
                div_src2 <= src_2[31] ? -src_2 : src_2;
            end
        end else begin
            case (uop.op_type)
                3'b110: begin 
                    if (uop.op)
                        uop_out.dst_val <= (uop.immediate << 12) + uop.pc;
                    else
                        uop_out.dst_val <= {{12{1'b0}}, uop.immediate} << 12;
                end
                3'b101: // jmp+pc // actual jumping handled during decode; dst reg assignment now
                    uop_out.dst_val <= uop.pc + 4;
                3'b100: begin // condtional jumps
                    uop_out.was_jmp <= 1'b1;
                    uop_out.pred_taken <= uop.pred_taken;
                    case (uop.op)
                        4'b0000: 
                            was_taken = (src_1 == src_2); 
                        4'b0001:
                            was_taken = (src_1 != src_2);
                        4'b0100:
                            was_taken = ($signed(src_1) <  $signed(src_2));
                        4'b0101:
                            was_taken = ($signed(src_1) >= $signed(src_2));
                        4'b0110:
                            was_taken = (src_1 < src_2);
                        4'b0111:
                            was_taken = (src_1 >= src_2);
                        default:
                            uop_out.faulted <= 1'b1;
                    endcase
                    if (was_taken) begin
                        uop_out.taken <= 1'b1;
                        uop_out.new_pc <= {{19{uop.immediate[11]}}, uop.immediate[11:0], 1'b0} + uop.pc;
                    end else begin
                        uop_out.taken <= 1'b0;
                        uop_out.new_pc <= uop.pc + 4; // inc instruction
                    end
                end
                3'b010: begin // JAL (reg)
                    uop_out.was_jmp <= 1'b1;
                    uop_out.pred_taken <= 1'b0; // manually invoke mispred logic
                    uop_out.taken <= 1'b1;
                    uop_out.new_pc <= ((src_1) + {{20{uop.immediate[11]}}, uop.immediate[11:0]}) & {{31{1'b1}}, 1'b0};
                    uop_out.dst_val <= uop.pc + 4;
                end
                3'b000: begin // the real ALU part
                    logic [31:0] imm_tmp;
                    imm_tmp = {{20{uop.immediate[11]}}, uop.immediate[11:0]};
                    case (uop.op)
                        4'b0000: // add
                            uop_out.dst_val <= uop.src2_valid ? 
                                (src_1+src_2) : (src_1+imm_tmp);
                        4'b1000: // sub
                            uop_out.dst_val <= src_1-src_2;
                        4'b0100: // xor
                            uop_out.dst_val <= uop.src2_valid ? 
                                (src_1^src_2) : (src_1^imm_tmp);
                        4'b0110: // or
                            uop_out.dst_val <= uop.src2_valid ? 
                                (src_1|src_2) : (src_1|imm_tmp);
                        4'b0111: // and
                            uop_out.dst_val <= uop.src2_valid ? 
                                (src_1&src_2) : (src_1&imm_tmp);
                        4'b0001: // sll
                            uop_out.dst_val <= uop.src2_valid ? 
                                (src_1<<(src_2[4:0])) : (src_1<<(uop.immediate[4:0]));
                        4'b0101: // srl
                            uop_out.dst_val <= uop.src2_valid ? 
                                (src_1>>(src_2[4:0])) : (src_1>>(uop.immediate[4:0]));
                        4'b1101: // sra arith (msb extends)
                            uop_out.dst_val <= uop.src2_valid ? 
                                ($signed(src_1)>>>(src_2[4:0])) : ($signed(src_1)>>>(uop.immediate[4:0]));
                        4'b0010: // set less than (slt)
                            uop_out.dst_val <= uop.src2_valid ?
                                (($signed(src_1) < $signed(src_2)) ? 1 : 0)
                                : (($signed(src_1) < $signed(imm_tmp)) ? 1 : 0);
                        4'b0011: // set less than unsigned (sltu) (zero extends)
                            uop_out.dst_val <= uop.src2_valid ?
                                ((src_1 < src_2) ? 1 : 0)
                                : ((src_1 < imm_tmp) ? 1 : 0);
                        default:
                            uop_out.faulted <= 1'b1;
                    endcase
                end
                default:
                    uop_out.faulted <= 1'b1;
            endcase
        end
    end else
        uop_out <= '0;
end
endmodule