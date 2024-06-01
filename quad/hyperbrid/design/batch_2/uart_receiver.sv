module uart_receiver #(
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQ = 50000000
) (
    input  clk,
    input  rstn,
    // serial interface
    input  uart_rx,
    // command interface
    output logic       com_valid,
    output logic [7:0] com_rdata
);

localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;

logic uart_rx_1, uart_rx_2;
logic trans_start;
logic [15:0] uart_clk_cnt;
logic [3:0]  uart_bit_cnt;
logic        uart_proc;
logic [7:0]  com_rdata_reg;

always @(posedge clk) begin
    if (~rstn) begin
        uart_rx_1 <= 1'b1;
        uart_rx_2 <= 1'b1;
    end else begin
        uart_rx_1 <= uart_rx;
        uart_rx_2 <= uart_rx_1;
    end
end

// recieve start
assign trans_start = (uart_rx_2 == 1'b1) && (uart_rx_1 == 1'b0);

// generate uart_proc
always @(posedge clk) begin
    if (~rstn) begin
        uart_proc <= 0;
    end
    else begin
        if (trans_start && uart_proc == 0) begin
            uart_proc <= 1;
        end
        else if (uart_bit_cnt == 9 && uart_clk_cnt == BIT_PERIOD/2) begin
            uart_proc <= 0;
        end
    end
end

// generate uart_clk_cnt
always @(posedge clk) begin
    if (~rstn) begin
        uart_clk_cnt <= 0;
    end
    else begin
        if (uart_proc) begin
            if (uart_clk_cnt < BIT_PERIOD - 1) begin
                uart_clk_cnt <= uart_clk_cnt + 1;
            end
            else begin
                uart_clk_cnt <= 0;
            end
        end
        else begin
            uart_clk_cnt <= 0;
        end
    end
end

// generate uart_bit_cnt
always @(posedge clk) begin
    if (~rstn) begin
        uart_bit_cnt <= 0;
    end
    else begin
        if (uart_proc) begin
            if (uart_clk_cnt == BIT_PERIOD-1 && uart_bit_cnt == 9) begin
                uart_bit_cnt <= 0;
            end
            else if (uart_clk_cnt == BIT_PERIOD-1) begin
                uart_bit_cnt <= uart_bit_cnt + 1;
            end
        end
        else begin
            uart_bit_cnt <= 0;
        end
    end
end

// collect data
always @(posedge clk) begin
    if (~rstn) begin
        com_rdata_reg <= 0;
    end
    else if (uart_proc && uart_clk_cnt == BIT_PERIOD/2 - 1) begin
        case(uart_bit_cnt)
            1: com_rdata_reg[0] <= uart_rx_1;
            2: com_rdata_reg[1] <= uart_rx_1;
            3: com_rdata_reg[2] <= uart_rx_1;
            4: com_rdata_reg[3] <= uart_rx_1;
            5: com_rdata_reg[4] <= uart_rx_1;
            6: com_rdata_reg[5] <= uart_rx_1;
            7: com_rdata_reg[6] <= uart_rx_1;
            8: com_rdata_reg[7] <= uart_rx_1;
        endcase
    end
    else if (trans_start && uart_proc == 0)
        com_rdata_reg <= 0;
end

// generate output
always @(posedge clk) begin
    if (~rstn) begin
        com_valid <= 0;
        com_rdata <= 0;
    end
    else begin
        if (uart_bit_cnt == 9 && uart_clk_cnt == BIT_PERIOD/2) begin
            com_valid <= 1;
            com_rdata <= com_rdata_reg;
        end
        else begin
            com_valid <= 0;
            com_rdata <= 0;
        end
    end
end
endmodule
