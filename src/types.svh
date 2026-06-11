typedef struct packed {
	logic [3:0]  op; // specifies what operation to perform
	logic [2:0]  op_type; // specifies what logical hardware resource to delegate it to
	logic [5:0]  src1_reg; // index of src1's reg
	logic        src1_valid; // prevents non-used registers from being renamed
	logic [5:0]  src2_reg;
	logic        src2_valid;
	logic [5:0]  dst_reg; // same as above for destination
	logic        dst_valid;
	logic [19:0] immediate; // immediate/offset, J/U type use 20 bits
	logic        pred_taken; // for later use, currently always not taken to simplify fetching
	logic        faulted;
	logic [31:0] pc; // needed for jmps/interupts/calls/etc
	logic [3:0]  rob_id; // lets ROB know what entry it is
} uop_t;

typedef struct packed {
	logic       finished; // is it done?
	logic       spec;     // is it a speculative branch?
	logic       store;    // does it have to be retired from the LSQ?
	logic       dst_valid;// is the destination a register?
	logic [5:0] a_dst_reg;// destination for retiring architectural state
	logic [5:0] pp_dst_reg;// for freeing
	logic [5:0] p_dst_reg;// to update architectural state
	logic       misspredict;
	logic [31:0]     new_pc; // for mispred
} rob_ent_t;