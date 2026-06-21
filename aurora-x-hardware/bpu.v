`timescale 1ns/1ps

module bpu #(
    parameter BTB_ENTRIES = 64,
    parameter INDEX_BITS = 6
) (
    input clk,
    input rst_n,
    
    // Prediction Interface (IF Stage)
    input [63:0] pc,
    output predicted_taken,
    output [63:0] predicted_target,
    
    // Update Interface (EX Stage)
    input update_en,
    input [63:0] update_pc,
    input update_taken,
    input [63:0] update_target,
    input update_is_branch
);

    // Branch Target Buffer (BTB) & Branch History Table (BHT) arrays
    reg [63:0] btb_target [0:BTB_ENTRIES-1];
    reg [63-INDEX_BITS-2:0] btb_tag [0:BTB_ENTRIES-1];
    reg btb_valid [0:BTB_ENTRIES-1];
    reg [1:0] bht_counter [0:BTB_ENTRIES-1];
    
    // Fetch Stage Lookup
    wire [INDEX_BITS-1:0] fetch_index = pc[INDEX_BITS+1:2];
    wire [63-INDEX_BITS-2:0] fetch_tag = pc[63:INDEX_BITS+2];
    
    wire btb_hit = btb_valid[fetch_index] && (btb_tag[fetch_index] == fetch_tag);
    wire bht_taken = (bht_counter[fetch_index][1] == 1'b1); // Taken if counter is 10 or 11
    
    // Prediction Output
    // If it's a hit, and BHT says taken, we predict taken.
    // If it's a jump, BHT might not matter, but we'll treat all as branches for BHT, 
    // or we just rely on BHT for unconditional jumps as well (they'll quickly become Strongly Taken).
    assign predicted_taken = btb_hit && bht_taken;
    assign predicted_target = btb_target[fetch_index];

    // Execute Stage Update
    wire [INDEX_BITS-1:0] update_index = update_pc[INDEX_BITS+1:2];
    wire [63-INDEX_BITS-2:0] update_tag = update_pc[63:INDEX_BITS+2];
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < BTB_ENTRIES; i = i + 1) begin
                btb_valid[i] <= 0;
                bht_counter[i] <= 2'b01; // Default to Weakly Not Taken
                btb_tag[i] <= 0;
                btb_target[i] <= 0;
            end
        end else if (update_en) begin
            // Update BTB
            btb_valid[update_index] <= 1'b1;
            btb_tag[update_index] <= update_tag;
            btb_target[update_index] <= update_target;
            
            // Update BHT (2-bit saturating counter)
            if (update_taken) begin
                if (bht_counter[update_index] != 2'b11)
                    bht_counter[update_index] <= bht_counter[update_index] + 1;
            end else begin
                if (bht_counter[update_index] != 2'b00)
                    bht_counter[update_index] <= bht_counter[update_index] - 1;
            end
        end
    end

endmodule
