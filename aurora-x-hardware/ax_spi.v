module ax_spi (
    input clk,
    input rst_n,
    input [31:0] addr,
    input [31:0] write_data,
    input we,
    input re,
    output reg [31:0] read_data,
    output reg ready,
    
    // SPI Pins
    output reg spi_sck,
    output reg spi_mosi,
    input  wire spi_miso,
    output reg [3:0] spi_cs
);
    
    reg [31:0] ctrl_reg;   // [0] enable, [1] start transfer, [5:2] CS select, [15:8] clock divider
    reg [7:0] tx_data;
    reg [7:0] rx_data;
    reg [31:0] status_reg; // [0] busy
    
    reg [2:0] spi_state;
    reg [2:0] bit_cnt;
    reg [7:0] clk_div_cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg <= 0;
            tx_data <= 0;
            rx_data <= 0;
            status_reg <= 0;
            read_data <= 0;
            ready <= 0;
            spi_sck <= 0;
            spi_mosi <= 0;
            spi_cs <= 4'hF;
            spi_state <= 0;
            bit_cnt <= 0;
            clk_div_cnt <= 0;
        end else begin
            ready <= 1'b0;
            // Bus interface
            if (we && !status_reg[0]) begin
                if (addr[7:0] == 8'h00) ctrl_reg <= write_data;
                else if (addr[7:0] == 8'h04) begin
                    tx_data <= write_data[7:0];
                    if (ctrl_reg[0]) begin
                        status_reg[0] <= 1'b1; // set busy
                        spi_state <= 1; // start SPI state machine
                        bit_cnt <= 7;
                        clk_div_cnt <= ctrl_reg[15:8];
                        spi_cs <= ~(4'b0001 << ctrl_reg[5:2]);
                    end
                end
                ready <= 1'b1;
            end else if (re) begin
                if (addr[7:0] == 8'h00) read_data <= ctrl_reg;
                else if (addr[7:0] == 8'h04) read_data <= {24'd0, rx_data};
                else if (addr[7:0] == 8'h08) read_data <= status_reg;
                ready <= 1'b1;
            end
            
            // SPI State Machine
            if (status_reg[0]) begin
                if (clk_div_cnt == 0) begin
                    clk_div_cnt <= ctrl_reg[15:8];
                    case (spi_state)
                        1: begin // Drive MOSI, SCK Low
                            spi_sck <= 0;
                            spi_mosi <= tx_data[bit_cnt];
                            spi_state <= 2;
                        end
                        2: begin // SCK High, Sample MISO
                            spi_sck <= 1;
                            rx_data[bit_cnt] <= spi_miso;
                            if (bit_cnt == 0) begin
                                spi_state <= 3; // Done
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                                spi_state <= 1;
                            end
                        end
                        3: begin // Cleanup
                            spi_sck <= 0;
                            spi_cs <= 4'hF;
                            status_reg[0] <= 1'b0; // clear busy
                            spi_state <= 0;
                        end
                    endcase
                end else begin
                    clk_div_cnt <= clk_div_cnt - 1;
                end
            end
        end
    end
endmodule
