module obstacle(
    input logic CLOCK_50,
    input logic reset,
    input logic [1:0] gameState,
    input logic frame_start,
    input logic [9:0] spawnX,
    input logic [8:0] spawnY,
    input logic [3:0] speed,
    input logic direction,
    input logic active,
    output logic [9:0] x,
    output logic [8:0] y
);
    localparam SCREEN_WIDTH = 640;
    localparam OBSTACLE_WIDTH = 16;
    localparam TOTAL_WIDTH = SCREEN_WIDTH + OBSTACLE_WIDTH;
    logic [31:0] time_since_spawn;
	            logic [10:0] obstacle_pos; // Increased to 11 bits

    always_ff @(posedge CLOCK_50) begin
        if (reset) begin
            x <= spawnX;
            y <= spawnY;
            time_since_spawn <= 0;
        end else if (gameState == 2'b01 && frame_start && active) begin
            time_since_spawn <= time_since_spawn + 1;
            
 
            if (direction == 0) begin // Moving left
                obstacle_pos = (spawnX + TOTAL_WIDTH - (time_since_spawn * speed)) % TOTAL_WIDTH;
            end else begin // Moving right
                obstacle_pos = (spawnX + (time_since_spawn * speed)) % TOTAL_WIDTH;
            end

            // Smooth wrapping
            if (obstacle_pos >= SCREEN_WIDTH) begin
                x <= obstacle_pos - TOTAL_WIDTH;
            end else begin
                x <= obstacle_pos;
            end
        end
    end
endmodule