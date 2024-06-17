// simple DSP module that computes the sum of the squares of two inputs
 
module quad (
    input  logic clk,
    input  logic rstn,
    input  logic [11:0] a,
    input  logic [11:0] b,
    output logic [21:0] c
);
 
logic [23:0] a_sq;
logic [23:0] b_sq;

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
