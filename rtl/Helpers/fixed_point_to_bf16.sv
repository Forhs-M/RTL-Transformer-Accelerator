module fixed_point_to_bf16 #(
    parameter int INT_WIDTH = 8,
    parameter int FRAC_WIDTH = 23, // >= 7 Because of bf16 mantissa
    localparam int NUM_WIDTH = INT_WIDTH + FRAC_WIDTH
)(
    input logic [NUM_WIDTH:0] inp, // inp ε [0,1] because it is softmax result
    output logic [15:0] out 
);

localparam logic [15:0] POS_ONE = 16'h3F80;
localparam logic [15:0] POS_ZERO = 16'h0000; 

integer i;

logic [FRAC_WIDTH-1:0] tmp;
logic [7:0] abs_unbiased_e;
logic [7:0] exp;
logic [FRAC_WIDTH-1:0] mant;

logic [6:0] bf16_mant;
logic guard_bit;
logic sticky_bit;
logic round_up;
logic [7:0] rounded_mant;

always_comb begin
    tmp = inp[FRAC_WIDTH-1:0];
    mant = '0;
    exp ='0;
    abs_unbiased_e = '0;

    bf16_mant = '0;
    guard_bit = 1'b0;
    sticky_bit = 1'b0;
    round_up = 1'b0;
    rounded_mant = '0;

    if (inp[FRAC_WIDTH] == 1'b1) begin
        out = POS_ONE;
    end
    else if (inp == '0) begin
        out = POS_ZERO;
    end
    else begin
        for (i = FRAC_WIDTH-1; i >= 0; i--) begin
            if (tmp[i] == 1'b1) begin
                abs_unbiased_e = (FRAC_WIDTH - i); 
                break;
            end
        end

        mant = tmp << abs_unbiased_e;

        exp = 8'h7F - abs_unbiased_e;

        bf16_mant = mant[FRAC_WIDTH-1:FRAC_WIDTH-7];


        // Following lines are only for FRAC_WIDTH = 8
        guard_bit = mant[FRAC_WIDTH-8];
        sticky_bit = 0;

        // For FRAC_WIDTH > 8 uncomment following commented lines
        // guard_bit = mant[FRAC_WIDTH-8];
        // sticky_bit = |mant[FRAC_WIDTH-9:0];

        round_up = guard_bit && (sticky_bit || bf16_mant[0]);

        rounded_mant = {1'b0, bf16_mant} + round_up;

        if (rounded_mant[7] == 1'b1) begin
            out = {1'b0, exp + 1'b1, 7'b0};
        end
        else begin
            out = {1'b0, exp, rounded_mant[6:0]};
        end
    end
end

endmodule
