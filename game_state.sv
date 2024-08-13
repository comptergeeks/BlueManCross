module game_state(
    input logic clk,
    input logic reset,
    input logic start,
    input logic collision,
    input logic [8:0] player_y,  // New input to check player's y position
    output logic [1:0] state
);
    localparam [1:0] START = 2'b00;
    localparam [1:0] PLAYING = 2'b01;
    localparam [1:0] OVER = 2'b10;
    localparam [1:0] WIN = 2'b11;  // New WIN state

    always_ff @(posedge clk) begin
        if (reset)
            state <= START;
        else if (state == START && start)
            state <= PLAYING;
        else if (state == PLAYING && collision)
            state <= OVER;
        else if (state == PLAYING && player_y <= 9'd10)  // Win condition
            state <= WIN;
        else if (state === 2'bxx)  
            state <= START;
    end
endmodule

module collision_detector #(
    parameter NUM_ROWS = 6,
    parameter OBSTACLES_PER_ROW = 10
)(
    input logic clk,
    input logic reset,
    input logic [9:0] player_x,
    input logic [8:0] player_y,
    input logic [9:0] obstacle_x [NUM_ROWS-1:0][OBSTACLES_PER_ROW-1:0],
    input logic [8:0] obstacle_y [NUM_ROWS-1:0][OBSTACLES_PER_ROW-1:0],
    output logic collision
);
    localparam PLAYER_WIDTH = 16;
    localparam PLAYER_HEIGHT = 16;
    localparam OBSTACLE_WIDTH = 32;
    localparam OBSTACLE_HEIGHT = 32;  
    localparam COLLISION_PADDING = 2;  

    always_ff @(posedge clk) begin
        if (reset) begin
            collision <= 1'b0;
        end else begin
            collision <= 1'b0;
            for (int row = 0; row < NUM_ROWS; row++) begin
                for (int col = 0; col < OBSTACLES_PER_ROW; col++) begin
                    if (player_x + COLLISION_PADDING < obstacle_x[row][col] + OBSTACLE_WIDTH - COLLISION_PADDING &&
                        player_x + PLAYER_WIDTH - COLLISION_PADDING > obstacle_x[row][col] + COLLISION_PADDING &&
                        player_y + COLLISION_PADDING < obstacle_y[row][col] + OBSTACLE_HEIGHT - COLLISION_PADDING &&
                        player_y + PLAYER_HEIGHT - COLLISION_PADDING > obstacle_y[row][col] + COLLISION_PADDING) begin
                        collision <= 1'b1;
                    end
                end
            end
        end
    end
endmodule