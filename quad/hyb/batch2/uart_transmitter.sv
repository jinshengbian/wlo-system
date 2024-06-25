module uart_transmitter #(
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQ = 50000000
) (
    input  logic clk,
    input  logic rstn,
    // serial interface
    output logic uart_tx,
    // command interface
    input  logic       com_valid,
    input  logic [7:0] com_tdata
);

localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
localparam BUF_LEN    = 16;////////////////////////////////

logic state; // 0: rece, 1: send

logic       com_valid_1;
logic [7:0] com_tdata_1;

logic [7:0] tdata_idx;
logic [7:0] rec_count;

logic [15:0] uart_clk_cnt;
logic [7:0]  uart_bit_cnt;

logic [7:0] tdata_cur;

// buffer
logic [7:0] tdata_buffer [BUF_LEN-1:0];

// receive reg
always @(posedge clk) begin
    if (~rstn) begin
        com_valid_1 <= 1'b0;
        com_tdata_1 <= 8'b0;
    end
    else begin
        com_valid_1 <= com_valid;
        com_tdata_1 <= com_tdata;
    end
end


// generate state
always @(posedge clk) begin
    if (~rstn) begin
        state <= 1'b0;
    end
    else begin
        if (~state) begin
            if ((com_valid_1 && ~com_valid) || (com_valid_1 && tdata_idx == BUF_LEN)) begin
                state <= 1'b1;
            end
        end
        else if (state) begin
            if (uart_clk_cnt == BIT_PERIOD-1 && uart_bit_cnt == 13 && tdata_idx == rec_count-1) begin
                state <= 1'b0;
            end
        end
    end
end

//generate tdata_idx
always @(posedge clk) begin
    if (~rstn) begin
        tdata_idx <= 0;
        tdata_cur <= 0;
    end
    else begin
        if (state) begin
            if (uart_clk_cnt == BIT_PERIOD-1 && uart_bit_cnt == 13 && tdata_idx < rec_count) begin
                tdata_idx <= tdata_idx + 1;
                tdata_cur <= tdata_buffer[tdata_idx + 1];
            end
            else begin
                tdata_cur <= tdata_buffer[tdata_idx];
            end
        end
        else begin
            tdata_idx <= 0;
            tdata_cur <= 0;
        end
    end
end


// receive tdata
always @(posedge clk) begin
    if (~rstn) begin
        for(int i = 0; i < BUF_LEN; i++) begin
            tdata_buffer[i] <= 8'h00;
        end
        rec_count <= 0;
    end
    else begin
        if (~state) begin
            if (com_valid_1 && rec_count < BUF_LEN) begin
                tdata_buffer[rec_count] <= com_tdata_1;
                rec_count <= rec_count + 1;
            end  
        end
        else if (state) begin
            if (tdata_idx == rec_count-1 && uart_clk_cnt == BIT_PERIOD-1 && uart_bit_cnt == 13) begin
                rec_count <= 0;
            end
        end
    end
end

// generate uart_clk_cnt
always @(posedge clk) begin
    if (~rstn) begin
        uart_clk_cnt <= 0;
    end
    else begin
        if (state) begin
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
        if (state) begin
            if (uart_clk_cnt == BIT_PERIOD-1 && uart_bit_cnt == 13) begin
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

// send data
always @(posedge clk) begin
    if (~rstn) begin
        uart_tx <= 1'b1;
    end
    else begin
        if (state) begin
            if (uart_bit_cnt == 0) begin
                uart_tx <= 0;
            end
            else if (uart_bit_cnt >= 9) begin
                uart_tx <= 1;
            end
            else begin
                uart_tx <= tdata_cur[uart_bit_cnt-1];
            end
        end
        else begin
            uart_tx <= 1'b1;
        end
    end
end


endmodule
