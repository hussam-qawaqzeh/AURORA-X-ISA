module hazard_unit (
    input [4:0] rs1_D,
    input [4:0] rs2_D,
    input [4:0] rd_E,
    input MemRead_E,
    input Branch_Taken,
    
    output reg Stall,
    output reg Flush
);
    always @(*) begin
        Stall = 0;
        Flush = 0;
        
        // Load-Use Hazard Detection
        if (MemRead_E && ((rd_E == rs1_D) || (rd_E == rs2_D))) begin
            Stall = 1;
        end
        
        // Control Hazard Detection
        if (Branch_Taken) begin
            Flush = 1;
        end
    end
endmodule
