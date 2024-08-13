module video_driver
    #(parameter WIDTH = 640, parameter HEIGHT = 480,
      parameter NUM_ROWS = 7, parameter OBSTACLES_PER_ROW = 5)
    (CLOCK_50, reset, x, y, r, g, b, VGA_R, VGA_G, VGA_B, VGA_BLANK_N, VGA_CLK, VGA_HS, VGA_SYNC_N, VGA_VS, start, KEY, SW);
    
    input CLOCK_50;
    input reset;
    output reg [9:0] x;
    output reg [8:0] y;
    input [7:0] r, g, b;
    input start;
    input [3:0] KEY;
    input [9:0] SW;
    output [7:0] VGA_R;
    output [7:0] VGA_G;
    output [7:0] VGA_B;
    output VGA_BLANK_N;
    output VGA_CLK;
    output VGA_HS;
    output VGA_SYNC_N;
    output VGA_VS;
    
    // Internal signals
    logic [1:0] gameState;
    logic [9:0] playerX;
    logic [8:0] playerY;
    logic frame_start;

    localparam integer X_BLOCK = 640 / WIDTH;
    localparam integer Y_BLOCK = 480 / HEIGHT;
    localparam integer BLOCK = X_BLOCK < Y_BLOCK ? X_BLOCK : Y_BLOCK;
    localparam integer X_SPAN = WIDTH * BLOCK;
    localparam integer Y_SPAN = HEIGHT * BLOCK;
    localparam integer X_START = (640 - X_SPAN) / 2;
    localparam integer Y_START = (480 - Y_SPAN) / 2;
    localparam integer X_STOP = X_START + X_SPAN;
    localparam integer Y_STOP = Y_START + Y_SPAN;
    localparam integer BLOCK_STOP = BLOCK - 1;
    
    wire read_enable;
    wire end_of_active_frame;
    wire end_of_frame;
    wire vga_blank;
    wire vga_c_sync;
    wire vga_h_sync;
    wire vga_v_sync;
    wire vga_data_enable;
    
    reg read_enable_last;
    wire CLOCK_25;
    wire locked; // ignore - is PLL locked?
    reg [9:0] xt;
    reg [8:0] yt;
    reg [9:0] xd;
    reg [8:0] yd;

    localparam SPRITE_WIDTH = 16;
    localparam SPRITE_HEIGHT = 16;
localparam OBSTACLE_WIDTH = 32;
localparam OBSTACLE_HEIGHT = 32;
    localparam ROAD_HEIGHT = SPRITE_HEIGHT * 2;
    localparam SIDEWALK_HEIGHT = SPRITE_HEIGHT * 2;
    localparam LANE_HEIGHT = ROAD_HEIGHT + SIDEWALK_HEIGHT;
    localparam BOTTOM_SIDEWALK_HEIGHT = LANE_HEIGHT * 2;
    localparam PLAYABLE_HEIGHT = HEIGHT - BOTTOM_SIDEWALK_HEIGHT;
	 

    parameter [0:SPRITE_WIDTH*SPRITE_HEIGHT-1] ROAD_SPRITE = {
        16'b1111111111111111, // Yellow line
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b1111111111111111, // White ticker
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b0000000000000000,
        16'b1111111111111111  // Yellow line
    };
	 
    parameter [23:0] YELLOW_COLOR = 24'hFFFF00;
    parameter [23:0] WHITE_COLOR = 24'hFFFFFF;
    parameter [23:0] BLACK_COLOR = 24'h000000;
    parameter [23:0] LIGHT_GRAY_COLOR = 24'hD3D3D3;
    parameter [23:0] DARK_GRAY_COLOR = 24'hA9A9A9;

    // Define blue man sprite data using a parameter
parameter [0:SPRITE_WIDTH*SPRITE_HEIGHT-1] BLUE_MAN_SPRITE = {
    16'b0000000000000000,
    16'b0000011111100000,
    16'b0000111111110000,
    16'b0000111111110000,
    16'b0001111111111000,
    16'b0001110110111000,
    16'b0000110110110000,
    16'b0000011111100000,
    16'b0000100000010000,
    16'b0001111111111000,
    16'b0011011111101100,
    16'b0011011111101100,
    16'b0000011111100000,
    16'b0000011001100000,
    16'b0000011001100000,
    16'b0000000000000000
};

// Outline for the Blue Man Sprite
parameter [0:SPRITE_WIDTH*SPRITE_HEIGHT-1] BLUE_MAN_OUTLINE = {
    16'b0000111111110000,
    16'b0001111111111000,
    16'b0011111111111100,
    16'b0011111111111100,
    16'b0111111111111110,
    16'b0111111111111110,
    16'b0011111111111100,
    16'b0001111111111000,
    16'b0001111111111000,
    16'b0111111111111110,
    16'b1111111111111111,
    16'b1111111111111111,
    16'b0001111111111000,
    16'b0001111111111000,
    16'b0001111111111000,
    16'b0000111111110000
};

// truck sprite has mutliple pieces which need to be rendered ~ 5 colors, black, white, light gray, sky blue, and dark gray

parameter [0:OBSTACLE_WIDTH*OBSTACLE_HEIGHT-1] TRUCK_SPRITE_BLACK = {
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000001111100000001111100,
    32'b00000000001111111111111111111111,
    32'b00001111111000000000000000000001,
    32'b11111010001000000000000000000001,
    32'b10001110001001000000000000000001,
    32'b10001010001110000000000000000001,
    32'b10001010001000000000000000000001,
    32'b10001010001000000000000000000001,
    32'b10001010001000000000000000000001,
    32'b10001010001001000000000000000001,
    32'b10001010001110000000000000000001,
    32'b10001010001000000000000000000001,
    32'b10001110001000000000000000000001,
    32'b10001010001110000000000000000001,
    32'b10001010001001000000000000000001,
    32'b10001010001000000000000000000001,
    32'b10001010001000000000000000000001,
    32'b10001010001000000000000000000001,
    32'b10001010001110000000000000000001,
    32'b10001110001001000000000000000001,
    32'b11111010001000000000000000000001,
    32'b00001111111000000000000000000001,
    32'b00000000001111111111111111111111,
    32'b00000000000001111100000001111100,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000
};


parameter [0:OBSTACLE_WIDTH*OBSTACLE_HEIGHT-1] TRUCK_SPRITE_WHITE = {
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000101110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b01110001110000000000000000000000,
    32'b00000101110000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000
};

parameter [0:OBSTACLE_WIDTH*OBSTACLE_HEIGHT-1] TRUCK_SPRITE_SKY_BLUE = {
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000100000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000
};

parameter [0:OBSTACLE_WIDTH*OBSTACLE_HEIGHT-1] TRUCK_SPRITE_DARK_GRAY = {
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000110000000000000000000,
    32'b00000000000001000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000110000000000000000000,
    32'b00000000000001000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000001000000000000000000,
    32'b00000000000110000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000001000000000000000000,
    32'b00000000000110000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000111000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000
};


parameter [0:OBSTACLE_WIDTH*OBSTACLE_HEIGHT-1] TRUCK_SPRITE_LIGHT_GRAY= {
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000111111111111111110,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000,
    32'b00000000000000000000000000000000
};



// Replace your existing text_renderer instantiations with these:
    logic [18:0] title_pixels;
text_renderer text_B  (.x(xt), .y(yt), .text_x(10'd220), .text_y(9'd200), .character("B"), .is_text_pixel(title_pixels[0]));
text_renderer text_L  (.x(xt), .y(yt), .text_x(10'd228), .text_y(9'd200), .character("L"), .is_text_pixel(title_pixels[1]));
text_renderer text_U  (.x(xt), .y(yt), .text_x(10'd236), .text_y(9'd200), .character("U"), .is_text_pixel(title_pixels[2]));
text_renderer text_E1 (.x(xt), .y(yt), .text_x(10'd244), .text_y(9'd200), .character("E"), .is_text_pixel(title_pixels[3]));
text_renderer text_M  (.x(xt), .y(yt), .text_x(10'd260), .text_y(9'd200), .character("M"), .is_text_pixel(title_pixels[4]));
text_renderer text_A1 (.x(xt), .y(yt), .text_x(10'd268), .text_y(9'd200), .character("A"), .is_text_pixel(title_pixels[5]));
text_renderer text_N  (.x(xt), .y(yt), .text_x(10'd276), .text_y(9'd200), .character("N"), .is_text_pixel(title_pixels[6]));
text_renderer text_A2 (.x(xt), .y(yt), .text_x(10'd292), .text_y(9'd200), .character("A"), .is_text_pixel(title_pixels[7]));
text_renderer text_D  (.x(xt), .y(yt), .text_x(10'd300), .text_y(9'd200), .character("D"), .is_text_pixel(title_pixels[8]));
text_renderer text_V  (.x(xt), .y(yt), .text_x(10'd308), .text_y(9'd200), .character("V"), .is_text_pixel(title_pixels[9]));
text_renderer text_E2 (.x(xt), .y(yt), .text_x(10'd316), .text_y(9'd200), .character("E"), .is_text_pixel(title_pixels[10]));
text_renderer text_N2 (.x(xt), .y(yt), .text_x(10'd324), .text_y(9'd200), .character("N"), .is_text_pixel(title_pixels[11]));
text_renderer text_T  (.x(xt), .y(yt), .text_x(10'd332), .text_y(9'd200), .character("T"), .is_text_pixel(title_pixels[12]));
text_renderer text_U2 (.x(xt), .y(yt), .text_x(10'd340), .text_y(9'd200), .character("U"), .is_text_pixel(title_pixels[13]));
text_renderer text_R  (.x(xt), .y(yt), .text_x(10'd348), .text_y(9'd200), .character("R"), .is_text_pixel(title_pixels[14]));
text_renderer text_E3 (.x(xt), .y(yt), .text_x(10'd356), .text_y(9'd200), .character("E"), .is_text_pixel(title_pixels[15]));

// Text rendering for "TOGGLE SW1 TO START"
logic [24:0] instruction_pixels;
text_renderer text_T2 (.x(xt), .y(yt), .text_x(10'd220), .text_y(9'd240), .character("T"), .is_text_pixel(instruction_pixels[0]));
text_renderer text_O  (.x(xt), .y(yt), .text_x(10'd228), .text_y(9'd240), .character("O"), .is_text_pixel(instruction_pixels[1]));
text_renderer text_G  (.x(xt), .y(yt), .text_x(10'd236), .text_y(9'd240), .character("G"), .is_text_pixel(instruction_pixels[2]));
text_renderer text_G2 (.x(xt), .y(yt), .text_x(10'd244), .text_y(9'd240), .character("G"), .is_text_pixel(instruction_pixels[3]));
text_renderer text_L2 (.x(xt), .y(yt), .text_x(10'd252), .text_y(9'd240), .character("L"), .is_text_pixel(instruction_pixels[4]));
text_renderer text_E4 (.x(xt), .y(yt), .text_x(10'd260), .text_y(9'd240), .character("E"), .is_text_pixel(instruction_pixels[5]));
text_renderer text_S  (.x(xt), .y(yt), .text_x(10'd276), .text_y(9'd240), .character("S"), .is_text_pixel(instruction_pixels[6]));
text_renderer text_W  (.x(xt), .y(yt), .text_x(10'd284), .text_y(9'd240), .character("W"), .is_text_pixel(instruction_pixels[7]));
text_renderer text_Z (.x(xt), .y(yt), .text_x(10'd292), .text_y(9'd240), .character("Z"), .is_text_pixel(instruction_pixels[8]));
text_renderer text_E5 (.x(xt), .y(yt), .text_x(10'd300), .text_y(9'd240), .character("E"), .is_text_pixel(instruction_pixels[9]));
text_renderer text_R2 (.x(xt), .y(yt), .text_x(10'd308), .text_y(9'd240), .character("R"), .is_text_pixel(instruction_pixels[10]));
text_renderer text_O2 (.x(xt), .y(yt), .text_x(10'd316), .text_y(9'd240), .character("O"), .is_text_pixel(instruction_pixels[11]));
text_renderer text_T3 (.x(xt), .y(yt), .text_x(10'd332), .text_y(9'd240), .character("T"), .is_text_pixel(instruction_pixels[12]));
text_renderer text_O3 (.x(xt), .y(yt), .text_x(10'd340), .text_y(9'd240), .character("O"), .is_text_pixel(instruction_pixels[13]));
text_renderer text_S2 (.x(xt), .y(yt), .text_x(10'd348), .text_y(9'd240), .character("S"), .is_text_pixel(instruction_pixels[14]));
text_renderer text_T4 (.x(xt), .y(yt), .text_x(10'd356), .text_y(9'd240), .character("T"), .is_text_pixel(instruction_pixels[15]));
text_renderer text_A3 (.x(xt), .y(yt), .text_x(10'd364), .text_y(9'd240), .character("A"), .is_text_pixel(instruction_pixels[16]));
text_renderer text_R3 (.x(xt), .y(yt), .text_x(10'd372), .text_y(9'd240), .character("R"), .is_text_pixel(instruction_pixels[17]));
text_renderer text_T5 (.x(xt), .y(yt), .text_x(10'd380), .text_y(9'd240), .character("T"), .is_text_pixel(instruction_pixels[18]));


// game over text
logic [30:0] game_over_message_pixels;
text_renderer text_GO_G (.x(xt), .y(yt), .text_x(10'd240), .text_y(9'd200), .character("G"), .is_text_pixel(game_over_message_pixels[0]));
text_renderer text_GO_A (.x(xt), .y(yt), .text_x(10'd248), .text_y(9'd200), .character("A"), .is_text_pixel(game_over_message_pixels[1]));
text_renderer text_GO_M (.x(xt), .y(yt), .text_x(10'd256), .text_y(9'd200), .character("M"), .is_text_pixel(game_over_message_pixels[2]));
text_renderer text_GO_E1 (.x(xt), .y(yt), .text_x(10'd264), .text_y(9'd200), .character("E"), .is_text_pixel(game_over_message_pixels[3]));
text_renderer text_GO_O1 (.x(xt), .y(yt), .text_x(10'd280), .text_y(9'd200), .character("O"), .is_text_pixel(game_over_message_pixels[4]));
text_renderer text_GO_V1 (.x(xt), .y(yt), .text_x(10'd288), .text_y(9'd200), .character("V"), .is_text_pixel(game_over_message_pixels[5]));
text_renderer text_GO_E2 (.x(xt), .y(yt), .text_x(10'd296), .text_y(9'd200), .character("E"), .is_text_pixel(game_over_message_pixels[6]));
text_renderer text_GO_R1 (.x(xt), .y(yt), .text_x(10'd304), .text_y(9'd200), .character("R"), .is_text_pixel(game_over_message_pixels[7]));

text_renderer text_GO_Y (.x(xt), .y(yt), .text_x(10'd240), .text_y(9'd220), .character("Y"), .is_text_pixel(game_over_message_pixels[8]));
text_renderer text_GO_O2 (.x(xt), .y(yt), .text_x(10'd248), .text_y(9'd220), .character("O"), .is_text_pixel(game_over_message_pixels[9]));
text_renderer text_GO_U (.x(xt), .y(yt), .text_x(10'd256), .text_y(9'd220), .character("U"), .is_text_pixel(game_over_message_pixels[10]));
text_renderer text_GO_G2 (.x(xt), .y(yt), .text_x(10'd272), .text_y(9'd220), .character("G"), .is_text_pixel(game_over_message_pixels[11]));
text_renderer text_GO_O3 (.x(xt), .y(yt), .text_x(10'd280), .text_y(9'd220), .character("O"), .is_text_pixel(game_over_message_pixels[12]));
text_renderer text_GO_T (.x(xt), .y(yt), .text_x(10'd288), .text_y(9'd220), .character("T"), .is_text_pixel(game_over_message_pixels[13]));

text_renderer text_GO_R2 (.x(xt), .y(yt), .text_x(10'd240), .text_y(9'd240), .character("R"), .is_text_pixel(game_over_message_pixels[14]));
text_renderer text_GO_A2 (.x(xt), .y(yt), .text_x(10'd248), .text_y(9'd240), .character("A"), .is_text_pixel(game_over_message_pixels[15]));
text_renderer text_GO_N (.x(xt), .y(yt), .text_x(10'd256), .text_y(9'd240), .character("N"), .is_text_pixel(game_over_message_pixels[16]));
text_renderer text_GO_O4 (.x(xt), .y(yt), .text_x(10'd272), .text_y(9'd240), .character("O"), .is_text_pixel(game_over_message_pixels[17]));
text_renderer text_GO_V2 (.x(xt), .y(yt), .text_x(10'd280), .text_y(9'd240), .character("V"), .is_text_pixel(game_over_message_pixels[18]));
text_renderer text_GO_E3 (.x(xt), .y(yt), .text_x(10'd288), .text_y(9'd240), .character("E"), .is_text_pixel(game_over_message_pixels[19]));
text_renderer text_GO_R3 (.x(xt), .y(yt), .text_x(10'd296), .text_y(9'd240), .character("R"), .is_text_pixel(game_over_message_pixels[20]));

logic [5:0] win_message_pixels;
text_renderer text_WIN_Y (.x(xt), .y(yt), .text_x(10'd280), .text_y(9'd220), .character("Y"), .is_text_pixel(win_message_pixels[0]));
text_renderer text_WIN_O (.x(xt), .y(yt), .text_x(10'd288), .text_y(9'd220), .character("O"), .is_text_pixel(win_message_pixels[1]));
text_renderer text_WIN_U (.x(xt), .y(yt), .text_x(10'd296), .text_y(9'd220), .character("U"), .is_text_pixel(win_message_pixels[2]));
text_renderer text_WIN_W (.x(xt), .y(yt), .text_x(10'd312), .text_y(9'd220), .character("W"), .is_text_pixel(win_message_pixels[3]));
text_renderer text_WIN_O2 (.x(xt), .y(yt), .text_x(10'd320), .text_y(9'd220), .character("O"), .is_text_pixel(win_message_pixels[4]));
text_renderer text_WIN_N (.x(xt), .y(yt), .text_x(10'd328), .text_y(9'd220), .character("N"), .is_text_pixel(win_message_pixels[5]));


	 logic [9:0] obstacle_x [NUM_ROWS-1:0][OBSTACLES_PER_ROW-1:0];
    logic [8:0] obstacle_y [NUM_ROWS-1:0][OBSTACLES_PER_ROW-1:0];
	 logic direction [NUM_ROWS-1:0];

obstacle_manager #(
    .NUM_ROWS(NUM_ROWS),
    .OBSTACLES_PER_ROW(OBSTACLES_PER_ROW)
) obstacle_mgr (
    .CLOCK_50(CLOCK_50),
    .reset(reset),
    .gameState(gameState),
    .frame_start(frame_start),
    .obstacle_x(obstacle_x),
    .obstacle_y(obstacle_y),
    .direction(direction)  
);
    game_state gameProgress (
        .clk(CLOCK_50),
        .reset(reset),
        .start(start),
        .collision(collision),
		  .player_y(playerY),  
        .state(gameState)
    );

    collision_detector #(
        .NUM_ROWS(NUM_ROWS),
        .OBSTACLES_PER_ROW(OBSTACLES_PER_ROW)
    ) collisionDetector (
        .clk(CLOCK_50),
        .reset(reset),
        .player_x(playerX),
        .player_y(playerY),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .collision(collision)
    );

    input_handler inputController (
        .CLOCK_50(CLOCK_50),
        .up(~KEY[2]),
        .down(~KEY[0]),
        .left(~KEY[3]),
        .right(~KEY[1]),
        .gameState(gameState),
        .x(playerX),
        .y(playerY),
        .reset(reset),
        .frame_start(frame_start)
    );

    CLOCK25_PLL c25_gen (.refclk(CLOCK_50), .rst(reset), .outclk_0(CLOCK_25), .locked);    
	 

    always_ff @(posedge CLOCK_25) begin
        frame_start <= end_of_active_frame;
    end

    always @(posedge CLOCK_25) begin
        if(reset) begin
            xt <= 0;
            yt <= 0;
            xd <= 0;
            yd <= 0;
            x <= 0;
            y <= 0;
        end else begin
            read_enable_last <= read_enable;
            if(read_enable) begin
                xt <= xt + 1'b1;
                if(xt >= X_START && xt < X_STOP) begin
                    if(xd == BLOCK_STOP) begin
                        xd <= 10'b0;
                        x <= x + 1'b1;
                    end else begin
                        xd <= xd + 1'b1;
                    end
                end else begin
                    xd <= 10'b0;
                    x <= 10'b0;
                end
            end else begin
                xt <= 10'b0;
                xd <= 10'b0;
                x <= 10'b0;
            end
            if(end_of_active_frame) begin
                yt <= 9'b111111111;
                yd <= 9'b0;
                y <= 9'b0;
            end else begin
                if(read_enable_last & ~read_enable) begin
                    yt <= yt + 1'b1;
                    if(yt >= Y_START && yt < Y_STOP) begin
                        if(yd == BLOCK_STOP) begin
                            yd <= 9'b0;
                            y <= y + 1'b1;
                        end else begin
                            yd <= yd + 1'b1;
                        end
                    end else begin
                        yd <= 9'b0;
                        y <= 9'b0;
                    end
                end
            end
        end
    end

    reg [7:0] rout, gout, bout;
    logic is_road_row [NUM_ROWS-1:0];
    
    // set up the roads fr
    always_ff @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            for (int row = 0; row < NUM_ROWS; row++) begin
                is_road_row[row] <= (row % 2 == 0);
            end
        end
    end
	 
	    localparam BOTTOM_SIDEWALK_ROWS = 4;
    localparam ROWS_PER_SECTION = 2;
    localparam TOTAL_ROWS = NUM_ROWS + BOTTOM_SIDEWALK_ROWS;  
	 logic obstacle_found;
	 

// Constants for truck movement
logic [9:0] truck_x;
logic [8:0] truck_y;
logic truck_dir_x;  // 0 for left, 1 for right
logic truck_dir_y;  // 0 for up, 1 for down
logic [31:0] time_since_game_over;

// Constants for truck movement
localparam TRUCK_SPEED_X = 2;
localparam TRUCK_SPEED_Y = 2;
localparam TRUCK_WIDTH = 32;
localparam TRUCK_HEIGHT = 32;
localparam SCREEN_WIDTH = 640;
localparam SCREEN_HEIGHT = 480;

// bouncing truck basic logic
always_ff @(posedge CLOCK_50 or posedge reset) begin
    if (reset) begin
        truck_x <= 10'd320;  // Start in the middle of the screen
        truck_y <= 9'd240;
        truck_dir_x <= 1'b1;  // Start moving right
        truck_dir_y <= 1'b1;  // Start moving down
        time_since_game_over <= 0;
    end else if (gameState == 2'b10 && frame_start) begin  // Only move when in OVER state and at frame start
        time_since_game_over <= time_since_game_over + 1;

        // Update X position
        if (truck_dir_x == 1'b1) begin
            if (truck_x + TRUCK_SPEED_X + TRUCK_WIDTH >= SCREEN_WIDTH) begin
                truck_x <= SCREEN_WIDTH - TRUCK_WIDTH;
                truck_dir_x <= 1'b0;
            end else begin
                truck_x <= truck_x + TRUCK_SPEED_X;
            end
        end else begin
            if (truck_x < TRUCK_SPEED_X) begin
                truck_x <= 0;
                truck_dir_x <= 1'b1;
            end else begin
                truck_x <= truck_x - TRUCK_SPEED_X;
            end
        end

        // Update Y position
        if (truck_dir_y == 1'b1) begin
            if (truck_y + TRUCK_SPEED_Y + TRUCK_HEIGHT >= SCREEN_HEIGHT) begin
                truck_y <= SCREEN_HEIGHT - TRUCK_HEIGHT;
                truck_dir_y <= 1'b0;
            end else begin
                truck_y <= truck_y + TRUCK_SPEED_Y;
            end
        end else begin
            if (truck_y < TRUCK_SPEED_Y) begin
                truck_y <= 0;
                truck_dir_y <= 1'b1;
            end else begin
                truck_y <= truck_y - TRUCK_SPEED_Y;
            end
        end
    end
end



reg [9:0] blue_man_x;
reg [8:0] blue_man_y;
reg blue_man_dir_x;
reg blue_man_dir_y;
reg [31:0] time_since_win;

// Constants for blue man movement
localparam BLUE_MAN_SPEED_X = 3;  // Slightly faster than the truck for variety
localparam BLUE_MAN_SPEED_Y = 3;
localparam BLUE_MAN_WIDTH = 16;
localparam BLUE_MAN_HEIGHT = 16;

// Blue man movement logic
always_ff @(posedge CLOCK_50 or posedge reset) begin
    if (reset) begin
        blue_man_x <= 10'd320;  // Start in the middle of the screen
        blue_man_y <= 9'd240;
        blue_man_dir_x <= 1'b1;  // Start moving right
        blue_man_dir_y <= 1'b1;  // Start moving down
        time_since_win <= 0;
    end else if (gameState == 2'b11 && frame_start) begin  // Only move when in WIN state and at frame start
        time_since_win <= time_since_win + 1;

        // Update X position
        if (blue_man_dir_x == 1'b1) begin
            if (blue_man_x + BLUE_MAN_SPEED_X + BLUE_MAN_WIDTH >= SCREEN_WIDTH) begin
                blue_man_x <= SCREEN_WIDTH - BLUE_MAN_WIDTH;
                blue_man_dir_x <= 1'b0;
            end else begin
                blue_man_x <= blue_man_x + BLUE_MAN_SPEED_X;
            end
        end else begin
            if (blue_man_x < BLUE_MAN_SPEED_X) begin
                blue_man_x <= 0;
                blue_man_dir_x <= 1'b1;
            end else begin
                blue_man_x <= blue_man_x - BLUE_MAN_SPEED_X;
            end
        end

        // Update Y position
        if (blue_man_dir_y == 1'b1) begin
            if (blue_man_y + BLUE_MAN_SPEED_Y + BLUE_MAN_HEIGHT >= SCREEN_HEIGHT) begin
                blue_man_y <= SCREEN_HEIGHT - BLUE_MAN_HEIGHT;
                blue_man_dir_y <= 1'b0;
            end else begin
                blue_man_y <= blue_man_y + BLUE_MAN_SPEED_Y;
            end
        end else begin
            if (blue_man_y < BLUE_MAN_SPEED_Y) begin
                blue_man_y <= 0;
                blue_man_dir_y <= 1'b1;
            end else begin
                blue_man_y <= blue_man_y - BLUE_MAN_SPEED_Y;
            end
        end
    end
end



// Main rendering logic
always_ff @(posedge CLOCK_25) begin
    if(reset) begin
        rout <= 8'h00;
        gout <= 8'h00;
        bout <= 8'h00;
    end else  if (gameState == 2'b11) begin // WIN state
        if (|win_message_pixels) begin
            // Render "You won!" in green
            rout <= 8'h00;
            gout <= 8'hFF;
            bout <= 8'h00;
        end else if (xt >= blue_man_x && xt < (blue_man_x + BLUE_MAN_WIDTH) &&
                     yt >= blue_man_y && yt < (blue_man_y + BLUE_MAN_HEIGHT)) begin
            // Render bouncing blue man
            logic [3:0] sprite_x, sprite_y;
            sprite_x = xt - blue_man_x;
            sprite_y = yt - blue_man_y;
            if (BLUE_MAN_OUTLINE[sprite_y * BLUE_MAN_WIDTH + sprite_x] && 
                !BLUE_MAN_SPRITE[sprite_y * BLUE_MAN_WIDTH + sprite_x]) begin
                // Render black outline
                rout <= 8'h00;
                gout <= 8'h00;
                bout <= 8'h00;
            end else if (BLUE_MAN_SPRITE[sprite_y * BLUE_MAN_WIDTH + sprite_x]) begin
                // Render blue sprite
                rout <= 8'h00;
                gout <= 8'h00;
                bout <= 8'hFF;
            end else begin
                // Transparent pixel, render background
                rout <= 8'h40;
                gout <= 8'h40;
                bout <= 8'h40;
            end
        end else begin
            // Render a light background
            rout <= 8'h40;
            gout <= 8'h40;
            bout <= 8'h40;
        end
    end else if (gameState == 2'b00) begin // START state
        // Render start screen text
        if (|title_pixels) begin
            // Render title in white
            rout <= 8'hFF;
            gout <= 8'hFF;
            bout <= 8'hFF;
        end else if (|instruction_pixels) begin
            // Render instruction in yellow
            rout <= 8'h00;
            gout <= 8'h00;
            bout <= 8'hFF;
        end else begin
            // Render background (you can customize this)
            rout <= 8'h00;
            gout <= 8'h00;
            bout <= 8'h00;
        end
    end else if (gameState == 2'b10) begin // OVER state
        if (|game_over_message_pixels) begin
            // Render "Game Over, you got ran over" in red
            rout <= 8'hFF;
            gout <= 8'h00;
            bout <= 8'h00;
        end else if (xt >= truck_x && xt < (truck_x + OBSTACLE_WIDTH) &&
                     yt >= truck_y && yt < (truck_y + OBSTACLE_HEIGHT)) begin
            // Render bouncing truck
            logic [4:0] sprite_x, sprite_y;
            logic is_black, is_white, is_sky_blue, is_dark_gray, is_light_gray;
            
            sprite_x = xt - truck_x;
            sprite_y = yt - truck_y;
            
            is_black = TRUCK_SPRITE_BLACK[sprite_y * OBSTACLE_WIDTH + sprite_x];
            is_white = TRUCK_SPRITE_WHITE[sprite_y * OBSTACLE_WIDTH + sprite_x];
            is_sky_blue = TRUCK_SPRITE_SKY_BLUE[sprite_y * OBSTACLE_WIDTH + sprite_x];
            is_dark_gray = TRUCK_SPRITE_DARK_GRAY[sprite_y * OBSTACLE_WIDTH + sprite_x];
            is_light_gray = TRUCK_SPRITE_LIGHT_GRAY[sprite_y * OBSTACLE_WIDTH + sprite_x];
            
            if (is_black) begin
                rout <= 8'h00; gout <= 8'h00; bout <= 8'h00;
            end else if (is_white) begin
                rout <= 8'hFF; gout <= 8'hFF; bout <= 8'hFF;
            end else if (is_sky_blue) begin
                rout <= 8'h87; gout <= 8'hCE; bout <= 8'hFA;
            end else if (is_dark_gray) begin
                rout <= 8'h4A; gout <= 8'h4A; bout <= 8'h4A;
            end else if (is_light_gray) begin
                rout <= 8'hD3; gout <= 8'hD3; bout <= 8'hD3;
            end else begin
                // Transparent pixel, render background
                rout <= 8'h20; gout <= 8'h20; bout <= 8'h20;
            end
        end else begin
            // Render a dark background
            rout <= 8'hFF;
            gout <= 8'hFF;
            bout <= 8'hFF;
        end
    end else if (xt >= X_START && xt < X_STOP && yt >= Y_START && yt < Y_STOP) begin
        logic [9:0] rel_x;
        logic [8:0] rel_y;
        logic [4:0] row_number;
        logic [3:0] sprite_y;
        logic [3:0] sprite_x;
        logic is_road_section;
        logic obstacle_found;
        logic in_player_sprite;
        logic pixel_rendered;
        logic is_black, is_white, is_sky_blue, is_dark_gray, is_light_gray;

        rel_x = xt - X_START;
        rel_y = yt - Y_START;
        row_number = (HEIGHT - 1 - rel_y) / SPRITE_HEIGHT; // Invert y-axis
        sprite_y = (HEIGHT - 1 - rel_y) % SPRITE_HEIGHT;
        sprite_x = rel_x % SPRITE_WIDTH;

        // Background rendering
        if (row_number < BOTTOM_SIDEWALK_ROWS) begin
            if (sprite_x == 0 || sprite_x == SPRITE_WIDTH - 1 || 
                sprite_y == 0 || sprite_y == SPRITE_HEIGHT - 1 || 
                rel_x == WIDTH - 1) begin // Added condition for right edge
                // Dark gray border (including right edge)
                rout <= DARK_GRAY_COLOR[23:16];
                gout <= DARK_GRAY_COLOR[15:8];
                bout <= DARK_GRAY_COLOR[7:0];
            end else begin
                // Light gray inside
                rout <= LIGHT_GRAY_COLOR[23:16];
                gout <= LIGHT_GRAY_COLOR[15:8];
                bout <= LIGHT_GRAY_COLOR[7:0];
            end
        end else begin
            logic [4:0] adjusted_row_number;
            adjusted_row_number = row_number - BOTTOM_SIDEWALK_ROWS;
            is_road_section = (adjusted_row_number / ROWS_PER_SECTION) % 2 == 0;

            if (is_road_section) begin
                // Road
                if (ROAD_SPRITE[sprite_y * SPRITE_WIDTH + sprite_x]) begin
                    if (sprite_y == 0 || sprite_y == SPRITE_HEIGHT - 1) begin
                        rout <= YELLOW_COLOR[23:16];
                        gout <= YELLOW_COLOR[15:8];
                        bout <= YELLOW_COLOR[7:0];
                    end else begin
                        rout <= WHITE_COLOR[23:16];
                        gout <= WHITE_COLOR[15:8];
                        bout <= WHITE_COLOR[7:0];
                    end
                end else begin
                    rout <= BLACK_COLOR[23:16];
                    gout <= BLACK_COLOR[15:8];
                    bout <= BLACK_COLOR[7:0];
                end
            end else begin
                // Sidewalk
                if (sprite_x == 0 || sprite_x == SPRITE_WIDTH - 1 || 
                    sprite_y == 0 || sprite_y == SPRITE_HEIGHT - 1) begin
                    rout <= DARK_GRAY_COLOR[23:16];
                    gout <= DARK_GRAY_COLOR[15:8];
                    bout <= DARK_GRAY_COLOR[7:0];
                end else begin
                    rout <= LIGHT_GRAY_COLOR[23:16];
                    gout <= LIGHT_GRAY_COLOR[15:8];
                    bout <= LIGHT_GRAY_COLOR[7:0];
                end
            end
        end
        
        pixel_rendered = 0;
        for (int row = 0; row < NUM_ROWS; row++) begin
            for (int col = 0; col < OBSTACLES_PER_ROW; col++) begin
                if (xt >= obstacle_x[row][col] && xt < (obstacle_x[row][col] + OBSTACLE_WIDTH) &&
                    yt >= obstacle_y[row][col] && yt < (obstacle_y[row][col] + OBSTACLE_HEIGHT)) begin

                    logic [4:0] obs_sprite_x, obs_sprite_y;
                    obs_sprite_y = yt - obstacle_y[row][col];
                    
                    // Flip the sprite horizontally if moving right
                    if (direction[row] == 0) begin // Assuming 0 means moving right
                        obs_sprite_x = OBSTACLE_WIDTH - 1 - (xt - obstacle_x[row][col]);
                    end else begin
                        obs_sprite_x = xt - obstacle_x[row][col];
                    end
                    
                    is_black = TRUCK_SPRITE_BLACK[obs_sprite_y * OBSTACLE_WIDTH + obs_sprite_x];
                    is_white = TRUCK_SPRITE_WHITE[obs_sprite_y * OBSTACLE_WIDTH + obs_sprite_x];
                    is_sky_blue = TRUCK_SPRITE_SKY_BLUE[obs_sprite_y * OBSTACLE_WIDTH + obs_sprite_x];
                    is_dark_gray = TRUCK_SPRITE_DARK_GRAY[obs_sprite_y * OBSTACLE_WIDTH + obs_sprite_x];
                    is_light_gray = TRUCK_SPRITE_LIGHT_GRAY[obs_sprite_y * OBSTACLE_WIDTH + obs_sprite_x];
                    
                    if (is_black) begin
                        // Render black pixel for the truck
                        rout <= 8'h00;
                        gout <= 8'h00;
                        bout <= 8'h00;
                        pixel_rendered = 1;
                    end else if (is_white) begin
                        // Render white pixel for the truck
                        rout <= 8'hFF;
                        gout <= 8'hFF;
                        bout <= 8'hFF;
                        pixel_rendered = 1;
                    end else if (is_sky_blue) begin
                        // Render sky blue pixel for the truck
                        rout <= 8'h87;
                        gout <= 8'hCE;
                        bout <= 8'hFA;
                        pixel_rendered = 1;
                    end else if (is_dark_gray) begin
                        // Render dark gray pixel for the truck
                        rout <= 8'h4A;
                        gout <= 8'h4A;
                        bout <= 8'h4A;
                        pixel_rendered = 1;
                    end else if (is_light_gray) begin
                        // Render light gray pixel for the truck
                        rout <= 8'hD3;
                        gout <= 8'hD3;
                        bout <= 8'hD3;
                        pixel_rendered = 1;
                    end
                    // If none of the colors, pixel remains transparent
                end
            end
        end

        // Render player if pixel not already rendered
        if (!pixel_rendered && xt >= playerX && xt < (playerX + SPRITE_WIDTH) &&
            yt >= playerY && yt < (playerY + SPRITE_HEIGHT)) begin
            logic [3:0] player_sprite_x, player_sprite_y;
            player_sprite_x = xt - playerX;
            player_sprite_y = yt - playerY;
            if (BLUE_MAN_OUTLINE[player_sprite_y * SPRITE_WIDTH + player_sprite_x] && 
                !BLUE_MAN_SPRITE[player_sprite_y * SPRITE_WIDTH + player_sprite_x]) begin
                // Render black outline
                rout <= 8'h00;
                gout <= 8'h00;
                bout <= 8'h00;
            end else if (BLUE_MAN_SPRITE[player_sprite_y * SPRITE_WIDTH + player_sprite_x]) begin
                // Render blue sprite
                rout <= 8'h00;
                gout <= 8'h00;
                bout <= 8'hFF;
            end
        end

    end else begin
        rout <= 8'h00;
        gout <= 8'h00;
        bout <= 8'h00;
    end
end
    assign VGA_BLANK_N = vga_blank;
    assign VGA_CLK = CLOCK_25;
    assign VGA_HS = vga_h_sync;
    assign VGA_SYNC_N = 1'b0;
    assign VGA_VS = vga_v_sync;
    
    altera_up_avalon_video_vga_timing video (
        // inputs
        .clk(CLOCK_25),
        .reset,
        .red_to_vga_display({rout,2'b00}),
        .green_to_vga_display({gout,2'b00}),
        .blue_to_vga_display({bout,2'b00}),
        .color_select(4'b1111),
        
        // outputs
        .read_enable,
        .end_of_active_frame,
        .end_of_frame,
        // dac pins
        .vga_blank,                    //    VGA BLANK
        .vga_c_sync,                   //    VGA COMPOSITE SYNC
        .vga_h_sync,                   //    VGA H_SYNC
        .vga_v_sync,                   //    VGA V_SYNC
        .vga_data_enable,              // VGA DEN
        .vga_red(VGA_R),               //    VGA Red[9:0]
        .vga_green(VGA_G),             //    VGA Green[9:0]
        .vga_blue(VGA_B),              //    VGA Blue[9:0]
        .vga_color_data()              //    VGA Color[9:0] for TRDB_LCM
    );
endmodule