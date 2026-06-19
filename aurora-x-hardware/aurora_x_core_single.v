module aurora_x_core (
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction Memory Interface
    output reg  [63:0] pc,
    input  wire [31:0] inst,
    
    // Data Memory Interface
    output wire [63:0] data_addr,
    output wire [63:0] data_write_val,
    input  wire [63:0] data_read_val,
    output wire        data_we,
    output wire        data_re,

    // Test Interface (CSR 0x700)
    output reg  [63:0] test_status
);

    // Wires
    wire [7:0]  opcode;
    wire [4:0]  rd, rs1, rs2;
    wire [13:0] imm14;
    wire [18:0] imm19;
    wire [11:0] csr_addr;
    wire [8:0]  funct9;

    wire [63:0] imm14_sext, imm19_sext;
    wire RegWrite, ALUSrc_B, MemRead, MemWrite, Branch, Jump, CSR_Write, CSR_Read;
    wire [2:0] ALU_Op;
    wire [1:0] MemtoReg;

    wire VectorOp, VectorRegWrite, VectorMemRead, VectorMemWrite;
    wire [2:0] VALU_Op;

    wire [63:0] read_data1, read_data2;
    wire [63:0] alu_result;
    wire alu_zero;

    // Decoder
    decoder u_decoder (
        .inst(inst),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm14(imm14),
        .imm19(imm19),
        .csr_addr(csr_addr),
        .funct9(funct9),
        .imm14_sext(imm14_sext),
        .imm19_sext(imm19_sext),
        .RegWrite(RegWrite),
        .ALUSrc_B(ALUSrc_B),
        .ALU_Op(ALU_Op),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .Branch(Branch),
        .Jump(Jump),
        .CSR_Write(CSR_Write),
        .CSR_Read(CSR_Read),
        .MemtoReg(MemtoReg),
        .VectorOp(VectorOp),
        .VectorRegWrite(VectorRegWrite),
        .VectorMemRead(VectorMemRead),
        .VectorMemWrite(VectorMemWrite),
        .VALU_Op(VALU_Op)
    );

    // Register File
    reg  [63:0] reg_write_data;
    register_file u_regfile (
        .clk(clk),
        .we(RegWrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(reg_write_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // ALU
    wire [63:0] alu_in_b = (ALUSrc_B) ? imm14_sext : read_data2;
    alu u_alu (
        .A(read_data1),
        .B(alu_in_b),
        .ALU_Op(ALU_Op),
        .Result(alu_result),
        .Zero(alu_zero)
    );

    // Vector Register File and ALU
    wire [2047:0] vector_read_data1, vector_read_data2, vector_read_data_vd;
    wire [2047:0] vector_alu_result;
    wire [2047:0] vector_write_data = VectorMemRead ? {1984'd0, data_read_val} : vector_alu_result;

    vector_register_file u_vrf (
        .clk(clk),
        .we(VectorRegWrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(vector_write_data),
        .read_data1(vector_read_data1),
        .read_data2(vector_read_data2),
        .read_data_vd(vector_read_data_vd)
    );

    vector_alu u_valu (
        .A(vector_read_data1),
        .B(vector_read_data2),
        .C(vector_read_data_vd),
        .VALU_Op(VALU_Op),
        .Result(vector_alu_result)
    );

    wire is_exret = (opcode == 8'h45);
    wire alignment_fault = (data_we_raw || data_re_raw) && (data_addr[2:0] != 3'b000);

    // Memory Interface
    wire data_we_raw = MemWrite || VectorMemWrite;
    wire data_re_raw = MemRead || VectorMemRead;
    
    assign data_addr      = alu_result;
    assign data_write_val = VectorMemWrite ? vector_read_data2[63:0] : read_data2;
    // Prevent memory access if there is an alignment fault
    assign data_we        = data_we_raw && !alignment_fault;
    assign data_re        = data_re_raw && !alignment_fault;

    // CSR Registers
    reg [63:0] csr_trap_handler;
    reg [63:0] csr_epc;
    reg [63:0] csr_trap_cause;

    // Writeback
    always @(*) begin
        case (MemtoReg)
            2'b00: reg_write_data = alu_result;
            2'b01: reg_write_data = data_read_val;
            2'b10: reg_write_data = pc + 4;
            2'b11: begin // CSR Read
                if (csr_addr == 12'h020) reg_write_data = csr_trap_handler;
                else if (csr_addr == 12'h021) reg_write_data = csr_epc;
                else if (csr_addr == 12'h008) reg_write_data = csr_trap_cause;
                else reg_write_data = 64'd0;
            end
        endcase
    end

    // PC Logic
    wire [63:0] next_pc;
    wire take_branch = Branch & alu_zero;
    wire [63:0] branch_offset = { {48{imm14[13]}}, imm14, 2'b00 };
    wire [63:0] jump_offset   = { {43{imm19[18]}}, imm19, 2'b00 };

    wire [63:0] pc_plus_4   = pc + 4;
    wire [63:0] pc_branch   = pc + branch_offset;
    wire [63:0] pc_jump     = pc + jump_offset;

    assign next_pc = alignment_fault ? csr_trap_handler :
                     is_exret        ? csr_epc :
                     Jump            ? pc_jump : 
                     (take_branch    ? pc_branch : pc_plus_4);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 64'd0;
            test_status <= 64'd0;
            csr_trap_handler <= 64'd0;
            csr_epc <= 64'd0;
            csr_trap_cause <= 64'd0;
        end else begin
            pc <= next_pc;

            // Handle Exceptions and CSRs
            if (alignment_fault) begin
                csr_epc <= pc; // Save offending PC
                csr_trap_cause <= 64'd2; // Alignment Fault Cause
            end else if (CSR_Write) begin
                if (csr_addr == 12'h700) test_status <= read_data1;
                else if (csr_addr == 12'h020) csr_trap_handler <= read_data1;
                else if (csr_addr == 12'h021) csr_epc <= read_data1;
                else if (csr_addr == 12'h008) csr_trap_cause <= read_data1;
            end
        end
    end

endmodule
