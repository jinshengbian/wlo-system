`timescale 1ns/1ps
module FIR_tb (
);


localparam COE_INTE_WL   = 4;
localparam COE_FRAC_WL   = 8;
localparam IN_INTE_WL    = 4;
localparam IN_FRAC_WL    = 8;
localparam OUT_INTE_WL   = 4;
localparam OUT_FRAC_WL   = 8;
localparam int PRODUCT_FRAC_WL_ARRAY [0:14] = {16,16,16,16,16,16,16,16,16,16,16,16,16,16,16} ;

logic clk,rst,in_valid,out_valid;
logic signed [IN_INTE_WL-1:-IN_FRAC_WL] data_in;
logic signed [OUT_INTE_WL-1:-OUT_FRAC_WL] data_out;



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

parameter int period = 10;
parameter string data_path = "./simu/";
parameter string in_data = {data_path,"input.txt"};
parameter string out_data = {data_path,"output.txt"};


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
    while (!$feof(input_file)) begin
	    start = 1;
        in_valid = 1;
        $fscanf(input_file, "%d\n", input_data);
        // $display("data:",input_data);
        data_in = 16'(input_data);
        #(period);
    end
    in_valid = 0;
    $fclose(input_file);
    // $finish;
end

initial begin
    output_file=$fopen(out_data,"w");
    $display("No output");
    wait(out_valid == 1);
    $display("Output");
    #(period/2)
    while(out_valid == 1) begin
        
        $fwrite(output_file,"%d\n",data_out);
        #(period);
        
    end
    $fclose(output_file);
    $finish;
	
end

endmodule
