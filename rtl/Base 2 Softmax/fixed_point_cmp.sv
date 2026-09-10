module fixed_point_cmp #(
    parameter int FRAC_WIDTH = 23,
    parameter int INTEGER_WIDTH = 5,
    localparam int NUM_WIDTH = FRAC_WIDTH + INTEGER_WIDTH
)(
    input logic signed [NUM_WIDTH:0] a,
    input logic signed [NUM_WIDTH:0] b,
    output logic signed [NUM_WIDTH:0] bigger
);

assign bigger = (a > b) ? a : b;

endmodule