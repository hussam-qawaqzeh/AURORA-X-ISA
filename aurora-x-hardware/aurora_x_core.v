module aurora_x_core (
    input clk,
    input rst_n,
    output reg [63:0] pc,
    input  [31:0] inst,
    output [63:0] data_addr,
    output [63:0] data_write_val,
    input  [63:0] data_read_val,
    output data_we,
    output data_re,
    output [63:0] test_status
);

    // Pipeline Registers
    // IF/ID
    reg [63:0] IF_ID_pc;
    reg [31:0] IF_ID_inst;

    // ID/EX
    reg [63:0] ID_EX_pc;
    reg [63:0] ID_EX_read_data1;
    reg [63:0] ID_EX_read_data2;
    reg [63:0] ID_EX_imm14_sext;
    reg [63:0] ID_EX_imm19_sext;
    reg [4:0]  ID_EX_rs1;
    reg [4:0]  ID_EX_rs2;
    reg [4:0]  ID_EX_rd;
    reg [11:0] ID_EX_csr_addr;
    
    // Control signals
    reg ID_EX_RegWrite, ID_EX_ALUSrc_B, ID_EX_MemRead, ID_EX_MemWrite;
    reg ID_EX_Branch, ID_EX_Jump, ID_EX_CSR_Write, ID_EX_CSR_Read;
    reg [2:0] ID_EX_ALU_Op;
    reg [1:0] ID_EX_MemtoReg;

    // EX/MEM
    reg [63:0] EX_MEM_alu_result;
    reg [63:0] EX_MEM_write_data;
    reg [4:0]  EX_MEM_rd;
    reg EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite;
    reg [1:0] EX_MEM_MemtoReg;

    // MEM/WB
    reg [63:0] MEM_WB_alu_result;
    reg [63:0] MEM_WB_read_data;
    reg [4:0]  MEM_WB_rd;
    reg MEM_WB_RegWrite;
    reg [1:0] MEM_WB_MemtoReg;

    // ------------------------------------------------------------------------
    // STAGE 1: INSTRUCTION FETCH (IF)
    // ------------------------------------------------------------------------
    wire Stall;
    wire Flush;
    wire [63:0] pc_plus_4 = pc + 4;
    wire [63:0] pc_next;
    
    wire Branch_Taken_EX;
    wire [63:0] Branch_Target_EX;

    assign pc_next = Branch_Taken_EX ? Branch_Target_EX : pc_plus_4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 0;
            IF_ID_pc <= 0;
            IF_ID_inst <= 32'd0;
        end else begin
            if (!Stall) begin
                pc <= pc_next;
                IF_ID_pc <= pc;
                IF_ID_inst <= inst;
            end
            if (Flush) begin
                IF_ID_inst <= 32'd0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 2: INSTRUCTION DECODE (ID)
    // ------------------------------------------------------------------------
    wire [4:0] rs1, rs2, rd;
    wire [13:0] imm14;
    wire [18:0] imm19;
    wire [11:0] csr_addr;
    wire [8:0] funct9;
    
    wire RegWrite_D, ALUSrc_B_D, MemRead_D, MemWrite_D, Branch_D, Jump_D, CSR_Write_D, CSR_Read_D;
    wire [2:0] ALU_Op_D;
    wire [1:0] MemtoReg_D;
    
    decoder u_dec (
        .inst(IF_ID_inst),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm14(imm14),
        .imm19(imm19),
        .csr_addr(csr_addr),
        .funct9(funct9),
        .RegWrite(RegWrite_D),
        .ALUSrc_B(ALUSrc_B_D),
        .MemRead(MemRead_D),
        .MemWrite(MemWrite_D),
        .Branch(Branch_D),
        .Jump(Jump_D),
        .CSR_Write(CSR_Write_D),
        .CSR_Read(CSR_Read_D),
        .MemtoReg(MemtoReg_D),
        .ALU_Op(ALU_Op_D)
    );

    wire [63:0] read_data1_D, read_data2_D;
    wire [63:0] write_data_W;

    register_file u_rf (
        .clk(clk),
        .we(MEM_WB_RegWrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(MEM_WB_rd),
        .write_data(write_data_W),
        .read_data1(read_data1_D),
        .read_data2(read_data2_D)
    );

    wire [63:0] imm14_sext_D = {{50{imm14[13]}}, imm14};
    wire [63:0] imm19_sext_D = {{45{imm19[18]}}, imm19};

    hazard_unit u_hu (
        .rs1_D(rs1),
        .rs2_D(rs2),
        .rd_E(ID_EX_rd),
        .MemRead_E(ID_EX_MemRead),
        .Branch_Taken(Branch_Taken_EX),
        .Stall(Stall),
        .Flush(Flush)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ID_EX_RegWrite <= 0; ID_EX_MemRead <= 0; ID_EX_MemWrite <= 0; ID_EX_Branch <= 0; ID_EX_Jump <= 0;
            ID_EX_CSR_Write <= 0; ID_EX_CSR_Read <= 0;
        end else begin
            if (Stall || Flush) begin
                ID_EX_RegWrite <= 0; ID_EX_MemRead <= 0; ID_EX_MemWrite <= 0; ID_EX_Branch <= 0; ID_EX_Jump <= 0;
                ID_EX_CSR_Write <= 0; ID_EX_CSR_Read <= 0;
            end else begin
                ID_EX_pc <= IF_ID_pc;
                ID_EX_read_data1 <= read_data1_D;
                ID_EX_read_data2 <= read_data2_D;
                ID_EX_imm14_sext <= imm14_sext_D;
                ID_EX_imm19_sext <= imm19_sext_D;
                ID_EX_rs1 <= rs1;
                ID_EX_rs2 <= rs2;
                ID_EX_rd <= rd;
                ID_EX_csr_addr <= csr_addr;
                ID_EX_RegWrite <= RegWrite_D;
                ID_EX_ALUSrc_B <= ALUSrc_B_D;
                ID_EX_MemRead <= MemRead_D;
                ID_EX_MemWrite <= MemWrite_D;
                ID_EX_Branch <= Branch_D;
                ID_EX_Jump <= Jump_D;
                ID_EX_ALU_Op <= ALU_Op_D;
                ID_EX_MemtoReg <= MemtoReg_D;
                ID_EX_CSR_Write <= CSR_Write_D;
            end
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 3: EXECUTION (EX)
    // ------------------------------------------------------------------------
    wire [1:0] ForwardA, ForwardB;
    wire [63:0] alu_in1 = (ForwardA == 2'b10) ? EX_MEM_alu_result :
                          (ForwardA == 2'b01) ? write_data_W :
                          ID_EX_read_data1;
    
    wire [63:0] forwarded_read_data2 = (ForwardB == 2'b10) ? EX_MEM_alu_result :
                                       (ForwardB == 2'b01) ? write_data_W :
                                       ID_EX_read_data2;

    wire [63:0] alu_in2 = ID_EX_ALUSrc_B ? ID_EX_imm14_sext : forwarded_read_data2;
    wire [63:0] alu_result_E;
    wire alu_zero_E;

    alu u_alu (
        .A(alu_in1),
        .B(alu_in2),
        .ALU_Op(ID_EX_ALU_Op),
        .Result(alu_result_E),
        .Zero(alu_zero_E)
    );

    forwarding_unit u_fu (
        .rs1_E(ID_EX_rs1),
        .rs2_E(ID_EX_rs2),
        .rd_M(EX_MEM_rd),
        .RegWrite_M(EX_MEM_RegWrite),
        .rd_W(MEM_WB_rd),
        .RegWrite_W(MEM_WB_RegWrite),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB)
    );

    assign Branch_Taken_EX = (ID_EX_Branch && alu_zero_E) || ID_EX_Jump;
    assign Branch_Target_EX = ID_EX_Jump ? (ID_EX_pc + (ID_EX_imm19_sext << 2)) : (ID_EX_pc + (ID_EX_imm14_sext << 2));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            EX_MEM_RegWrite <= 0; EX_MEM_MemRead <= 0; EX_MEM_MemWrite <= 0;
        end else begin
            EX_MEM_alu_result <= alu_result_E;
            EX_MEM_write_data <= forwarded_read_data2;
            EX_MEM_rd <= ID_EX_rd;
            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_MemRead <= ID_EX_MemRead;
            EX_MEM_MemWrite <= ID_EX_MemWrite;
            EX_MEM_MemtoReg <= ID_EX_MemtoReg;
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 4: MEMORY (MEM)
    // ------------------------------------------------------------------------
    assign data_addr = EX_MEM_alu_result;
    assign data_write_val = EX_MEM_write_data;
    assign data_we = EX_MEM_MemWrite;
    assign data_re = EX_MEM_MemRead;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MEM_WB_RegWrite <= 0;
        end else begin
            MEM_WB_alu_result <= EX_MEM_alu_result;
            MEM_WB_read_data <= data_read_val;
            MEM_WB_rd <= EX_MEM_rd;
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_MemtoReg <= EX_MEM_MemtoReg;
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 5: WRITE BACK (WB)
    // ------------------------------------------------------------------------
    assign write_data_W = (MEM_WB_MemtoReg == 2'b01) ? MEM_WB_read_data : MEM_WB_alu_result;

    // Test Status Logic
    reg [63:0] test_status_reg = 0;
    always @(posedge clk) begin
        if (ID_EX_CSR_Write && ID_EX_csr_addr == 12'h700)
            test_status_reg <= alu_in1;
    end
    assign test_status = test_status_reg;
    
    // Exports for Testbench
    wire tb_CSR_Write = ID_EX_CSR_Write;
    wire [11:0] tb_csr_addr = ID_EX_csr_addr;
    wire [63:0] tb_read_data1 = alu_in1;

endmodule
