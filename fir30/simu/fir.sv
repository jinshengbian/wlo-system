module FIR #(
    parameter COE_INTE_WL   = 4,
    parameter COE_FRAC_WL   = 8,
    parameter IN_INTE_WL    = 4,
    parameter IN_FRAC_WL    = 8,
    parameter OUT_INTE_WL   = 4,
    parameter OUT_FRAC_WL   = 8,

    parameter int PRODUCT_FRAC_WL_ARRAY [0:14]  = '{16,16,16,16,16,16,16,16,16,16,16,16,16,16,16}
)
(
    input  logic clk,
    input  logic rst,
    input  logic signed [IN_INTE_WL-1:-IN_FRAC_WL] data_in,
    input  logic in_valid,
    output logic signed [OUT_INTE_WL-1:-OUT_FRAC_WL] data_out,
    output logic out_valid
);

localparam int PRODUCT_INTE_WL = COE_INTE_WL+IN_INTE_WL;
localparam int PRODUCT_FRAC_WL = COE_FRAC_WL+IN_FRAC_WL;

localparam int n_taps = 15;
localparam signed [COE_INTE_WL-1:-COE_FRAC_WL] coe_fir [0:n_taps-1] = '{
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.00263119098697776)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * -0.00783030622561309)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * -0.0319539987462920)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * -0.0435309144561433)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.00448942892782332)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.126799787633365)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.266483430011455)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.328711880092251)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.266483430011455)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.126799787633365)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.00448942892782332)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * -0.0435309144561433)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * -0.0319539987462920)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * -0.00783030622561309)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) * 0.00263119098697776))
};

logic signed [PRODUCT_INTE_WL-1:-PRODUCT_FRAC_WL] product [0:n_taps-1];
logic signed [PRODUCT_INTE_WL-1:-PRODUCT_FRAC_WL] product_new [0:n_taps-1];
logic signed [PRODUCT_INTE_WL-1:-PRODUCT_FRAC_WL] sum_reg [0:n_taps-2];
logic [n_taps-1:0] valid_reg;

always @(posedge clk) begin
    if (rst == 1'b1) begin
        for (int i=0; i<n_taps-1; i=i+1) begin
            sum_reg[i] <= (PRODUCT_INTE_WL+PRODUCT_FRAC_WL)'(0);
        end
        valid_reg <= 1'b0;
    end
    else begin
        sum_reg[n_taps-2] <= product_new[n_taps-2]+product_new[n_taps-1];
        for (int i=0; i<n_taps-2; i=i+1) begin
            sum_reg[i] <= product_new[i]+sum_reg[i+1];
        end
        valid_reg[0] <= in_valid;
        for (integer i=1; i<n_taps; i=i+1) begin
            valid_reg[i] <= valid_reg[i-1];
        end
    
    end
end

always @(*) begin
    for (int i=0; i<n_taps; i=i+1) begin
        product[i] <= coe_fir[i] * data_in;
    end
    
end

genvar i;
generate
    for (i=0; i<n_taps; i=i+1) begin
        if (PRODUCT_FRAC_WL>PRODUCT_FRAC_WL_ARRAY[i]) begin
            assign product_new[i] = {product[i][PRODUCT_INTE_WL-1:-(PRODUCT_FRAC_WL_ARRAY[i])],(PRODUCT_FRAC_WL-PRODUCT_FRAC_WL_ARRAY[i])'(0)};
        end
        else begin
            assign product_new[i] = product[i];
        end
    end
endgenerate

assign data_out = sum_reg[0][OUT_INTE_WL-1:-OUT_FRAC_WL];
assign out_valid = valid_reg[n_taps-1];

endmodule