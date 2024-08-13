module LFSR (
    input logic clk,
    input logic reset,
    output logic [9:0] lfsr_out
);
    logic feedback;

    assign feedback = lfsr_out[0];

    always_ff @(posedge clk) begin
        if (reset) begin
            lfsr_out <= 10'b0000000001; 
        end else begin
            lfsr_out[9:1] <= lfsr_out[8:0];
            lfsr_out[0] <= ~(lfsr_out[9] ^ lfsr_out[6]);
        end
    end
endmodule