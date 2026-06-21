module ax_gpio (
    input clk,
    input rst_n,
    input [31:0] addr,
    input [31:0] write_data,
    input we,
    input re,
    output reg [31:0] read_data,
    output reg ready,
    
    // External GPIO Pins
    inout [31:0] gpio_pins
);
    
    reg [31:0] dir_reg;
    reg [31:0] out_reg;
    wire [31:0] in_reg;
    
    // Tristate buffers for GPIO
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_gpio
            assign gpio_pins[i] = dir_reg[i] ? out_reg[i] : 1'bz;
            assign in_reg[i] = gpio_pins[i];
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dir_reg <= 32'd0;
            out_reg <= 32'd0;
            read_data <= 32'd0;
            ready <= 1'b0;
        end else begin
            ready <= 1'b0;
            if (we) begin
                if (addr[7:0] == 8'h00) dir_reg <= write_data;
                else if (addr[7:0] == 8'h04) out_reg <= write_data;
                ready <= 1'b1;
            end else if (re) begin
                if (addr[7:0] == 8'h00) read_data <= dir_reg;
                else if (addr[7:0] == 8'h04) read_data <= out_reg;
                else if (addr[7:0] == 8'h08) read_data <= in_reg;
                else read_data <= 32'd0;
                ready <= 1'b1;
            end
        end
    end
endmodule
