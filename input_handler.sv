module input_handler(
    input logic CLOCK_50,
    input logic reset,
    input logic up, down, left, right,
    input logic [1:0] gameState,
    input logic frame_start,
    output logic [9:0] x,
    output logic [8:0] y
);


// could add animation logic
    localparam INITIAL_X = 10'd100;
    localparam INITIAL_Y = 9'd450;
    localparam MOVE_SPEED = 1;
    localparam FRAMES_PER_MOVE = 1;  // needed to link the character movement to the frame rate, this way the movement is smooth and does not move between frames

    logic up_debounced, down_debounced, left_debounced, right_debounced;
    D_FF up_ff (.q(up_debounced), .d(up), .reset(reset), .clk(CLOCK_50));
    D_FF down_ff (.q(down_debounced), .d(down), .reset(reset), .clk(CLOCK_50));
    D_FF left_ff (.q(left_debounced), .d(left), .reset(reset), .clk(CLOCK_50));
    D_FF right_ff (.q(right_debounced), .d(right), .reset(reset), .clk(CLOCK_50));

    logic [2:0] frame_counter;

    always_ff @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            x <= INITIAL_X;
            y <= INITIAL_Y;
            frame_counter <= 3'd0;
        end else if (gameState == 2'b01 && frame_start) begin  
            if (frame_counter == FRAMES_PER_MOVE - 1) begin
                frame_counter <= 3'd0;
                if (up_debounced && !down_debounced && y > MOVE_SPEED) y <= y - MOVE_SPEED;
                if (down_debounced && !up_debounced && y < 9'd479 - MOVE_SPEED) y <= y + MOVE_SPEED;
                if (left_debounced && !right_debounced && x > MOVE_SPEED) x <= x - MOVE_SPEED;
                if (right_debounced && !left_debounced && x < 10'd639 - MOVE_SPEED) x <= x + MOVE_SPEED;
            end else begin
                frame_counter <= frame_counter + 1;
            end
        end
    end
endmodule

	module D_FF (q, d, reset, clk);
		 output logic q;
		 input logic d, reset, clk;
		 
		 always_ff @(posedge clk) begin
			  if (reset) q <= 0; // On reset, set to 0
			  else q <= d; // Otherwise out = d
		 end
	endmodule
