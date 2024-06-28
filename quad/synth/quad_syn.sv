// simple DSP module that computes the sum of the squares of two inputs
 
module quad (
    input  logic clk,
    input  logic rstn,
    input  logic [12-1:0] a,//2+12
    input  logic [12-1:0] b,//2+12
    output logic [29-1:0] c //5+24
);
parameter FWL_A = 2 ;
parameter FWL_B = 12 ;
parameter FWL_C = 5 ;

logic [12-1:0] a_wl;
logic [12-1:0] b_wl;
logic [29-1:0] c_wl;

assign a_wl = {a[12-1:FWL_A], (FWL_A){1'b0}};
assign b_wl = {b[12-1:FWL_B], (FWL_B){1'b0}};

logic [2*14-1:0] a_sq;
logic [2*14-1:0] b_sq;

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
        c_wl <= 0;
    end else begin
        c_wl <= a_sq + b_sq;
    end
end

assign c = {c_wl[29-1:FWL_C], (FWL_C){1'b0}};

endmodule
