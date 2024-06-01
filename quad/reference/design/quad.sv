// simple DSP module that computes the sum of the squares of two inputs
 
module quad #(
    parameter input_wl1 = 14,
    parameter input_wl2 = 14,
    parameter output_wl = 29
    )(
    input  logic clk,
    input  logic rstn,
    input  logic [input_wl1-1:0] a,
    input  logic [input_wl2-1:0] b,
    output logic [output_wl-1:0] c
);
 
logic [2*input_wl1-1:0] a_sq;
logic [2*input_wl2-1:0] b_sq;
 
always @(posedge clk) begin
    if (~rstn) begin
        a_sq <= 0;
        b_sq <= 0;
    end else begin
        a_sq <= a * a;
        b_sq <= b * b;
    end
end
 
always @(posedge clk) begin
    if (~rstn) begin
        c <= 0;
    end else begin
        c <= a_sq + b_sq;
    end
end
 
endmodule
