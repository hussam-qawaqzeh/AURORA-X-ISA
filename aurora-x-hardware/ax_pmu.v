`include "aurora_config.vh"

module ax_pmu (
    input clk,
    input rst_n,
    
    // Flat arrays for PMU Interface
    input  [`TOTAL_CORES-1:0] pmu_req,
    input  [(`TOTAL_CORES*64)-1:0] pmu_write_data,
    
    // Output clocks
    output [`TOTAL_CORES-1:0] clk_cores
);

    reg [63:0] pmu_ctrl;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Enable all cores by default, full speed (divider = 0)
            pmu_ctrl <= 64'hFFFFFFFFFFFFFFFF; 
        end else begin
            // Any core can write to the PMU control register
            for (i = 0; i < `TOTAL_CORES; i = i + 1) begin
                if (pmu_req[i]) begin
                    pmu_ctrl <= pmu_write_data[(i*64) +: 64];
                end
            end
        end
    end

    // Clock divider counters
    reg [2:0] div_counter [`TOTAL_CORES-1:0];

    // Use negedge to avoid glitches when driving a posedge clock
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < `TOTAL_CORES; i = i + 1) begin
                div_counter[i] <= 0;
            end
        end else begin
            for (i = 0; i < `TOTAL_CORES; i = i + 1) begin
                div_counter[i] <= div_counter[i] + 1;
            end
        end
    end

    genvar g;
    generate
        for (g = 0; g < `TOTAL_CORES; g = g + 1) begin : clk_gen
            wire core_en = pmu_ctrl[g]; // 1 bit enable per core
            // Use 2 bits per core for divider, starting from bit 32
            wire [1:0] core_div = pmu_ctrl[32 + (g*2) +: 2];

            reg clk_mux;
            always @(*) begin
                if (!core_en) clk_mux = 1'b0; // Core Gated
                else begin
                    case (core_div)
                        2'b00: clk_mux = clk;
                        2'b01: clk_mux = div_counter[g][0]; // /2
                        2'b10: clk_mux = div_counter[g][1]; // /4
                        2'b11: clk_mux = div_counter[g][2]; // /8
                    endcase
                end
            end
            assign clk_cores[g] = clk_mux;
        end
    endgenerate

endmodule
