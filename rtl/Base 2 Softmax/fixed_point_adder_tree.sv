module fixed_point_adder_tree #(
    parameter int NUM_WIDTH = 23, // unsigned Q1.(NUM_WIDTH-1)
    parameter int INP_NUM = 8,
    localparam int LEVELS = $clog2(INP_NUM),
    localparam int RES_WIDTH = LEVELS + NUM_WIDTH + 1
)(
    input logic [NUM_WIDTH-1:0] inp [INP_NUM],
    output logic [RES_WIDTH-1:0] out 
);

logic [RES_WIDTH-1:0] tree [0:LEVELS][0:INP_NUM -1];

int i, level;

always_comb begin
    
    for (i = 0; i < INP_NUM; i++) begin
        tree[0][i] = {{(LEVELS){1'b0}}, inp[i]};
    end

    for (level = 0; level < LEVELS; level++) begin
        for (i = 0; i < (INP_NUM >> (level + 1)); i++) begin
            tree[level+1][i] = tree[level][2*i] + tree[level][2*i+1];
        end
    end
end

assign out = tree[LEVELS][0];

endmodule
