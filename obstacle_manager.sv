module obstacle_manager
    #(parameter NUM_ROWS = 6, parameter OBSTACLES_PER_ROW = 10)
    (
    input logic CLOCK_50,
    input logic reset,
    input logic [1:0] gameState,
    input logic frame_start,
    output logic [9:0] obstacle_x [NUM_ROWS-1:0][OBSTACLES_PER_ROW-1:0],
    output logic [8:0] obstacle_y [NUM_ROWS-1:0][OBSTACLES_PER_ROW-1:0],
    output logic direction [NUM_ROWS-1:0]
);
    localparam SCREEN_WIDTH = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam OBSTACLE_WIDTH = 32;
    localparam OBSTACLE_HEIGHT = 32;
    localparam TOTAL_WIDTH = SCREEN_WIDTH + OBSTACLE_WIDTH;
    localparam SPRITE_HEIGHT = 16;
    localparam ROAD_HEIGHT = SPRITE_HEIGHT * 2;
    localparam SIDEWALK_HEIGHT = SPRITE_HEIGHT * 2;
    localparam LANE_HEIGHT = ROAD_HEIGHT + SIDEWALK_HEIGHT;
    localparam BOTTOM_SIDEWALK_HEIGHT = LANE_HEIGHT * 2;
    localparam PLAYABLE_HEIGHT = SCREEN_HEIGHT - BOTTOM_SIDEWALK_HEIGHT;
    localparam VERTICAL_OFFSET = 2; 
    
    logic [9:0] spawn_x [NUM_ROWS-1:0][OBSTACLES_PER_ROW-1:0];
    logic [8:0] spawn_y [NUM_ROWS-1:0];
    logic [7:0] speed [NUM_ROWS-1:0];
    logic [9:0] spacing;
    logic [31:0] time_since_start;
    logic is_road_row [NUM_ROWS-1:0];
    
    // LFSR instance
    logic [9:0] lfsr_out;
    LFSR lfsr_inst (
        .clk(CLOCK_50),
        .reset(reset),
        .lfsr_out(lfsr_out)
    );
    
    // Speed limits (fixed-point representation, 4 fractional bits)
    localparam MIN_SPEED = 8'd12;  // 0.75 
    localparam MAX_SPEED = 8'd24; // 1.5 
    localparam SPEED_RANGE = MAX_SPEED - MIN_SPEED;

    // Initialize and update obstacles
    always_ff @(posedge CLOCK_50) begin
        if (reset) begin
            spacing <= TOTAL_WIDTH / OBSTACLES_PER_ROW;
            time_since_start <= 0;
            for (int row = 0; row < NUM_ROWS; row++) begin
                direction[row] <= row[0]; 
                
                // lfsr!! for speed for row
                speed[row] <= (((lfsr_out ^ {6'b0, row[3:0]}) * SPEED_RANGE) >> 6) + MIN_SPEED;
                
                is_road_row[row] <= 1'b1;  
                
                spawn_y[row] <= VERTICAL_OFFSET + (NUM_ROWS - 1 - row) * LANE_HEIGHT + (ROAD_HEIGHT / 2) - (OBSTACLE_HEIGHT / 2);
                
                for (int col = 0; col < OBSTACLES_PER_ROW; col++) begin
                    spawn_x[row][col] <= col * spacing;
                    obstacle_x[row][col] <= direction[row] ? SCREEN_WIDTH : -OBSTACLE_WIDTH;
                    obstacle_y[row][col] <= spawn_y[row];
                end
            end
        end else if (gameState == 2'b01 && frame_start) begin
            time_since_start <= time_since_start + 1;
            for (int row = 0; row < NUM_ROWS; row++) begin
                logic [18:0] lane_offset;
                lane_offset = (time_since_start * speed[row]) >> 4;  // Shift right by 4 to account for fixed-point
                lane_offset = lane_offset % TOTAL_WIDTH;
                for (int col = 0; col < OBSTACLES_PER_ROW; col++) begin
                    logic [18:0] obstacle_pos;
                    if (direction[row] == 0) begin // left --> right 
                        obstacle_pos = (spawn_x[row][col] + lane_offset) % TOTAL_WIDTH;
                    end else begin // right --> left
                        obstacle_pos = (spawn_x[row][col] + TOTAL_WIDTH - lane_offset) % TOTAL_WIDTH;
                    end
                    
                    // Smooth wrapping
                    if (direction[row] == 0) begin // left --> right
                        obstacle_x[row][col] <= (obstacle_pos >= SCREEN_WIDTH) ? obstacle_pos - TOTAL_WIDTH : obstacle_pos[9:0];
                    end else begin // right --> left
                        obstacle_x[row][col] <= (obstacle_pos <= OBSTACLE_WIDTH) ? obstacle_pos + SCREEN_WIDTH : obstacle_pos[9:0];
                    end
                end
            end
        end
    end
endmodule