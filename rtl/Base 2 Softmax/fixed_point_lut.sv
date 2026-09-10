module fixed_point_lut #(
    parameter int FRAC_WIDTH = 23,
    parameter int LUT_ENTRIES_NUM = 32
)(
    input logic [FRAC_WIDTH-1:0] inp,
    input logic mode,
    output logic [FRAC_WIDTH-1:0] out
);

localparam ENC_ENTRIES_NUM = $clog2(LUT_ENTRIES_NUM); 

logic [FRAC_WIDTH-1:0] fixed_point_lut_1 [LUT_ENTRIES_NUM];
logic [FRAC_WIDTH-1:0] fixed_point_lut_2 [LUT_ENTRIES_NUM];

logic [ENC_ENTRIES_NUM-1:0] ra;

`include "fixed_point_lut1_assigns.svh"
`include "fixed_point_lut2_assigns.svh"

function automatic logic [ENC_ENTRIES_NUM-1:0] idx_find (
    input logic [FRAC_WIDTH-1:0] x,
    input logic [FRAC_WIDTH-1:0] nodes [LUT_ENTRIES_NUM]
);

    logic [ENC_ENTRIES_NUM-1:0] idx;
    logic [FRAC_WIDTH:0] diff;
    integer j;
    
    begin
        idx = {(ENC_ENTRIES_NUM){1'b0}};

        for (j = 0; j < LUT_ENTRIES_NUM; j++) begin
            diff = {1'b0, x} - {1'b0, nodes[j]};

            if (diff[FRAC_WIDTH] == 1'b0) begin
                idx = j[ENC_ENTRIES_NUM-1:0];
            end
        end

        idx_find = idx;
    end
endfunction

assign ra = mode ? idx_find(inp, fixed_point_lut_2) : idx_find(inp, fixed_point_lut_1);

always_comb begin 
    if (mode == 1'b1) begin
        out = fixed_point_lut_1[ra];
    end
    else begin 
        out = fixed_point_lut_2[ra];
    end
end

endmodule