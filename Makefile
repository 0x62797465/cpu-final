all: decode_tb rename_tb issue_tb alu_tb

decode_tb: src/decode.sv tb/decode_tb.sv
	vlib work
	vmap work work
	vlog -sv +incdir+src src/decode.sv tb/decode_tb.sv
	SALT_LICENSE_SERVER=~/Tools/LR-156275_License.dat vsim -suppress 12110 -quiet -c work.decode_tb -do "run -all; quit"

rename_tb: src/rename.sv tb/rename_tb.sv
	vlib work
	vmap work work
	vlog -sv src/rename.sv tb/rename_tb.sv
	SALT_LICENSE_SERVER=~/Tools/LR-156275_License.dat vsim -suppress 12110 -quiet -c work.rename_tb -do "run -all; quit"

issue_tb: src/issue.sv tb/issue_tb.sv
	vlib work
	vmap work work
	vlog -sv src/issue.sv tb/issue_tb.sv
	SALT_LICENSE_SERVER=~/Tools/LR-156275_License.dat vsim -suppress 12110 -quiet -c work.issue_tb -do "run -all; quit"

alu_tb: src/alu.sv tb/alu_tb.sv
	vlib work
	vmap work work
	vlog -sv src/alu.sv tb/alu_tb.sv
	SALT_LICENSE_SERVER=~/Tools/LR-156275_License.dat vsim -suppress 12110 -quiet -c work.alu_tb -do "run -all; quit"

