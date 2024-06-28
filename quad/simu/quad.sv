// simple DSP module that computes the sum of the squares of two inputs
 
module quad (
    input  logic clk,
    input  logic rstn,
    input  logic unsigned [14-1:0] a,//2+12
    input  logic unsigned [14-1:0] b,//2+12
    output logic unsigned [29-1:0] c //5+24
);
parameter FWL_A = 5 ;
parameter FWL_B = 5 ;
parameter FWL_C = 5 ;

logic unsigned [14-1:0] a_wl;
logic unsigned [14-1:0] b_wl;
logic unsigned [29-1:0] c_wl;

// assign a_wl = {a[14-1:12-FWL_A], {FWL_A{1'b0}}}; 
// assign b_wl = {b[14-1:12-FWL_B], {FWL_B{1'b0}}}; // Modelsim BUG, so use the following lines

generate
    if (FWL_A == 12) begin
        assign a_wl = a;
    end
    else begin
        assign a_wl[14-1:12-FWL_A] = a[14-1:12-FWL_A];
        assign a_wl[12-FWL_A-1:0]  = 0;
    end
endgenerate
generate
    if (FWL_B == 12) begin
        assign b_wl = b;
    end
    else begin
        assign b_wl[14-1:12-FWL_B] = b[14-1:12-FWL_B];
        assign b_wl[12-FWL_B-1:0]  = 0;
    end
endgenerate



logic [2*14-1:0] a_sq;
logic [2*14-1:0] b_sq;

always @(posedge clk) begin
    if (~rstn) begin
        a_sq <= 0;
        b_sq <= 0;
    end else begin
        a_sq <= a_wl * a_wl;
        b_sq <= b_wl * b_wl;
    end
end

always @(posedge clk) begin
    if (~rstn) begin
        c_wl <= 0;
    end else begin
        c_wl <= a_sq + b_sq;
    end
end

// assign c = {c_wl[29-1:24-FWL_C], {FWL_C{1'b0}}}; // Modelsim BUG, so use the following lines


generate
    if (FWL_C == 24) begin
        assign c = c_wl;
    end
    else begin
        assign c[29-1:24-FWL_C] = c_wl[29-1:24-FWL_C];
        assign c[24-FWL_C-1:0]  = 0;
    end
endgenerate

endmodule