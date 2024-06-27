module top (
    input logic clk,
    input logic rstn,
    //uart
    input  logic uart_rx,
    output logic uart_tx
);

//////////////////////////////////////////////////////////////// signals & param

// parameter
parameter NUM_CHAN = 15;
parameter INPUT_WL = 12;
parameter OUTPUT_WL = 12;

// system
logic soft_rstn;
logic sys_rstn;
logic sys_rst;
// uart
logic com_rxvalid, com_txvalid;
logic [7:0] com_rxdata, com_txdata;

// control signals
logic [7:0] sw_int [1:0][NUM_CHAN-1:0];
logic [7:0] sw_frac[1:0][NUM_CHAN-1:0];
logic [7:0] sw_frac_ref[NUM_CHAN-1:0];
logic start;

// data 
logic [63:0] urn64;
logic [INPUT_WL-1:0] input_data;
logic [INPUT_WL-1:0] output_data [1:0];
logic [INPUT_WL-1:0] output_ref;


// mse result
logic [63:0] mse_data[1:0];
logic mse_valid[1:0];
logic mse_valid_out;

//////////////////////////////////////////////////////////////// connections
//  ila_0 ila (
//  .clk(clk),


//  .probe0(uart_rx),
//  .probe1(uart_tx)
//  );
assign sys_rstn = soft_rstn & rstn;
assign sys_rst  = ~sys_rstn;
assign mse_valid_out = mse_valid[0] | mse_valid[1];
//random number generator
ung64 rng_inst (
    .clk(clk),
    .rstn(sys_rstn),
    .ce(1'b1),
    .data_out(urn64),
    .valid_out(valid_out)
);
assign input_data = urn64[11:0];




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

control_unit #(15) control_unit_inst (
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
FIR dut_sys0 (
    .clk(clk),
    .rst(sys_rst),
    .frac_wl(sw_frac),
    .data_in(input_data),
    .in_valid(1'b1),
    .data_out(output_data[0]),
    .out_valid()
);

FIR dut_sys1 (
    .clk(clk),
    .rst(sys_rst),
    .frac_wl(sw_frac),
    .data_in(input_data),
    .in_valid(1'b1),
    .data_out(output_data[1]),
    .out_valid()
);
assign sw_frac_ref = {8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16};
FIR ref_sys (
    .clk(clk),
    .rst(sys_rst),
    .frac_wl(sw_frac_ref),
    .data_in(input_data),
    .in_valid(1'b1),
    .data_out(output_ref),
    .out_valid()
);

// data_collector

data_collector data_collector_0 (
    .clk(clk),
    .rstn(sys_rstn),
    .start(start),
    .data_in(output_data[0]),
    .data_ref(output_ref),
    .data_out(mse_data[0]),
    .data_valid(mse_valid[0])
);
data_collector data_collector_1 (
    .clk(clk),
    .rstn(sys_rstn),
    .start(start),
    .data_in(output_data[1]),
    .data_ref(output_ref),
    .data_out(mse_data[1]),
    .data_valid(mse_valid[1])
);



endmodule



