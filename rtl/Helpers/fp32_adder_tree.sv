module fp32_adder_tree #(
    parameter int INP_NUM = 32
)(
    input logic [31:0] inp [INP_NUM],
    output logic [31:0] out
);

localparam int LEVELS = $clog2(INP_NUM);

logic [31:0] tree [0:LEVELS][0:INP_NUM -1];

genvar level, i;

generate 
    for (i = 0; i < INP_NUM; i++) begin
        assign tree[0][i] = inp[i];
    end

    for (level = 0; level < LEVELS; level++) begin
        for (i = 0; i < (INP_NUM >> (level + 1)); i++) begin
            fp32_adder my_fp32_adder(
                .a(tree[level][2*i]),
                .b(tree[level][2*i+1]),
                .result(tree[level+1][i])
            );
        end
    end
endgenerate

assign out = tree[LEVELS][0];

endmodule