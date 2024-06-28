module data_collector (
    input  logic clk,
    input  logic rstn,
    input  logic start,

    input  logic unsigned [28:0] data_in,
    input  logic unsigned [28:0] data_ref,

    output logic unsigned [63:0] data_out,
    output logic       data_valid
);

//////////////////////////////////////////////////////////////// signals & param

// parameter
parameter SEQ_LEN = 131072;

// intermediate signals
logic unsigned [29:0] data_sub;
logic unsigned [60:0] data_mul;

// counter
logic [31:0] data_idx;
logic accu_proc; // accumulation process

// generated output
logic unsigned [77:0] data_out_gen;


logic unsigned [29:0] data_in_unsigned;
logic unsigned [29:0] data_ref_unsigned;
//////////////////////////////////////////////////////////////// logic


assign data_in_unsigned  = {1'b0,data_in};
assign data_ref_unsigned = {1'b0,data_ref};


// calculate data_sub
always @(posedge clk) begin
    if (~rstn) begin
        data_sub <= 0;
    end
    else begin
        data_sub <= data_ref_unsigned - data_in_unsigned;
    end
end 

// calculate data_mul
always @(posedge clk) begin
    if (~rstn) begin
        data_mul <= 0;
    end
    else begin
        data_mul <= data_sub * data_sub;
    end
end

// counter & accu_proc
always @(posedge clk) begin
    if (~rstn) begin
        data_idx  <= 0;
        accu_proc <= 0;
    end
    else begin
        if (data_idx == SEQ_LEN+1) begin
            data_idx  <= 0;
        end
        else if (start || accu_proc) begin
            data_idx  <= data_idx + 1;
        end

        if (start) begin
            accu_proc <= 1;
        end
        else if (data_idx == SEQ_LEN) begin
            accu_proc <= 0;
        end
    end
end

// generate data_out
always @(posedge clk) begin
    if (~rstn) begin
        data_out_gen <= 0;
        data_out     <= 0;
        data_valid   <= 0;
    end
    else begin
        if (accu_proc) begin
            data_out_gen <= data_out_gen + data_mul;
        end
        else begin
            data_out_gen <= 0;
        end

        if (data_idx == SEQ_LEN+1) begin
            data_out   <= data_out_gen[77:14];
            data_valid <= 1;
        end
        else begin
            data_out   <= 0;
            data_valid <= 0;
        end
    end
end

endmodule
