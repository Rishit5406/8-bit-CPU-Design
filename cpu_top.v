module cpu_top (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [7:0] out_port
);

    // ============================
    // Registers 
    // ============================
    reg [7:0]  pc;
    reg [15:0] ir;
    reg [7:0]  acc;
    reg        zf;

    // ============================
    // ROM interface instantiation
    // ============================
    wire [15:0] rom_data;

    ROM u_rom (
        .addr(pc),
        .data(rom_data)
    );

    // ============================
    // Decode
    // ============================
    wire [3:0] opcode = ir[15:12];
    wire [7:0] imm    = ir[7:0];

    // ============================
    // ALU instantiation
    // ============================
    reg  [2:0] alu_sel;
    wire [7:0] alu_y;
    wire       alu_z;

    ALU u_alu (
        .a   (acc),
        .b   (imm),
        .sel (alu_sel),
        .y   (alu_y),
        .z   (alu_z)
    );

    // ============================
    // FSM states
    // ============================
    reg [2:0] state, next_state;

    // Defining states using parameters
    parameter S_FETCH     = 3'd0;
    parameter S_DECODE    = 3'd1;
    parameter S_EXEC_ALU  = 3'd2;
    parameter S_EXEC_BR   = 3'd3;
    parameter S_EXEC_OUT  = 3'd4;

    // ============================
    // Next-state logic (combinational)
    // ============================
    always @(*) begin
        next_state = state;
        case (state)
            S_FETCH: next_state = S_DECODE;

            S_DECODE: begin
                case (opcode)
                    4'h0: next_state = S_FETCH;      // NOP
                    4'h1,
                    4'h2,
                    4'h3,
                    4'h4,
                    4'h5: next_state = S_EXEC_ALU;   // ALU operations
                    4'h6,
                    4'h7: next_state = S_EXEC_BR;    // JMP or JZ
                    4'h8: next_state = S_EXEC_OUT;   // OUT
                    default: next_state = S_FETCH;
                endcase
            end

            S_EXEC_ALU: next_state = S_FETCH;
            S_EXEC_BR:  next_state = S_FETCH;
            S_EXEC_OUT: next_state = S_FETCH;

            default: next_state = S_FETCH;
        endcase
    end

    // ============================
    // ALU control (combinational)
    // ============================
    always @(*) begin
        alu_sel = 3'b000;  // default
        case (opcode)
            4'h1: alu_sel = 3'b000; // LOAD
            4'h2: alu_sel = 3'b001; // ADD
            4'h3: alu_sel = 3'b010; // SUB
            4'h4: alu_sel = 3'b011; // AND
            4'h5: alu_sel = 3'b100; // OR
            default: alu_sel = 3'b000;
        endcase
    end

    // ============================
    // Sequential logic (register updates)
    // ============================
    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_FETCH;
            pc       <= 8'h00;
            ir       <= 16'h0000;
            acc      <= 8'h00;
            zf       <= 1'b1;
            out_port <= 8'h00;
        end else begin
            state <= next_state;

            case (state)
                // FETCH: read ROM at PC into IR and increment PC
                S_FETCH: begin
                    ir <= rom_data;
                    pc <= pc + 8'h01;
                end

                // EXECUTE ALU operations
                S_EXEC_ALU: begin
                    acc <= alu_y;
                    zf  <= alu_z;
                end

                // EXECUTE BRANCH instructions
                S_EXEC_BR: begin
                    if (opcode == 4'h6) begin
                        pc <= imm;        // JMP
                    end else if (opcode == 4'h7) begin
                        if (zf)
                            pc <= imm;    // JZ
                    end
                end

                // EXECUTE OUT instruction
                S_EXEC_OUT: begin
                    out_port <= acc;
                end

                default: ;
            endcase
        end
    end

endmodule
