`timescale 1ns/1ps  // Simulation time unit
module test_bench;
    reg clk;
    reg rst_n;
    wire [7:0] out_port;
    cpu_top uut (.clk(clk), .rst_n(rst_n), .out_port(out_port));
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  
    end
    // Reset and simulation control
    initial begin
        // Initialize
        rst_n = 0;
        #12;             // Hold reset for a few cycles
        rst_n = 1;       // Release reset
        
        // Run simulation 
        #400;            
        $finish;           
    end
    initial begin
        $display("Time\tPC\tIR\tACC\tZF\tOUT");
        $monitor("%0dns\t%0d\t%h\t%h\t%b\t%h", 
                  $time, uut.pc, uut.ir, uut.acc, uut.zf, out_port);
    end
endmodule
