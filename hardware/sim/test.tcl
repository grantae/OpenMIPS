# Wait for early messages to clear
run 1us
puts "Simulating 400us..."
run 399us
if {[test uut/MIPS32/Core/RegisterFile/registers(2) deafbeef -radix hex]} {
    puts "MIPS32r1 test succeeded."
} else {
    puts "MIPS32r1 test failed."
}
quit
