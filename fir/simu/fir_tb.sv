`timescale 1ns / 1ps

module FIR_tb(
    );

localparam COE_INTE_WL   = 4;
localparam COE_FRAC_WL   = 8;
localparam IN_INTE_WL    = 4;
localparam IN_FRAC_WL    = 8;
localparam OUT_INTE_WL   = 4;
localparam OUT_FRAC_WL   = 8;

localparam int PRODUCT_FRAC_WL_ARRAY [0:14] = {15,6,11,15,10,2,5,2,6,6,14,1,5,2,16} ;

logic clk,rst,in_valid,out_valid;
logic [IN_INTE_WL-1:-IN_FRAC_WL] data_in;
logic [OUT_INTE_WL-1:-OUT_FRAC_WL] data_out;

parameter int period = 10;
parameter string data_path = "./simu/";
parameter string in_data = {data_path,"input.txt"};
parameter string out_data = {data_path,"output.txt"};

FIR #(
    .COE_INTE_WL(COE_INTE_WL),
    .COE_FRAC_WL(COE_FRAC_WL),
    .IN_INTE_WL(IN_INTE_WL),
    .IN_FRAC_WL(IN_FRAC_WL),
    .OUT_INTE_WL(OUT_INTE_WL),
    .OUT_FRAC_WL(OUT_FRAC_WL),
    .PRODUCT_FRAC_WL_ARRAY(PRODUCT_FRAC_WL_ARRAY)
) dut(
    .clk(clk),
    .rst(rst),
    .data_in(data_in),
    .in_valid(in_valid),
    .data_out(data_out),
    .out_valid(out_valid)
);



always #(period/2) clk = ~clk;

int input_file,output_file;
int input_data;
int start;

initial begin
    input_file=$fopen(in_data,"r");
  
    
    start = 0;
    rst = 1;
    clk = 1;
    in_valid = 0;
    #150
    rst = 0;
    start = 1;
    in_valid = 1;
    while (!$feof(input_file)) begin
        #(period)
	    
        $fscanf(input_file, "%d\n", input_data);
        
        data_in = 12'(input_data);
    end
    
    start = 0;
    in_valid = 0;
    $fclose(input_file);
    $finish;
end

initial begin
    output_file=$fopen(out_data,"w");
    $display("not start");
    wait(out_valid == 1);
    $display("start");
    #(period*0.5)
    while(out_valid == 1) begin
        #(period)
        $fwrite(output_file,"%d\n",data_out);
        
    end
    $fclose(output_file);
    $finish;
	
end


endmodule
