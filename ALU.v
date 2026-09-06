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
            3'b000 : y = b;      
            3'b001 : y = a + b;  
            3'b010 : y = a - b;  
            3'b011 : y = a & b;  
            3'b100 : y = a | b;  
            default : y = 8'h00; 
        endcase                  
    end
    assign z = (y == 8'h00);
endmodule
