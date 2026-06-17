# Testbench
See if misprediction is triggered (testing will be left for entire CPU module testbench)
Make sure free list remains consistent (should be similar to the one in rename)
Make sure outputted freelist is correct
Make sure the head is consistent
Test if faulting is triggered correctly

# Misc
Add UART to a certain address and testbench

# Testbench CPU.sv with realish programs

# FPGA!

# Bonus
Make IP relative jumps execute immediatly after decoding (would run alongside of rename, execute would treat the instruction as a NOP)
Predict conditional jumps during the same stage (execute would serve to test if prediction was correct, ROB would make everything correct), additionally store a correct/not correct counter. 
Make the memory unit have a 1-cycle delay instead of 2 (LSQ stuff).
Real pages with actual permission bits
Make oob reads/writes actually fault
Rewrite rename testbench