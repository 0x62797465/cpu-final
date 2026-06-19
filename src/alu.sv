`include "types.svh"

// This module functions as an arithmatic unit but
// also as somewhat of a decoder, since it is responsible
// for making sure operations are valid. It is also utilized
// for control flow instructions since we it also simplifies our
// pipeline since we don't want an entire seperate control
// flow unit. 

// For conceptual simplicity, although the original uop
// structure probably would've been optimized automatically
// to be more ~~memory~~ LUT efficient. 

module alu (
    input               clk,
    input               CPU_RESET_n,
    input var uop_t     uop,
    input               valid,
    input reg [31:0]    src_1,
    input reg [31:0]    src_2,
    input               flush,

    output var post_ex_uop_t uop_out
);
logic was_taken = '0;
always @(posedge clk or negedge CPU_RESET_n) begin
	if (!CPU_RESET_n) begin
        uop_out <= '0;
    end else if (flush) begin
        uop_out <= '0;
    end else if (valid) begin
        was_taken = 0;
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
        case (uop.op_type)
            3'b110: // load
                uop_out.dst_val <= {{12{1'b0}}, uop.immediate} << 12;
            3'b111: // load+pc
                uop_out.dst_val <= (uop.immediate << 12) + uop.pc;
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
    end else
        uop_out <= '0;
end
endmodule