// bit switch module
// 2024-03-19

module bit_switch #(
    parameter MAX_LEN = 32, // maximum wordlength
    parameter INT_POS = 16  // position of the integer part （index)

)(
    // control signals
    input  [7:0] num_int, // number of integer bits
    input  [7:0] num_frac, // number of fractional bits
    // data path
    input  logic [MAX_LEN-1:0] data_i,
    output logic [MAX_LEN-1:0] data_o
);

logic [MAX_LEN-INT_POS-1:0] data_int;
logic [INT_POS-1:0]         data_frac;
logic [MAX_LEN-INT_POS-1:0] mask_int  [MAX_LEN-INT_POS-1:0];
logic [INT_POS-1:0]         mask_frac [INT_POS-1:0];

// always @(posedge clk) begin
//     if (~rstn) begin
//         data_o <= 0;
//     end
//     else begin
//         data_o <= {data_int,data_frac};
//     end
// end

// register removed
assign data_o = {data_int,data_frac};

generate
    for (genvar i = 0; i <= MAX_LEN-INT_POS-1; i ++) begin
        assign mask_int[i]  = {(MAX_LEN-INT_POS){1'b1}} >> (MAX_LEN-INT_POS-i);
    end
    for (genvar i = 0; i <= INT_POS-1; i ++) begin
        assign mask_frac[i] = {(INT_POS){1'b1}} << (INT_POS-i);
    end
endgenerate 

always @(*) begin
    if (num_int < (MAX_LEN - INT_POS)) begin
        data_int = data_i[MAX_LEN-1:INT_POS] & mask_int[num_int];
    end
    else begin
        data_int = data_i[MAX_LEN-1:INT_POS];
    end
end
always @(*) begin
     if (num_frac < INT_POS) begin
        data_frac = data_i[INT_POS-1:0] & mask_frac[num_frac];
    end
    else begin
        data_frac = data_i[INT_POS-1:0];
    end
end
endmodule

