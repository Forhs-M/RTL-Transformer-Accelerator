module fixed_point_largest_finder #(
    parameter int FRAC_WIDTH = 23,
    parameter int INTEGER_WIDTH = 5,
    parameter int INP_NUM = 8,
    localparam int NUM_WIDTH = FRAC_WIDTH + INTEGER_WIDTH
)(
    input logic signed [NUM_WIDTH:0] inp [INP_NUM],
    output logic signed [NUM_WIDTH:0] largest 
);

localparam int LEVELS = $clog2(INP_NUM);

logic [NUM_WIDTH:0] tree [0:LEVELS][0:INP_NUM-1];

genvar level, i;

generate 
    for (i = 0; i < INP_NUM; i++) begin
        assign tree[0][i] = inp[i];
    end

    for (level = 0; level < LEVELS; level++) begin
        for (i = 0; i < (INP_NUM >> (level + 1)); i++) begin
            fixed_point_cmp #(
                .FRAC_WIDTH(FRAC_WIDTH),
                .INTEGER_WIDTH(INTEGER_WIDTH)
            ) my_fixed_point_cmp (
                .a(tree[level][2*i]),
                .b(tree[level][2*i+1]),
                .bigger(tree[level+1][i])
            );
        end
    end
endgenerate

assign largest = tree[LEVELS][0];

endmodule