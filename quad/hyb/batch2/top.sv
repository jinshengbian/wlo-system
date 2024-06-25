module top (
    input logic clk,
    input logic rstn,
    //uart
    input  logic uart_rx,
    output logic uart_tx
);

//////////////////////////////////////////////////////////////// signals & param

// parameter
parameter NUM_CHAN = 3;

// system
logic soft_rstn;
logic sys_rstn;

// uart
logic com_rxvalid, com_txvalid;
logic [7:0] com_rxdata, com_txdata;

// control signals
logic [7:0] sw_int [1:0][NUM_CHAN-1:0];
logic [7:0] sw_frac[1:0][NUM_CHAN-1:0];
logic start;

// data 
logic [63:0] urn64;
logic [13:0] input_data    [NUM_CHAN-2:0]; //rng
logic [28:0] output_data [1:0];
logic [28:0] output_ref [1:0];
logic [13:0] input_dsp     [1:0][NUM_CHAN-2:0];
logic [28:0] output_dsp[1:0];

// mse result
logic [63:0] mse_data[1:0];
logic mse_valid[1:0];
logic mse_valid_out;

//////////////////////////////////////////////////////////////// connections
 ila_0 ila (
 .clk(clk),


 .probe0(uart_rx),
 .probe1(uart_tx)
 );
assign sys_rstn = soft_rstn & rstn;
assign mse_valid_out = mse_valid[0] | mse_valid[1];
//random number generator
ung64 rng_inst (
    .clk(clk),
    .rstn(sys_rstn),
    .ce(1'b1),
    .data_out(urn64),
    .valid_out(valid_out)
);
assign input_data[0] = urn64[13:0];
assign input_data[1] = urn64[27:14];



uart_transmitter uart_transmitter_inst (
    .clk(clk),
    .rstn(rstn),
    .uart_tx(uart_tx),
    .com_valid(com_txvalid),
    .com_tdata(com_txdata)
);

uart_receiver uart_receiver_inst (
    .clk(clk),
    .rstn(rstn),
    .uart_rx(uart_rx),
    .com_valid(com_rxvalid),
    .com_rdata(com_rxdata)
);

control_unit #(3) control_unit_inst (
    .clk(clk),
    .rstn(rstn),
    .com_rxvalid(com_rxvalid),
    .com_rxdata(com_rxdata),
    .com_txvalid(com_txvalid),
    .com_txdata(com_txdata),
    .sw_int(sw_int),
    .sw_frac(sw_frac),
    .mse_data(mse_data),
    .mse_valid(mse_valid_out),
    .start(start),
    .soft_rstn(soft_rstn)
);


// dsp design
quad dsp_ref0 (
    .clk(clk),
    .rstn(sys_rstn),
    .a(input_data[0]), 
    .b(input_data[1]),
    .c(output_ref[0])
);
quad dsp_sys0 (
    .clk(clk),
    .rstn(sys_rstn),
    .a(input_dsp[0][0]),
    .b(input_dsp[0][1]),
    .c(output_dsp[0])
);

quad dsp_ref1 (
    .clk(clk),
    .rstn(sys_rstn),
    .a(input_data[0]), 
    .b(input_data[1]),
    .c(output_ref[1])
);
quad dsp_sys1 (
    .clk(clk),
    .rstn(sys_rstn),
    .a(input_dsp[1][0]),
    .b(input_dsp[1][1]),
    .c(output_dsp[1])
);
// data_collector

data_collector data_collector_0 (
    .clk(clk),
    .rstn(sys_rstn),
    .start(start),
    .data_in(output_data[0]),
    .data_ref(output_ref[0]),
    .data_out(mse_data[0]),
    .data_valid(mse_valid[0])
);
data_collector data_collector_1 (
    .clk(clk),
    .rstn(sys_rstn),
    .start(start),
    .data_in(output_data[1]),
    .data_ref(output_ref[1]),
    .data_out(mse_data[1]),
    .data_valid(mse_valid[1])
);


//sw 0
bit_switch #(14,12) sw00 (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd2),
    .num_frac(sw_frac[0][0]),
    .data_i(input_data[0]),
    .data_o(input_dsp[0][0])
);

bit_switch #(14,12) sw01 (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd2),
    .num_frac(sw_frac[0][1]),
    .data_i(input_data[1]),
    .data_o(input_dsp[0][1])
);

bit_switch #(29,24) sw02 (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd5),
    .num_frac(sw_frac[0][2]),
    .data_i(output_dsp[0]),
    .data_o(output_data[0])
);
//sw 1
bit_switch #(14,12) sw10 (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd2),
    .num_frac(sw_frac[1][0]),
    .data_i(input_data[0]),
    .data_o(input_dsp[1][0])
);

bit_switch #(14,12) sw11 (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd2),
    .num_frac(sw_frac[1][1]),
    .data_i(input_data[1]),
    .data_o(input_dsp[1][1])
);

bit_switch #(29,24) sw12 (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd5),
    .num_frac(sw_frac[1][2]),
    .data_i(output_dsp[1]),
    .data_o(output_data[1])
);


endmodule



