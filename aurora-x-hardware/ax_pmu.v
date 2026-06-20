module ax_pmu (
    input clk,
    input rst_n,
    
    // Core 0 PMU Interface
    input c0_pmu_req,
    input [63:0] c0_pmu_write_data,
    
    // Core 1 PMU Interface
    input c1_pmu_req,
    input [63:0] c1_pmu_write_data,
    
    // Outputs
    output wire clk_c0,
    output wire clk_c1
);

    reg [63:0] pmu_ctrl;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Default: Both cores enabled, full speed
            // Bit 0: Core 0 Enable (1)
            // Bit 1: Core 1 Enable (1)
            // Bit 3:2: Core 0 Div (00)
            // Bit 5:4: Core 1 Div (00)
            pmu_ctrl <= 64'h0000000000000003; 
        end else begin
            if (c0_pmu_req) begin
                pmu_ctrl <= c0_pmu_write_data;
            end else if (c1_pmu_req) begin
                pmu_ctrl <= c1_pmu_write_data;
            end
        end
    end

    wire c0_en = pmu_ctrl[0];
    wire c1_en = pmu_ctrl[1];
    wire [1:0] c0_div = pmu_ctrl[3:2];
    wire [1:0] c1_div = pmu_ctrl[5:4];

    // Clock divider counters
    reg [2:0] div_counter_c0;
    reg [2:0] div_counter_c1;

    // Use negedge to avoid glitches when driving a posedge clock
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_counter_c0 <= 0;
            div_counter_c1 <= 0;
        end else begin
            div_counter_c0 <= div_counter_c0 + 1;
            div_counter_c1 <= div_counter_c1 + 1;
        end
    end

    reg clk_c0_mux;
    always @(*) begin
        if (!c0_en) clk_c0_mux = 1'b0; // Core Gated
        else begin
            case (c0_div)
                2'b00: clk_c0_mux = clk;
                2'b01: clk_c0_mux = div_counter_c0[0]; // /2
                2'b10: clk_c0_mux = div_counter_c0[1]; // /4
                2'b11: clk_c0_mux = div_counter_c0[2]; // /8
            endcase
        end
    end

    reg clk_c1_mux;
    always @(*) begin
        if (!c1_en) clk_c1_mux = 1'b0; // Core Gated
        else begin
            case (c1_div)
                2'b00: clk_c1_mux = clk;
                2'b01: clk_c1_mux = div_counter_c1[0]; // /2
                2'b10: clk_c1_mux = div_counter_c1[1]; // /4
                2'b11: clk_c1_mux = div_counter_c1[2]; // /8
            endcase
        end
    end

    assign clk_c0 = clk_c0_mux;
    assign clk_c1 = clk_c1_mux;

endmodule
