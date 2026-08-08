`timescale 1ns / 1ps

//ROM only stores instruction, it does not execute 
//execution only happens in FSM, ALU, registers

module ROM(
    input wire [7:0] addr,  //takes from PC
    output reg [15:0] data  //outputs instruction
    );
    //data == [15:12]:Opcode [11:8]=0000 reserved  [7:0]=imm
    always@(*) begin
        case(addr)
            8'h00: data = {4'h1,4'h0,8'h01}; //0001=opcode=load
            8'h01: data = {4'h8,4'h0,8'h00}; //1000=opcode=out
            8'h02: data = {4'h2,4'h0,8'h01}; //0010=opcode=add
            8'h03: data = {4'h8,4'h0,8'h00}; //1000=opcode=out
            8'h04: data = {4'h6,4'h0,8'h01}; //0110=opcode=JMP
            
            default : data = 16'h0000; //if addr doesnt match output a NOP instruction
         endcase
         
         //what happens: 
         //PC=0 ROM ouputs load 1 PC+1
         //PC=1 ROM outputs OUT
         //PC=2 ROM outputs ADD 1
         //PC=3 ROM outpts OUT
         //PC=4 ROM outputs JMP 1 so it jumps back to PC to 1
         //and loop continues forever
    end         
endmodule
