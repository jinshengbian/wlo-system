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
logic [7:0] sw_int [NUM_CHAN-1:0];
logic [7:0] sw_frac[NUM_CHAN-1:0];
logic start;

// data 
logic [63:0] urn64;
logic [13:0] input_data    [NUM_CHAN-2:0]; //rng
logic [28:0] output_data;
logic [28:0] output_ref;
logic [13:0] input_dsp     [NUM_CHAN-2:0];
logic [28:0] output_dsp;

// mse result
logic [63:0] mse_data;
logic mse_valid;

//////////////////////////////////////////////////////////////// connections
// ila_0 ila (
// .clk(clk),
//.probe0(mse_data),
//.probe1(mse_valid)

//  .probe0(input_data[0]),
//  .probe1(input_data[1]),
//  .probe2(input_dsp[0]),
//  .probe3(input_dsp[1]),
//  .probe4(output_ref),
//  .probe5(output_dsp),
//  .probe6(output_data)
// );
assign sys_rstn = soft_rstn & rstn;

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
    .mse_valid(mse_valid),
    .start(start),
    .soft_rstn(soft_rstn)
);

quad dsp_ref (
    .clk(clk),
    .rstn(sys_rstn),
    .a(input_data[0]), 
    .b(input_data[1]),
    .c(output_ref)
);

quad dsp_sys (
    .clk(clk),
    .rstn(sys_rstn),
    .a(input_dsp[0]),
    .b(input_dsp[1]),
    .c(output_dsp)
);

data_collector data_collector_inst (
    .clk(clk),
    .rstn(sys_rstn),
    .start(start),
    .data_in(output_data),
    .data_ref(output_ref),
    .data_out(mse_data),
    .data_valid(mse_valid)
);



bit_switch #(14,12) sw1 (
    .num_int(8'd2),
    .num_frac(sw_frac[0]),
    .data_i(input_data[0]),
    .data_o(input_dsp[0])
);

bit_switch #(14,12) sw2 (
    .num_int(8'd2),
    .num_frac(sw_frac[1]),
    .data_i(input_data[1]),
    .data_o(input_dsp[1])
);

bit_switch #(29,24) sw3 (
    .num_int(8'd5),
    .num_frac(sw_frac[2]),
    .data_i(output_dsp),
    .data_o(output_data)
);



endmodule



