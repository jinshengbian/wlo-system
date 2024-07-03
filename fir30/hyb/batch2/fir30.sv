module FIR #(
    parameter COE_INTE_WL   = 4,
    parameter COE_FRAC_WL   = 12,
    parameter IN_INTE_WL    = 4,
    parameter IN_FRAC_WL    = 12,
    parameter OUT_INTE_WL   = 4,
    parameter OUT_FRAC_WL   = 12,

    parameter int PRODUCT_FRAC_WL_ARRAY [0:29]  = '{24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24}
)
(
    input  logic clk,
    input  logic rst,
    // wordlength
    input logic [7:0] frac_wl [29:0],

    input  logic signed [IN_INTE_WL-1:-IN_FRAC_WL] data_in,
    input  logic in_valid,
    output logic signed [OUT_INTE_WL-1:-OUT_FRAC_WL] data_out,
    output logic out_valid
);

localparam int PRODUCT_INTE_WL = COE_INTE_WL+IN_INTE_WL;
localparam int PRODUCT_FRAC_WL = COE_FRAC_WL+IN_FRAC_WL;

localparam int n_taps = 30;
localparam signed [COE_INTE_WL-1:-COE_FRAC_WL] coe_fir [0:n_taps-1] = '{
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.00697112627832066)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.00214668252633400)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0106403714218162)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.00755755721797582)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.0135201851863616)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.0166510553347940)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0139465908132496)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0303126648160083)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.00939568594075770)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.0503785836275237)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.00512079904257882)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0837585301586807)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0474504764792547)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.179131234205905)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.413038901956024)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.413038901956024)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.179131234205905)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0474504764792547)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0837585301586807)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.00512079904257882)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.0503785836275237)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.00939568594075770)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0303126648160083)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0139465908132496)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.0166510553347940)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.0135201851863616)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.00755755721797582)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *-0.0106403714218162)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.00214668252633400)),
    (COE_INTE_WL+COE_FRAC_WL)'(int'(2**(COE_FRAC_WL) *0.00697112627832066))
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
    //     if (PRODUCT_FRAC_WL>PRODUCT_FRAC_WL_ARRAY[i]) begin
    //         assign product_new[i] = {product[i][PRODUCT_INTE_WL-1:-(PRODUCT_FRAC_WL_ARRAY[i])],(PRODUCT_FRAC_WL-PRODUCT_FRAC_WL_ARRAY[i])'(0)};
    //     end
    //     else begin
    //         assign product_new[i] = product[i];
    //     end
        bit_switch #(32,24) sw (
            .num_int(8'd8),
            .num_frac(frac_wl[i]),
            .data_i(product[i]),
            .data_o(product_new[i])
        );
    end
    
endgenerate

assign data_out = sum_reg[0][OUT_INTE_WL-1:-OUT_FRAC_WL];
assign out_valid = valid_reg[n_taps-1];

endmodule