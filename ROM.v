`timescale 1ns / 1ps
module ROM(
    input wire [7:0] addr,  
    output reg [15:0] data  
    );
    //data == [15:12]:Opcode [11:8]=0000 reserved  [7:0]=imm
    always@(*) begin
        case(addr)
            8'h00: data = {4'h1,4'h0,8'h01}; //0001=opcode=load
            8'h01: data = {4'h8,4'h0,8'h00}; //1000=opcode=out
            8'h02: data = {4'h2,4'h0,8'h01}; //0010=opcode=add
            8'h03: data = {4'h8,4'h0,8'h00}; //1000=opcode=out
            8'h04: data = {4'h6,4'h0,8'h01}; //0110=opcode=JMP
            default : data = 16'h0000; 
         endcase
    end         
endmodule
