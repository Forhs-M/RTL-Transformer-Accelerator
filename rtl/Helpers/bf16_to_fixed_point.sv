module bf16_to_fixed_point #(
    parameter int INT_WIDTH = 8,
    parameter int FRAC_WIDTH = 23, // >= 7 Because of bf16 mantissa
    localparam int NUM_WIDTH = INT_WIDTH + FRAC_WIDTH,
    localparam int EXTRA_BITS = FRAC_WIDTH - 7
)(
    input logic [15:0] inp,
    output logic signed [NUM_WIDTH:0] out
);

localparam logic signed [NUM_WIDTH:0] FIXED_MAX = {1'b0, {(NUM_WIDTH){1'b1}}};

localparam logic signed [NUM_WIDTH:0] FIXED_MIN = {1'b1, {(NUM_WIDTH){1'b0}}};

logic sign;
logic [7:0] exp;
logic [6:0] mantissa;
logic [7:0] sig;

int signed shift;

logic [NUM_WIDTH:0] tmp;
logic [NUM_WIDTH:0] pre_comp_2;
logic overflow;

always_comb begin
    sign = inp[15];
    exp = inp[14:7];
    mantissa = inp[6:0];
    sig = {1'b1, mantissa};

    shift = '0;

    overflow = '0;

    pre_comp_2 = '0;

    out = '0;

    if (EXTRA_BITS == 0) begin
        tmp = {{(INT_WIDTH-1){1'b0}}, sig};
    end
    else begin 
        tmp = {{(INT_WIDTH-1){1'b0}}, sig, {(EXTRA_BITS){1'b0}}};
    end

    if (exp == 8'h00) begin
        out = '0;
    end
    else if (exp == 8'hff) begin
        out = sign ? FIXED_MIN : FIXED_MAX;
    end
    else begin
        shift = int'(exp) - 127;
        
        if (shift < 0) begin
            if ((-shift) >= FRAC_WIDTH + 1) begin
                pre_comp_2 = '0;
            end
            else begin
                pre_comp_2 = tmp >> (-shift);
            end
        end
        else if (shift >= INT_WIDTH) begin
            overflow = 1'b1;
        end
        else begin
            pre_comp_2 = tmp << shift;
        end

        if (sign == 1'b0) begin
            if (overflow == 1'b1) begin
                out = FIXED_MAX;
            end
            else begin
                out = pre_comp_2;
            end
        end
        else begin
            if (overflow == 1'b1) begin
                out = FIXED_MIN;
            end
            else begin
                out = -$signed(pre_comp_2);
            end
        end
    end
end         

endmodule

