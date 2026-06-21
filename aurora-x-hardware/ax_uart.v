module ax_uart #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 115200
)(
    input clk,
    input rst_n,
    
    // Bus Interface
    input [63:0] addr,
    input [63:0] write_data,
    input we,
    input re,
    output reg [63:0] read_data,
    output reg ready,
    
    // External Pins
    input rx,
    output tx
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // Register Offsets
    localparam TX_DATA = 64'h00;
    localparam RX_DATA = 64'h04;
    localparam STATUS  = 64'h08;

    // TX State Machine
    reg [2:0] tx_state;
    localparam TX_IDLE  = 3'd0;
    localparam TX_START = 3'd1;
    localparam TX_DATA_BITS = 3'd2;
    localparam TX_STOP  = 3'd3;
    
    reg [31:0] tx_clk_count;
    reg [2:0]  tx_bit_index;
    reg [7:0]  tx_shift_reg;
    reg tx_reg;
    assign tx = tx_reg;
    
    wire tx_ready = (tx_state == TX_IDLE);
    
    // RX State Machine
    reg [2:0] rx_state;
    localparam RX_IDLE  = 3'd0;
    localparam RX_START = 3'd1;
    localparam RX_DATA_BITS = 3'd2;
    localparam RX_STOP  = 3'd3;
    
    reg [31:0] rx_clk_count;
    reg [2:0]  rx_bit_index;
    reg [7:0]  rx_shift_reg;
    reg [7:0]  rx_data_reg;
    reg        rx_valid;
    
    // TX Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_clk_count <= 0;
            tx_bit_index <= 0;
            tx_shift_reg <= 0;
            tx_reg <= 1'b1; // Idle high
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_reg <= 1'b1;
                    tx_clk_count <= 0;
                    tx_bit_index <= 0;
                    // Trigger TX on memory write to TX_DATA
                    if (we && addr == TX_DATA) begin
                        tx_shift_reg <= write_data[7:0];
                        tx_state <= TX_START;
                    end
                end
                TX_START: begin
                    tx_reg <= 1'b0; // Start bit is low
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 0;
                        tx_state <= TX_DATA_BITS;
                    end
                end
                TX_DATA_BITS: begin
                    tx_reg <= tx_shift_reg[tx_bit_index];
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 0;
                        if (tx_bit_index < 7) begin
                            tx_bit_index <= tx_bit_index + 1;
                        end else begin
                            tx_state <= TX_STOP;
                        end
                    end
                end
                TX_STOP: begin
                    tx_reg <= 1'b1; // Stop bit is high
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 0;
                        tx_state <= TX_IDLE;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end
    
    // RX Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_clk_count <= 0;
            rx_bit_index <= 0;
            rx_shift_reg <= 0;
            rx_data_reg <= 0;
            rx_valid <= 0;
        end else begin
            // Clear valid on read
            if (re && addr == RX_DATA) begin
                rx_valid <= 1'b0;
            end
            
            case (rx_state)
                RX_IDLE: begin
                    rx_clk_count <= 0;
                    rx_bit_index <= 0;
                    if (rx == 1'b0) begin // Start bit detected
                        rx_state <= RX_START;
                    end
                end
                RX_START: begin
                    if (rx_clk_count < (CLKS_PER_BIT / 2) - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        if (rx == 1'b0) begin
                            rx_clk_count <= 0;
                            rx_state <= RX_DATA_BITS;
                        end else begin
                            rx_state <= RX_IDLE; // False start
                        end
                    end
                end
                RX_DATA_BITS: begin
                    if (rx_clk_count < CLKS_PER_BIT - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_clk_count <= 0;
                        rx_shift_reg[rx_bit_index] <= rx;
                        if (rx_bit_index < 7) begin
                            rx_bit_index <= rx_bit_index + 1;
                        end else begin
                            rx_state <= RX_STOP;
                        end
                    end
                end
                RX_STOP: begin
                    if (rx_clk_count < CLKS_PER_BIT - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_clk_count <= 0;
                        rx_state <= RX_IDLE;
                        rx_data_reg <= rx_shift_reg;
                        rx_valid <= 1'b1;
                    end
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end
    
    // Memory Mapped Reads
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data <= 64'd0;
            ready <= 1'b0;
        end else begin
            ready <= 1'b0;
            if (we || re) begin
                ready <= 1'b1; // Respond in 1 cycle
            end
            
            if (re) begin
                case (addr)
                    RX_DATA: read_data <= {56'd0, rx_data_reg};
                    STATUS:  read_data <= {62'd0, rx_valid, tx_ready};
                    default: read_data <= 64'd0;
                endcase
            end
        end
    end

endmodule
