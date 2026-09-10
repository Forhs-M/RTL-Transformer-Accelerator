module fixed_point_decomp_2 #(
    parameter int FRAC_WIDTH = 23,
    parameter int INTEGER_WIDTH = 6,
    localparam int NUM_WIDTH = FRAC_WIDTH + INTEGER_WIDTH 
)(
    input logic signed [NUM_WIDTH:0] inp,
    output logic signed [INTEGER_WIDTH+1:0] neg_int,
    output logic [FRAC_WIDTH-1:0] pos_frac 
);

logic has_frac;

logic signed [NUM_WIDTH+1:0] floored;
 
logic signed [NUM_WIDTH+1:0] pos_frac_extnd;

assign floored = {inp[NUM_WIDTH], inp[NUM_WIDTH:FRAC_WIDTH], {(FRAC_WIDTH){1'b0}}};

assign has_frac = |(inp[FRAC_WIDTH-1:0]);

assign pos_frac_extnd = {inp[NUM_WIDTH], inp} - floored;

always_comb begin 
    if(has_frac == 1'b1) begin
        neg_int = floored [NUM_WIDTH+1:FRAC_WIDTH];
        pos_frac = pos_frac_extnd[FRAC_WIDTH-1:0];
    end
    else begin
        neg_int = {inp[NUM_WIDTH], inp[NUM_WIDTH:FRAC_WIDTH]};
        pos_frac = {(FRAC_WIDTH){1'b0}};
    end
end

endmodule

