`timescale 1ns/1ps

module mmu #(
    parameter TLB_ENTRIES = 32
) (
    input clk,
    input rst_n,
    
    // Control
    input satp_en, // 1: Enable MMU Translation, 0: Bypass
    input is_instruction, // 1: Fetch, 0: Data
    input is_write,
    
    // Translation Request
    input [63:0] va,
    output reg [63:0] pa,
    
    // Faults
    output reg tlb_miss,
    output reg page_fault,
    
    // Software TLB Update Interface
    input tlb_update_en,
    input [26:0] tlb_update_vpn,
    input [43:0] tlb_update_ppn,
    input tlb_update_r,
    input tlb_update_w,
    input tlb_update_x
);

    // TLB Storage
    reg [26:0] tlb_vpn [0:TLB_ENTRIES-1];
    reg [43:0] tlb_ppn [0:TLB_ENTRIES-1];
    reg tlb_valid [0:TLB_ENTRIES-1];
    reg tlb_r [0:TLB_ENTRIES-1];
    reg tlb_w [0:TLB_ENTRIES-1];
    reg tlb_x [0:TLB_ENTRIES-1];
    
    // Replacement Policy (Simple Round Robin)
    reg [4:0] replace_idx;

    // Virtual Address Parsing (SV39 style)
    wire [26:0] va_vpn = va[38:12];
    wire [11:0] va_offset = va[11:0];

    // TLB Lookup Logic
    integer i;
    reg hit;
    reg [4:0] hit_idx;
    
    always @(*) begin
        hit = 0;
        hit_idx = 0;
        for (i = 0; i < TLB_ENTRIES; i = i + 1) begin
            if (tlb_valid[i] && (tlb_vpn[i] == va_vpn)) begin
                hit = 1;
                hit_idx = i[4:0];
            end
        end
        
        if (!satp_en) begin
            // Bypass MMU
            pa = va;
            tlb_miss = 0;
            page_fault = 0;
        end else begin
            if (hit) begin
                pa = {8'd0, tlb_ppn[hit_idx], va_offset};
                tlb_miss = 0;
                
                // Permission Check
                page_fault = 0;
                if (is_instruction && !tlb_x[hit_idx]) page_fault = 1;
                if (!is_instruction && !is_write && !tlb_r[hit_idx]) page_fault = 1;
                if (!is_instruction && is_write && !tlb_w[hit_idx]) page_fault = 1;
            end else begin
                // Miss
                pa = 64'd0;
                tlb_miss = 1;
                page_fault = 0;
            end
        end
    end

    // TLB Update Logic (Software Managed via CSRs)
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            replace_idx <= 0;
            for (j = 0; j < TLB_ENTRIES; j = j + 1) begin
                tlb_valid[j] <= 0;
                tlb_vpn[j] <= 0;
                tlb_ppn[j] <= 0;
                tlb_r[j] <= 0;
                tlb_w[j] <= 0;
                tlb_x[j] <= 0;
            end
        end else if (tlb_update_en) begin
            tlb_valid[replace_idx] <= 1;
            tlb_vpn[replace_idx] <= tlb_update_vpn;
            tlb_ppn[replace_idx] <= tlb_update_ppn;
            tlb_r[replace_idx] <= tlb_update_r;
            tlb_w[replace_idx] <= tlb_update_w;
            tlb_x[replace_idx] <= tlb_update_x;
            
            replace_idx <= replace_idx + 1; // Round robin
        end
    end

endmodule
