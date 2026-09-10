// For inpout R : outputs l and r where: R = r * 2^l, r ε [1,2)
module fixed_point_l_and_r #(
    parameter int FRAC_WIDTH = 23,
    parameter int INTEGER_WIDTH = 3,
    localparam int NUM_WIDTH = INTEGER_WIDTH + FRAC_WIDTH
)(
    input logic [NUM_WIDTH-1:0] inp,
    output logic [INTEGER_WIDTH-1:0] l,
    output logic [FRAC_WIDTH:0] r
);

integer i;

logic [NUM_WIDTH-1:0] shifted;

always_comb begin 
    l = '0;

    for (i = NUM_WIDTH-1; i >= FRAC_WIDTH; i--) begin
        if (inp[i] == 1'b1) begin
            l = INTEGER_WIDTH'(i - FRAC_WIDTH);
            break;
        end
    end
end

assign shifted = inp >> l;

assign r = shifted[FRAC_WIDTH:0]; 

endmodule