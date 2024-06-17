// Title  : 64-bit Uniform Number Generator (Skip-ahead LFSR)
// Author : Jinsheng Bian
// Version: 0.1

module ung64 #(
    parameter seed_i = 64'd5030521883283424767
)(
    input  logic clk,
    input  logic rstn,
    input  logic ce,
    //input  logic [51:0] seed_i,
    output logic [63:0] data_out,
    output logic valid_out
);
    parameter URN_WIDTH  = 64;
    parameter SKIP_CYCLE = 11;
    logic [63:0] vector_f; // front-end vector
    logic [63:0] vector_b; // back-end vector
//    logic [63:0] seed_i;
//    assign seed_i = 63'd5030521883283424767;
    // update vector_f 
    always @ (posedge clk) begin
        if (rstn == 0) begin
            vector_f <= seed_i;
        end
        else if (ce) begin
            //if (flush_i == 1) begin
            //    vector_f <= seed_i;
            //end
            //else begin
                vector_f <= vector_b;
            //end
        end 
    end
    // generate vector_b using feedback matrix
    assign vector_b[0] = vector_f[1] + vector_f[53] + vector_f[54] + vector_f[55] + vector_f[59] + vector_f[60] + vector_f[61];
    assign vector_b[1] = vector_f[2] + vector_f[54] + vector_f[55] + vector_f[56] + vector_f[60] + vector_f[61] + vector_f[62];
    assign vector_b[2] = vector_f[3] + vector_f[55] + vector_f[56] + vector_f[57] + vector_f[61] + vector_f[62] + vector_f[63];
    assign vector_b[3] =  vector_f[0] + vector_f[1] + vector_f[3] + vector_f[56] + vector_f[57] + vector_f[58] + vector_f[62] + vector_f[63];
    assign vector_b[4] =  vector_f[0] + vector_f[2] + vector_f[3] + vector_f[57] + vector_f[58] + vector_f[59] + vector_f[63];
    assign vector_b[5] =  vector_f[0] + vector_f[58] + vector_f[59] + vector_f[60];
    assign vector_b[6] =  vector_f[1] + vector_f[59] + vector_f[60] + vector_f[61];
    assign vector_b[7] =  vector_f[2] + vector_f[60] + vector_f[61] + vector_f[62];
    assign vector_b[8] =  vector_f[3] + vector_f[61] + vector_f[62] + vector_f[63];
    assign vector_b[9] = vector_f[0] + vector_f[1] + vector_f[3] + vector_f[62] + vector_f[63];
    assign vector_b[10] =  vector_f[0] + vector_f[2] + vector_f[3] + vector_f[63];


    
    

    generate 
        for (genvar i = 11; i < URN_WIDTH; i ++) begin
            assign vector_b[i] = vector_f[i-SKIP_CYCLE];
        end
    endgenerate
    
    
    
    always @ (posedge clk) begin
    if (!rstn)
        valid_out <= 1'b0;
    else
        valid_out <= ce;
    end
	//assign data_o = vector_b;
	always @ (posedge clk) begin
    if (!rstn)
        data_out <= 64'd0;
    else
        data_out <= vector_b;
        //data_out <= vector_b[15:0]^vector_b[15+16:0+16]^vector_b[15+32:0+32]^vector_b[63:0+48];
    end
endmodule
