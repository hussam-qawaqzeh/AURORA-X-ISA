module aurora_x_core #(
    parameter CORE_TYPE = 0 // 0: P-Core, 1: E-Core, 2: AI-Core (with Vector SIMT)
)(
    input clk,
    input rst_n,
    output [63:0] pc,
    input  [31:0] inst,
    output [63:0] data_addr,
    output [63:0] data_write_val,
    input  [63:0] data_read_val,
    output data_we,
    output data_re,
    input  data_ready,
    input  [3:0] core_id,
    output [63:0] test_status,
    output pmu_req,
    output [63:0] pmu_write_data,
    
    // Snoop Interface
    input [63:0] snoop_addr,
    input snoop_we
);

    // Pipeline Registers
    // IF/ID
    reg [63:0] IF_ID_pc;
    reg [31:0] IF_ID_inst;
    reg IF_ID_predicted_taken;
    reg [63:0] IF_ID_predicted_target;

    // ID/EX
    reg [63:0] ID_EX_pc;
    reg [63:0] ID_EX_read_data1;
    reg [63:0] ID_EX_read_data2;
    reg [2047:0] ID_EX_vread_data1;
    reg [2047:0] ID_EX_vread_data2;
    reg [2047:0] ID_EX_vread_data_vd;
    reg [63:0] ID_EX_imm14_sext;
    reg [63:0] ID_EX_imm19_sext;
    reg [4:0]  ID_EX_rs1;
    reg [4:0]  ID_EX_rs2;
    reg [4:0]  ID_EX_rd;
    reg [11:0] ID_EX_csr_addr;
    reg ID_EX_predicted_taken;
    reg [63:0] ID_EX_predicted_target;
    
    // Control signals
    reg ID_EX_RegWrite, ID_EX_ALUSrc_B, ID_EX_MemRead, ID_EX_MemWrite;
    reg ID_EX_Branch, ID_EX_Jump, ID_EX_CSR_Write, ID_EX_CSR_Read;
    reg [3:0] ID_EX_ALU_Op;
    reg [1:0] ID_EX_MemtoReg;
    reg [2:0] ID_EX_Branch_Type;
    reg ID_EX_Ecall, ID_EX_Exret;
    reg ID_EX_VectorOp, ID_EX_VectorRegWrite, ID_EX_VectorMemRead, ID_EX_VectorMemWrite;
    reg ID_EX_VectorMaskWe, ID_EX_VectorUseMask;
    reg [2:0] ID_EX_VALU_Op;

    // EX/MEM
    reg [63:0] EX_MEM_pc;
    reg [63:0] EX_MEM_alu_result;
    reg [63:0] EX_MEM_write_data;
    reg [2047:0] EX_MEM_valu_result;
    reg [4:0]  EX_MEM_rd;
    reg [11:0] EX_MEM_csr_addr;
    reg EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite;
    reg [1:0] EX_MEM_MemtoReg;
    reg EX_MEM_CSR_Write, EX_MEM_CSR_Read;
    reg EX_MEM_VectorRegWrite, EX_MEM_VectorMemRead, EX_MEM_VectorMemWrite;
    reg EX_MEM_VectorMaskWe, EX_MEM_VectorUseMask;
    reg [63:0] EX_MEM_Mask_Result;

    // MEM/WB
    reg [63:0] MEM_WB_pc;
    reg [63:0] MEM_WB_alu_result;
    reg [63:0] MEM_WB_read_data;
    reg [2047:0] MEM_WB_valu_result;
    reg [4:0]  MEM_WB_rd;
    reg [11:0] MEM_WB_csr_addr;
    reg MEM_WB_RegWrite;
    reg [1:0] MEM_WB_MemtoReg;
    reg MEM_WB_CSR_Read;
    reg MEM_WB_VectorRegWrite;
    reg MEM_WB_VectorMemRead;
    reg MEM_WB_VectorMaskWe, MEM_WB_VectorUseMask;
    reg [63:0] MEM_WB_Mask_Result;

    // ------------------------------------------------------------------------
    // CSRs (Moved from single_cycle)
    // ------------------------------------------------------------------------
    reg [63:0] csr_trap_handler;
    reg [63:0] csr_epc;
    reg [63:0] csr_trap_cause;
    reg [63:0] test_status_reg;
    reg [63:0] csr_read_data_W;
    
    // MMU CSRs
    reg [63:0] csr_satp;
    reg [26:0] csr_tlb_update_vpn;
    reg [43:0] csr_tlb_update_ppn;
    reg [3:0]  csr_tlb_update_flags;
    reg tlb_update_en_pulse;

    assign test_status = test_status_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_trap_handler <= 0;
            csr_epc <= 0;
            csr_trap_cause <= 0;
            test_status_reg <= 0;
        end else if (EX_MEM_CSR_Write) begin
            case (EX_MEM_csr_addr)
                12'h700: test_status_reg <= EX_MEM_alu_result;
                12'h020: csr_trap_handler <= EX_MEM_alu_result;
                12'h021: csr_epc <= EX_MEM_alu_result;
                12'h008: csr_trap_cause <= EX_MEM_alu_result;
                12'h180: csr_satp <= EX_MEM_alu_result;
                12'h181: csr_tlb_update_vpn <= EX_MEM_alu_result[26:0];
                12'h182: csr_tlb_update_ppn <= EX_MEM_alu_result[43:0];
                12'h183: begin
                    csr_tlb_update_flags <= EX_MEM_alu_result[3:0];
                    if (EX_MEM_alu_result[3]) tlb_update_en_pulse <= 1;
                end
            endcase
        end else if (ID_EX_Ecall) begin
            csr_epc <= ID_EX_pc;
            csr_trap_cause <= 64'd8; // Env call from User mode
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 1: INSTRUCTION FETCH (IF)
    // ------------------------------------------------------------------------
    wire Stall_IF_ID;
    wire Stall_Pipeline;
    wire Flush;
    wire cache_stall;
    
    reg [63:0] virt_pc;
    wire [63:0] physical_pc;
    wire i_tlb_miss, i_page_fault;

    wire [63:0] pc_plus_4 = virt_pc + 4;
    wire [63:0] pc_next;
    
    // BPU Signals
    wire bpu_predicted_taken;
    wire [63:0] bpu_predicted_target;
    
    // BPU Update Signals from EX stage
    wire bpu_update_en;
    wire [63:0] bpu_update_pc;
    wire bpu_update_taken;
    wire [63:0] bpu_update_target;
    wire bpu_update_is_branch;

    generate
        if (CORE_TYPE == 0 || CORE_TYPE == 2) begin : gen_bpu
            bpu u_bpu (
                .clk(clk),
                .rst_n(rst_n),
                .pc(virt_pc),
                .predicted_taken(bpu_predicted_taken),
                .predicted_target(bpu_predicted_target),
                .update_en(bpu_update_en),
                .update_pc(bpu_update_pc),
                .update_taken(bpu_update_taken),
                .update_target(bpu_update_target),
                .update_is_branch(bpu_update_is_branch)
            );
        end else begin : gen_no_bpu
            assign bpu_predicted_taken = 1'b0;
            assign bpu_predicted_target = 64'd0;
        end
    endgenerate

    wire Branch_Mispredict_EX;
    wire [63:0] virt_pc_next;
    wire [63:0] Correct_Target_EX;

    assign virt_pc_next = ID_EX_Ecall ? csr_trap_handler :
                     ID_EX_Exret ? csr_epc :
                     Branch_Mispredict_EX ? Correct_Target_EX : 
                     bpu_predicted_taken ? bpu_predicted_target : pc_plus_4;

    generate
        if (`ENABLE_MMU) begin : gen_i_mmu
            mmu i_mmu (
                .clk(clk),
                .rst_n(rst_n),
                .satp_en(csr_satp[0]),
                .is_instruction(1'b1),
                .is_write(1'b0),
                .va(virt_pc),
                .pa(physical_pc),
                .tlb_miss(i_tlb_miss),
                .page_fault(i_page_fault),
                .tlb_update_en(tlb_update_en_pulse),
                .tlb_update_vpn(csr_tlb_update_vpn),
                .tlb_update_ppn(csr_tlb_update_ppn),
                .tlb_update_r(csr_tlb_update_flags[0]),
                .tlb_update_w(csr_tlb_update_flags[1]),
                .tlb_update_x(csr_tlb_update_flags[2])
            );
        end else begin : gen_no_i_mmu
            assign physical_pc = virt_pc;
            assign i_tlb_miss = 0;
            assign i_page_fault = 0;
        end
    endgenerate

    assign pc = physical_pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tlb_update_en_pulse <= 0;
            virt_pc <= 0;
            IF_ID_pc <= 0;
            IF_ID_inst <= 32'd0;
            IF_ID_predicted_taken <= 0;
            IF_ID_predicted_target <= 0;
        end else if (!Stall_Pipeline) begin
            tlb_update_en_pulse <= 0;
            if (!Stall_IF_ID) begin
                virt_pc <= virt_pc_next;
                IF_ID_pc <= virt_pc;
                IF_ID_inst <= inst;
                IF_ID_predicted_taken <= bpu_predicted_taken;
                IF_ID_predicted_target <= bpu_predicted_target;
            end
            if (Flush) begin
                IF_ID_inst <= 32'd0;
                IF_ID_predicted_taken <= 0;
                IF_ID_predicted_target <= 0;
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
    wire [3:0] ALU_Op_D;
    wire [1:0] MemtoReg_D;
    wire [2:0] Branch_Type_D;
    wire Ecall_D, Exret_D;
    wire VectorOp_D, VectorRegWrite_D, VectorMemRead_D, VectorMemWrite_D;
    wire VectorMaskWe_D, VectorUseMask_D;
    wire [2:0] VALU_Op_D;
    
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
        .Branch_Type(Branch_Type_D),
        .Jump(Jump_D),
        .CSR_Write(CSR_Write_D),
        .CSR_Read(CSR_Read_D),
        .MemtoReg(MemtoReg_D),
        .ALU_Op(ALU_Op_D),
        .Ecall(Ecall_D),
        .Exret(Exret_D),
        .VectorOp(VectorOp_D),
        .VectorRegWrite(VectorRegWrite_D),
        .VectorMemRead(VectorMemRead_D),
        .VectorMemWrite(VectorMemWrite_D),
        .VALU_Op(VALU_Op_D),
        .VectorMaskWe(VectorMaskWe_D),
        .VectorUseMask(VectorUseMask_D)
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

    wire [2047:0] vread_data1_D, vread_data2_D, vread_data_vd_D;
    wire [2047:0] vwrite_data_W;
    
    generate
        if (CORE_TYPE == 2) begin : gen_vrf
            vector_register_file u_vrf (
                .clk(clk),
                .we(MEM_WB_VectorRegWrite),
                .mask_we(MEM_WB_VectorMaskWe),
                .use_mask(MEM_WB_VectorUseMask),
                .rs1(rs1),
                .rs2(rs2),
                .rd_write(MEM_WB_rd),
                .vd_read(rd),
                .write_data(vwrite_data_W),
                .mask_data(MEM_WB_Mask_Result),
                .read_data1(vread_data1_D),
                .read_data2(vread_data2_D),
                .read_data_vd(vread_data_vd_D)
            );
        end else begin : gen_no_vrf
            assign vread_data1_D = 2048'd0;
            assign vread_data2_D = 2048'd0;
            assign vread_data_vd_D = 2048'd0;
        end
    endgenerate

    wire [63:0] imm14_sext_D = {{50{imm14[13]}}, imm14};
    wire [63:0] imm19_sext_D = {{45{imm19[18]}}, imm19};

    hazard_unit u_hu (
        .rs1_D(rs1),
        .rs2_D(rs2),
        .rd_E(ID_EX_rd),
        .MemRead_E(ID_EX_MemRead),
        .Branch_Taken(Branch_Mispredict_EX || ID_EX_Ecall || ID_EX_Exret),
        .cache_stall(cache_stall),
        .Stall_IF_ID(Stall_IF_ID),
        .Stall_Pipeline(Stall_Pipeline),
        .Flush(Flush)
    );

    // EX/MEM Pipeline Register
    always @(posedge clk) begin
        if (!Stall_Pipeline) begin
            if (ID_EX_Branch) begin
                $display("Time=%0t | Core %d | Branch at PC=%x | in1=%d | in2=%d | Taken=%b", $time, core_id, ID_EX_pc, alu_in1, forwarded_read_data2, Branch_Taken_EX);
            end
            if (ID_EX_RegWrite) $display("Time=%0t | Core %d | PC=%x | ALU_Op=%b | in1=%d | in2=%d | res=%d | rd=%d", $time, core_id, ID_EX_pc, ID_EX_ALU_Op, alu_in1, alu_in2, actual_alu_result, ID_EX_rd);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ID_EX_RegWrite <= 0; ID_EX_MemRead <= 0; ID_EX_MemWrite <= 0; ID_EX_Branch <= 0; ID_EX_Jump <= 0;
            ID_EX_CSR_Write <= 0; ID_EX_CSR_Read <= 0; ID_EX_Ecall <= 0; ID_EX_Exret <= 0;
            ID_EX_VectorOp <= 0; ID_EX_VectorRegWrite <= 0; ID_EX_VectorMemRead <= 0; ID_EX_VectorMemWrite <= 0;
        end else if (!Stall_Pipeline) begin
            if (Stall_IF_ID || Flush) begin
                ID_EX_RegWrite <= 0; ID_EX_MemRead <= 0; ID_EX_MemWrite <= 0; ID_EX_Branch <= 0; ID_EX_Jump <= 0;
                ID_EX_CSR_Write <= 0; ID_EX_CSR_Read <= 0; ID_EX_Ecall <= 0; ID_EX_Exret <= 0;
                ID_EX_VectorOp <= 0; ID_EX_VectorRegWrite <= 0; ID_EX_VectorMemRead <= 0; ID_EX_VectorMemWrite <= 0;
                ID_EX_VectorMaskWe <= 0; ID_EX_VectorUseMask <= 0;
                ID_EX_predicted_taken <= 0;
                ID_EX_predicted_target <= 0;
            end else begin
                ID_EX_pc <= IF_ID_pc;
                ID_EX_read_data1 <= read_data1_D;
                ID_EX_read_data2 <= read_data2_D;
                ID_EX_vread_data1 <= vread_data1_D;
                ID_EX_vread_data2 <= vread_data2_D;
                ID_EX_vread_data_vd <= vread_data_vd_D;
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
                ID_EX_CSR_Read <= CSR_Read_D;
                ID_EX_Branch_Type <= Branch_Type_D;
                ID_EX_Ecall <= Ecall_D;
                ID_EX_Exret <= Exret_D;
                ID_EX_VectorOp <= VectorOp_D;
                ID_EX_VectorRegWrite <= VectorRegWrite_D;
                ID_EX_VectorMemRead <= VectorMemRead_D;
                ID_EX_VectorMemWrite <= VectorMemWrite_D;
                ID_EX_VectorMaskWe <= VectorMaskWe_D;
                ID_EX_VectorUseMask <= VectorUseMask_D;
                ID_EX_VALU_Op <= VALU_Op_D;
                ID_EX_predicted_taken <= IF_ID_predicted_taken;
                ID_EX_predicted_target <= IF_ID_predicted_target;
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

    wire [63:0] actual_alu_result;

    alu u_alu (
        .A(alu_in1),
        .B(alu_in2),
        .ALU_Op(ID_EX_ALU_Op),
        .Result(actual_alu_result),
        .Zero(alu_zero_E)
    );

    reg [63:0] csr_read_data_E;
    always @(*) begin
        csr_read_data_E = 64'd0;
        if (ID_EX_CSR_Read) begin
            case (ID_EX_csr_addr)
                12'h700: csr_read_data_E = test_status_reg;
                12'h020: csr_read_data_E = csr_trap_handler;
                12'h021: csr_read_data_E = csr_epc;
                12'h008: csr_read_data_E = csr_trap_cause;
                12'hF14: csr_read_data_E = {60'd0, core_id};
                default: csr_read_data_E = 64'd0;
            endcase
        end
    end

    assign alu_result_E = ID_EX_CSR_Read ? csr_read_data_E : actual_alu_result;

    // Vector ALU
    wire [2047:0] valu_in2 = ID_EX_ALUSrc_B ? {1984'd0, ID_EX_imm14_sext} : ID_EX_vread_data2;
    wire [2047:0] valu_result_E;
    wire [63:0]   valu_mask_result_E;
    generate
        if (CORE_TYPE == 2) begin : gen_valu
            vector_alu u_valu (
                .A(ID_EX_vread_data1),
                .B(valu_in2),
                .C(ID_EX_vread_data_vd),
                .VALU_Op(ID_EX_VALU_Op),
                .Result(valu_result_E),
                .Mask_Result(valu_mask_result_E)
            );
        end else begin : gen_no_valu
            assign valu_result_E = 2048'd0;
            assign valu_mask_result_E = 64'd0;
        end
    endgenerate

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

    reg Branch_Cond_Met;
    always @(*) begin
        case (ID_EX_Branch_Type)
            3'd0: Branch_Cond_Met = (alu_in1 == forwarded_read_data2); // BEQ
            3'd1: Branch_Cond_Met = (alu_in1 != forwarded_read_data2); // BNE
            3'd2: Branch_Cond_Met = ($signed(alu_in1) < $signed(forwarded_read_data2)); // BLT
            3'd3: Branch_Cond_Met = ($signed(alu_in1) >= $signed(forwarded_read_data2)); // BGE
            3'd4: Branch_Cond_Met = (alu_in1 < forwarded_read_data2); // BLTU
            3'd5: Branch_Cond_Met = (alu_in1 >= forwarded_read_data2); // BGEU
            default: Branch_Cond_Met = 0;
        endcase
    end
    wire Branch_Taken_EX;
    wire [63:0] Branch_Target_EX;
    
    assign Branch_Taken_EX = (ID_EX_Branch && Branch_Cond_Met) || ID_EX_Jump;
    assign Branch_Target_EX = ID_EX_Jump ? (ID_EX_pc + (ID_EX_imm19_sext << 2)) : (ID_EX_pc + (ID_EX_imm14_sext << 2));

    // BPU Validation
    assign Branch_Mispredict_EX = (ID_EX_Branch || ID_EX_Jump) && 
        ((ID_EX_predicted_taken != Branch_Taken_EX) || 
         (ID_EX_predicted_taken && (ID_EX_predicted_target != Branch_Target_EX)));
         
    assign Correct_Target_EX = Branch_Taken_EX ? Branch_Target_EX : (ID_EX_pc + 4);

    // BPU Updates
    assign bpu_update_en = (ID_EX_Branch || ID_EX_Jump) && !Stall_Pipeline;
    assign bpu_update_pc = ID_EX_pc;
    assign bpu_update_taken = Branch_Taken_EX;
    assign bpu_update_target = Branch_Target_EX;
    assign bpu_update_is_branch = ID_EX_Branch || ID_EX_Jump;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            EX_MEM_RegWrite <= 0; EX_MEM_MemRead <= 0; EX_MEM_MemWrite <= 0;
            EX_MEM_CSR_Write <= 0; EX_MEM_CSR_Read <= 0;
            EX_MEM_VectorRegWrite <= 0; EX_MEM_VectorMemRead <= 0; EX_MEM_VectorMemWrite <= 0;
            EX_MEM_VectorMaskWe <= 0; EX_MEM_VectorUseMask <= 0;
        end else if (!Stall_Pipeline) begin
            EX_MEM_pc <= ID_EX_pc;
            EX_MEM_alu_result <= alu_result_E;
            EX_MEM_write_data <= forwarded_read_data2;
            EX_MEM_valu_result <= valu_result_E;
            EX_MEM_rd <= ID_EX_rd;
            EX_MEM_csr_addr <= ID_EX_csr_addr;
            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_MemRead <= ID_EX_MemRead;
            EX_MEM_MemWrite <= ID_EX_MemWrite;
            EX_MEM_MemtoReg <= ID_EX_MemtoReg;
            EX_MEM_CSR_Write <= ID_EX_CSR_Write;
            EX_MEM_CSR_Read <= ID_EX_CSR_Read;
            EX_MEM_VectorRegWrite <= ID_EX_VectorRegWrite;
            EX_MEM_VectorMemRead <= ID_EX_VectorMemRead;
            EX_MEM_VectorMemWrite <= ID_EX_VectorMemWrite;
            EX_MEM_VectorMaskWe <= ID_EX_VectorMaskWe;
            EX_MEM_VectorUseMask <= ID_EX_VectorUseMask;
            EX_MEM_Mask_Result <= valu_mask_result_E;
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 4: MEMORY (MEM)
    // ------------------------------------------------------------------------
    wire [63:0] physical_data_addr;
    wire d_tlb_miss, d_page_fault;

    generate
        if (`ENABLE_MMU) begin : gen_d_mmu
            mmu d_mmu (
                .clk(clk),
                .rst_n(rst_n),
                .satp_en(csr_satp[0]),
                .is_instruction(1'b0),
                .is_write(EX_MEM_MemWrite || EX_MEM_VectorMemWrite),
                .va(EX_MEM_alu_result),
                .pa(physical_data_addr),
                .tlb_miss(d_tlb_miss),
                .page_fault(d_page_fault),
                .tlb_update_en(tlb_update_en_pulse),
                .tlb_update_vpn(csr_tlb_update_vpn),
                .tlb_update_ppn(csr_tlb_update_ppn),
                .tlb_update_r(csr_tlb_update_flags[0]),
                .tlb_update_w(csr_tlb_update_flags[1]),
                .tlb_update_x(csr_tlb_update_flags[2])
            );
        end else begin : gen_no_d_mmu
            assign physical_data_addr = EX_MEM_alu_result;
            assign d_tlb_miss = 0;
            assign d_page_fault = 0;
        end
    endgenerate

    wire [63:0] cache_read_data;
    l1_cache u_cache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(physical_data_addr),
        .cpu_write_data(EX_MEM_write_data),
        .cpu_we(EX_MEM_MemWrite || EX_MEM_VectorMemWrite),
        .cpu_re(EX_MEM_MemRead || EX_MEM_VectorMemRead),
        .cpu_read_data(cache_read_data),
        .stall(cache_stall),
        .mem_addr(data_addr),
        .mem_write_data(data_write_val),
        .mem_we(data_we),
        .mem_re(data_re),
        .mem_read_data(data_read_val),
        .mem_ready(data_ready),
        .snoop_addr(snoop_addr),
        .snoop_we(snoop_we)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MEM_WB_RegWrite <= 0;
            MEM_WB_CSR_Read <= 0;
            MEM_WB_VectorRegWrite <= 0;
            MEM_WB_VectorMemRead <= 0;
            MEM_WB_VectorMaskWe <= 0;
        end else if (!Stall_Pipeline) begin
            MEM_WB_pc <= EX_MEM_pc;
            MEM_WB_alu_result <= EX_MEM_alu_result;
            MEM_WB_read_data <= cache_read_data;
            MEM_WB_valu_result <= EX_MEM_valu_result;
            MEM_WB_rd <= EX_MEM_rd;
            MEM_WB_csr_addr <= EX_MEM_csr_addr;
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_MemtoReg <= EX_MEM_MemtoReg;
            MEM_WB_CSR_Read <= EX_MEM_CSR_Read;
            MEM_WB_VectorRegWrite <= EX_MEM_VectorRegWrite;
            MEM_WB_VectorMemRead <= EX_MEM_VectorMemRead;
            MEM_WB_VectorMaskWe <= EX_MEM_VectorMaskWe;
            MEM_WB_VectorUseMask <= EX_MEM_VectorUseMask;
            MEM_WB_Mask_Result <= EX_MEM_Mask_Result;
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 5: WRITE BACK (WB)
    // ------------------------------------------------------------------------
    always @(*) begin
        csr_read_data_W = 64'd0;
        if (MEM_WB_CSR_Read) begin
            case (MEM_WB_csr_addr)
                12'h700: csr_read_data_W = test_status_reg;
                12'h020: csr_read_data_W = csr_trap_handler;
                12'h021: csr_read_data_W = csr_epc;
                12'h008: csr_read_data_W = csr_trap_cause;
                12'hF14: csr_read_data_W = {60'd0, core_id}; // Hardware Thread ID
                default: csr_read_data_W = 64'd0;
            endcase
        end
    end

    assign write_data_W = (MEM_WB_MemtoReg == 2'b01) ? MEM_WB_read_data : 
                          (MEM_WB_MemtoReg == 2'b10) ? (MEM_WB_pc + 4) :
                          (MEM_WB_MemtoReg == 2'b11) ? csr_read_data_W :
                          MEM_WB_alu_result;

    assign vwrite_data_W = MEM_WB_VectorMemRead ? {1984'd0, MEM_WB_read_data} : MEM_WB_valu_result;

    // Exports for Testbench
    wire tb_CSR_Write = EX_MEM_CSR_Write;
    wire [11:0] tb_csr_addr = EX_MEM_csr_addr;
    wire [63:0] tb_read_data1 = EX_MEM_alu_result;

    // PMU Interface
    assign pmu_req = EX_MEM_CSR_Write && (EX_MEM_csr_addr == 12'h800);
    assign pmu_write_data = EX_MEM_alu_result;

endmodule
