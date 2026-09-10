// Inputs will be in QINT_WIDTH.FRAC_WIDTH format (Texas Instrument's notation)

module fixed_point_base_2_softmax #(
    parameter int FRAC_WIDTH = 23,
    parameter int INTEGER_WIDTH = 5,
    parameter int INP_NUM = 8,
    parameter int LUT_ENTRIES_NUM = 32,
    localparam int NUM_WIDTH = FRAC_WIDTH + INTEGER_WIDTH 
)(
    input logic signed [NUM_WIDTH:0] inp [INP_NUM],
    output logic [FRAC_WIDTH:0] out [INP_NUM] 
);

logic signed [NUM_WIDTH:0] largest;

logic signed [NUM_WIDTH+1:0] inp_minus_largest [INP_NUM];

genvar j;
logic signed [INTEGER_WIDTH+2:0] neg_int_1 [INP_NUM];
logic [FRAC_WIDTH-1:0] pos_frac_1 [INP_NUM];
logic [FRAC_WIDTH-1:0] lut_res_1 [INP_NUM];
logic [FRAC_WIDTH:0] lut_res_1_shifted [INP_NUM]; // unsinged Q1.FRAC_WIDTH because lut_res_1 is in [1,2) 

localparam LEVELS = $clog2(INP_NUM);
localparam SUM_WIDTH = LEVELS + FRAC_WIDTH + 2;
logic [SUM_WIDTH-1:0] sum; // unsinged QLEVELS.FRAC_WIDTH

logic [LEVELS+1:0] l;
logic [FRAC_WIDTH:0] r;

logic [FRAC_WIDTH-1:0] log_2_r;

logic [SUM_WIDTH-1:0] log_2_R;

logic signed [NUM_WIDTH+1:0] inp_minus_largest_minus_log_2_R [INP_NUM];

logic signed [INTEGER_WIDTH+2:0] neg_int_2 [INP_NUM];
logic [FRAC_WIDTH-1:0] pos_frac_2 [INP_NUM];
logic [FRAC_WIDTH-1:0] lut_res_2 [INP_NUM];

fixed_point_largest_finder #(
    .FRAC_WIDTH(FRAC_WIDTH),
    .INTEGER_WIDTH(INTEGER_WIDTH),
    .INP_NUM(INP_NUM)
) my_fixed_point_largest_finder (
    .inp(inp),
    .largest(largest)
);

int o;

always_comb begin
    for (o = 0; o < INP_NUM; o++) begin
        inp_minus_largest[o] = {inp[o][NUM_WIDTH], inp[o]} - {largest[NUM_WIDTH], largest};
    end
end

generate 
    for (j = 0; j < INP_NUM; j++) begin
        fixed_point_decomp_2 #(
            .FRAC_WIDTH(FRAC_WIDTH),
            .INTEGER_WIDTH(INTEGER_WIDTH+1)
        ) first_decomp (
            .inp(inp_minus_largest[j]),
            .neg_int(neg_int_1[j]),
            .pos_frac(pos_frac_1[j])
        );
    end

    for (j = 0; j < INP_NUM; j++) begin
        fixed_point_lut #(
            .FRAC_WIDTH(FRAC_WIDTH),
            .LUT_ENTRIES_NUM(LUT_ENTRIES_NUM)
        ) first_lut_set (
            .inp(pos_frac_1[j]),
            .mode(1'b1),
            .out(lut_res_1[j])
        );
    end
endgenerate

int p;

always_comb begin 
    for (p = 0; p < INP_NUM; p++) begin
        lut_res_1_shifted[p] = {1'b1, lut_res_1[p]} >> (-neg_int_1[p]);
    end
end

// R calculation

fixed_point_adder_tree #(
    .NUM_WIDTH(FRAC_WIDTH+1),
    .INP_NUM(INP_NUM)
) R_calculation (
    .inp(lut_res_1_shifted),
    .out(sum)
); 

// R decomposition to l and r where R = r * 2^l and r ε [1,2)

fixed_point_l_and_r #(
    .FRAC_WIDTH(FRAC_WIDTH),
    .INTEGER_WIDTH(LEVELS+2)
) R_decomp (
    .inp(sum),
    .l(l),
    .r(r)
);

fixed_point_lut #(
    .FRAC_WIDTH(FRAC_WIDTH),
    .LUT_ENTRIES_NUM(LUT_ENTRIES_NUM)
) log_2_r_calc (
    .inp(r[FRAC_WIDTH-1:0]),
    .mode(1'b0),
    .out(log_2_r)
);

assign log_2_R = {l, log_2_r};

int k;

always_comb begin
    for (k = 0; k < INP_NUM; k++) begin
        inp_minus_largest_minus_log_2_R[k] = {inp_minus_largest[k][NUM_WIDTH], inp_minus_largest[k]} - {{(NUM_WIDTH+1-$bits(log_2_R)){1'b0}}, log_2_R};
    end
end

generate 
    for (j = 0; j < INP_NUM; j++) begin
        fixed_point_decomp_2 #(
            .FRAC_WIDTH(FRAC_WIDTH),
            .INTEGER_WIDTH(INTEGER_WIDTH +1)
        ) second_decomp (
            .inp(inp_minus_largest_minus_log_2_R[j]),
            .neg_int(neg_int_2[j]),
            .pos_frac(pos_frac_2[j])
        );
    end

    for (j = 0; j < INP_NUM; j++) begin
        fixed_point_lut #(
            .FRAC_WIDTH(FRAC_WIDTH),
            .LUT_ENTRIES_NUM(LUT_ENTRIES_NUM)
        ) second_lut_set (
            .inp(pos_frac_2[j]),
            .mode(1'b1),
            .out(lut_res_2[j])
        );
    end
endgenerate

int q;

always_comb begin 
    for (q = 0; q < INP_NUM; q++) begin
        out[q] = {1'b1, lut_res_2[q]} >> (-neg_int_2[q]);
    end
end

endmodule