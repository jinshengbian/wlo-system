module top (
    input  logic clk,
    input  logic rstn,
    // frac bits
    input  [7:0] num_frac_a,
    input  [7:0] num_frac_b,
    input  [7:0] num_frac_c,
    // data path
    input  logic [13:0] a,
    input  logic [13:0] b,
    output logic [28:0] c
);

parameter MAX_LEN = 14;
parameter INT_POS = 12;
logic [MAX_LEN-1:0] a_dsp;
logic [MAX_LEN-1:0] b_dsp;
logic [MAX_LEN*2:0] c_dsp;


quad quad_inst (
    .clk(clk),
    .rstn(rstn),
    .a(a_dsp),
    .b(b_dsp),
    .c(c_dsp)
);

bit_switch #(
    .MAX_LEN(MAX_LEN),
    .INT_POS(INT_POS)
) bit_switch_a (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd2),
    .num_frac(num_frac_a),
    .data_i(a),
    .data_o(a_dsp)
);
bit_switch #(
    .MAX_LEN(MAX_LEN),
    .INT_POS(INT_POS)
) bit_switch_b (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd2),
    .num_frac(num_frac_b),
    .data_i(b),
    .data_o(b_dsp)
);
bit_switch #(
    .MAX_LEN(MAX_LEN*2+1),
    .INT_POS(INT_POS*2)
) bit_switch_c (
    .clk(clk),
    .rstn(rstn),
    .num_int(8'd5),
    .num_frac(num_frac_c),
    .data_i(c_dsp),
    .data_o(c)
);


endmodule

// module top (
//     input  logic clk,
//     input  logic rstn,
//     // frac bits
//     input  [7:0] num_frac_a,
//     input  [7:0] num_frac_b,
//     input  [7:0] num_frac_c,
//     // data path
//     input  logic [11:0] a,
//     input  logic [11:0] b,
//     output logic [24:0] c
// );


// logic [11:0] a_dsp;
// logic [11:0] b_dsp;
// logic [23:0] c_dsp;


// quad quad_inst (
//     .clk(clk),
//     .rstn(rstn),
//     .a(a),
//     .b(b),
//     .c(c)
// );

// // bit_switch #(
// //     .MAX_LEN(12),
// //     .INT_POS(6)
// // ) bit_switch_a (
// //     .clk(clk),
// //     .rstn(rstn),
// //     .num_int(6),
// //     .num_frac(num_frac_a),
// //     .data_i(a),
// //     .data_o(a_dsp)
// // );
// // bit_switch #(
// //     .MAX_LEN(12),
// //     .INT_POS(6)
// // ) bit_switch_b (
// //     .clk(clk),
// //     .rstn(rstn),
// //     .num_int(6),
// //     .num_frac(num_frac_b),
// //     .data_i(b),
// //     .data_o(b_dsp)
// // );
// // bit_switch #(
// //     .MAX_LEN(25),
// //     .INT_POS(12)
// // ) bit_switch_c (
// //     .clk(clk),
// //     .rstn(rstn),
// //     .num_int(13),
// //     .num_frac(num_frac_c),
// //     .data_i(c_dsp),
// //     .data_o(c)
// // );


// endmodule

