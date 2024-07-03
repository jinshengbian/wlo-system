module top (
    input logic clk,
    input logic rstn,
    //uart
    input  logic uart_rx,
    output logic uart_tx
);

//////////////////////////////////////////////////////////////// signals & param

// parameter
parameter NUM_CHAN = 30;
parameter INPUT_WL = 16;
parameter OUTPUT_WL = 16;

// system
logic soft_rstn;
logic sys_rstn;
logic sys_rst;

// uart
logic com_rxvalid, com_txvalid;
logic [7:0] com_rxdata, com_txdata;

// control signals
logic [7:0] sw_int [NUM_CHAN-1:0];
logic [7:0] sw_frac[NUM_CHAN-1:0];
logic [7:0] sw_frac_ref[NUM_CHAN-1:0];
logic start;

// data 
logic [63:0] urn64;
logic [INPUT_WL-1:0]  input_data; //rng
logic [OUTPUT_WL-1:0] output_data;
logic [OUTPUT_WL-1:0] output_ref;

// mse result
logic [63:0] mse_data;
logic mse_valid;

//////////////////////////////////////////////////////////////// connections
//ila_0 ila (
//.clk(clk),
//.probe0(output_data),
//.probe1(output_ref),
//.probe2(input_data),
//.probe3(sw_frac[1])
//);
//ila_0 ila (
//.clk(clk),
//.probe0(mse_data)
//);

assign sys_rstn = soft_rstn & rstn;
assign sys_rst  = ~sys_rstn;

//random number generator
ung64 rng_ins (
    .clk(clk),
    .rstn(sys_rstn),
    .ce(1'b1),
    .data_out(urn64),
    .valid_out(valid_out)
);
assign input_data = {2'b00,urn64[INPUT_WL-3:0]};


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

control_unit #(NUM_CHAN) control_unit_inst (
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

FIR dut_sys (
    .clk(clk),
    .rst(sys_rst),
    .frac_wl(sw_frac),
    .data_in(input_data),
    .in_valid(1'b1),
    .data_out(output_data),
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


data_collector data_collector_inst (
    .clk(clk),
    .rstn(sys_rstn),
    .start(start),
    .data_in(output_data),
    .data_ref(output_ref),
    .data_out(mse_data),
    .data_valid(mse_valid)
);




endmodule



