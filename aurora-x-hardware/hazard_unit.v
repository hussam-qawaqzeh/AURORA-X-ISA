module hazard_unit (
    input [4:0] rs1_D,
    input [4:0] rs2_D,
    input [4:0] rd_E,
    input MemRead_E,
    input Branch_Taken,
    input cache_stall,
    input thread_id_D,
    input thread_id_E,
    
    output reg Stall_IF_ID,
    output reg Stall_Pipeline,
    output reg Flush
);
    always @(*) begin
        Stall_IF_ID = 0;
        Stall_Pipeline = 0;
        Flush = 0;
        
        // Cache Stall (Global Freeze)
        if (cache_stall) begin
            Stall_Pipeline = 1;
        end else begin
            // Load-Use Hazard Detection
            if (thread_id_D == thread_id_E && MemRead_E && (rd_E != 0) && ((rd_E == rs1_D) || (rd_E == rs2_D))) begin
                Stall_IF_ID = 1;
            end
            
            // Control Hazard Detection
            // Prioritize Flush over Stall_IF_ID
            if (Branch_Taken) begin
                Flush = 1;
                Stall_IF_ID = 0; // Overrides load-use stall
            end
        end
    end
endmodule
