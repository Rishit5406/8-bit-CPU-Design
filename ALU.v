`timescale 1ns / 1ps

module ALU(
    input wire [7:0]a,
    input wire [7:0]b,
    input wire [2:0]sel,
    output reg [7:0]y,
    output wire z
    );
    
    always@(*) begin
        case(sel)
            3'b000 : y = b;      //loads the instruction(ACC <- IMM)
            3'b001 : y = a + b;  //ADD ; hardware it will be an 8 bit adder to 1 input of MUX
            3'b010 : y = a - b;  //SUB ; implemented using adder and 2s complement internally 
            3'b011 : y = a & b;  //AND ;8 parallel AND gates
            3'b100 : y = a | b;  //OR  ;8 parallel or gates
            default : y = 8'h00; //if sel is none of values listed above set outpyt y to 0
        endcase                  //without default synthesizer creates latch(unwanted memory)
    end
    
    assign z = (y == 8'h00);
      
endmodule

