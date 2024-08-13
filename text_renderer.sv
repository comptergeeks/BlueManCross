module text_renderer(
    input logic [9:0] x,
    input logic [8:0] y,
    input logic [9:0] text_x,
    input logic [8:0] text_y,
    input logic [7:0] character,
    output logic is_text_pixel
);
    // Define a simple 8x8 font for required characters
 parameter [0:36][0:7][7:0] FONT_8X8 = {
        {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}, // Space
        {8'h18, 8'h3C, 8'h3C, 8'h18, 8'h18, 8'h00, 8'h18, 8'h00}, // !
        {8'h36, 8'h36, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}, // "
        {8'h36, 8'h36, 8'h7F, 8'h36, 8'h7F, 8'h36, 8'h36, 8'h00}, // #
        {8'h0C, 8'h3E, 8'h03, 8'h1E, 8'h30, 8'h1F, 8'h0C, 8'h00}, // $
        {8'h00, 8'h63, 8'h33, 8'h18, 8'h0C, 8'h66, 8'h63, 8'h00}, // %
        {8'h1C, 8'h36, 8'h1C, 8'h6E, 8'h3B, 8'h33, 8'h6E, 8'h00}, // &
        {8'h06, 8'h06, 8'h03, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}, // '
        {8'h18, 8'h0C, 8'h06, 8'h06, 8'h06, 8'h0C, 8'h18, 8'h00}, // (
        {8'h06, 8'h0C, 8'h18, 8'h18, 8'h18, 8'h0C, 8'h06, 8'h00}, // )
        {8'h00, 8'h66, 8'h3C, 8'hFF, 8'h3C, 8'h66, 8'h00, 8'h00}, // *
        {8'h00, 8'h0C, 8'h0C, 8'h3F, 8'h0C, 8'h0C, 8'h00, 8'h00}, // +
        {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h0C, 8'h0C, 8'h06}, // ,
        {8'h00, 8'h00, 8'h00, 8'h3F, 8'h00, 8'h00, 8'h00, 8'h00}, // -
        {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h0C, 8'h0C, 8'h00}, // .
        {8'h60, 8'h30, 8'h18, 8'h0C, 8'h06, 8'h03, 8'h01, 8'h00}, // /
        8'h3E, 8'h63, 8'h73, 8'h7B, 8'h6F, 8'h67, 8'h3E, 8'h00, // 0
         8'h0C, 8'h0E, 8'h0C, 8'h0C, 8'h0C, 8'h0C, 8'h3F, 8'h00, // 1
        {8'h1E, 8'h33, 8'h30, 8'h1C, 8'h06, 8'h33, 8'h3F, 8'h00}, // 2
        {8'h1E, 8'h33, 8'h30, 8'h1C, 8'h30, 8'h33, 8'h1E, 8'h00}, // 3
        {8'h38, 8'h3C, 8'h36, 8'h33, 8'h7F, 8'h30, 8'h78, 8'h00}, // 4
        {8'h3F, 8'h03, 8'h1F, 8'h30, 8'h30, 8'h33, 8'h1E, 8'h00}, // 5
        {8'h1C, 8'h06, 8'h03, 8'h1F, 8'h33, 8'h33, 8'h1E, 8'h00}, // 6
        {8'h3F, 8'h33, 8'h30, 8'h18, 8'h0C, 8'h0C, 8'h0C, 8'h00}, // 7
        {8'h1E, 8'h33, 8'h33, 8'h1E, 8'h33, 8'h33, 8'h1E, 8'h00}, // 8
        {8'h1E, 8'h33, 8'h33, 8'h3E, 8'h30, 8'h18, 8'h0E, 8'h00}, // 9
        {8'h00, 8'h0C, 8'h0C, 8'h00, 8'h00, 8'h0C, 8'h0C, 8'h00}, // :
        {8'h00, 8'h0C, 8'h0C, 8'h00, 8'h00, 8'h0C, 8'h0C, 8'h06}, // ;
        {8'h18, 8'h0C, 8'h06, 8'h03, 8'h06, 8'h0C, 8'h18, 8'h00}, // <
        {8'h00, 8'h00, 8'h3F, 8'h00, 8'h00, 8'h3F, 8'h00, 8'h00}, // =
        {8'h06, 8'h0C, 8'h18, 8'h30, 8'h18, 8'h0C, 8'h06, 8'h00}, // >
        {8'h1E, 8'h33, 8'h30, 8'h18, 8'h0C, 8'h00, 8'h0C, 8'h00},  // ?
        8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, // Space
        8'h3C, 8'h66, 8'h66, 8'h7E, 8'h66, 8'h66, 8'h66, 8'h00, // A
        8'h7C, 8'h66, 8'h66, 8'h7C, 8'h66, 8'h66, 8'h7C, 8'h00, // B
        8'h3C, 8'h66, 8'h60, 8'h60, 8'h60, 8'h66, 8'h3C, 8'h00, // C
        8'h7C, 8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h7C, 8'h00, // D
        8'h7E, 8'h60, 8'h60, 8'h7C, 8'h60, 8'h60, 8'h7E, 8'h00, // E
        8'h7E, 8'h60, 8'h60, 8'h7C, 8'h60, 8'h60, 8'h60, 8'h00, // F
        8'h3C, 8'h66, 8'h60, 8'h6E, 8'h66, 8'h66, 8'h3C, 8'h00, // G
        8'h66, 8'h66, 8'h66, 8'h7E, 8'h66, 8'h66, 8'h66, 8'h00, // H
        8'h3C, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h3C, 8'h00, // I
        8'h1E, 8'h0C, 8'h0C, 8'h0C, 8'h0C, 8'h6C, 8'h38, 8'h00, // J
        8'h66, 8'h6C, 8'h78, 8'h70, 8'h78, 8'h6C, 8'h66, 8'h00, // K
        8'h60, 8'h60, 8'h60, 8'h60, 8'h60, 8'h60, 8'h7E, 8'h00, // L
        8'h63, 8'h77, 8'h7F, 8'h6B, 8'h63, 8'h63, 8'h63, 8'h00, // M
        8'h66, 8'h76, 8'h7E, 8'h7E, 8'h6E, 8'h66, 8'h66, 8'h00, // N
        8'h3C, 8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h3C, 8'h00, // O
        8'h7C, 8'h66, 8'h66, 8'h7C, 8'h60, 8'h60, 8'h60, 8'h00, // P
        8'h3C, 8'h66, 8'h66, 8'h66, 8'h66, 8'h3C, 8'h0E, 8'h00, // Q
        8'h7C, 8'h66, 8'h66, 8'h7C, 8'h78, 8'h6C, 8'h66, 8'h00, // R
        8'h3C, 8'h66, 8'h60, 8'h3C, 8'h06, 8'h66, 8'h3C, 8'h00, // S
        8'h7E, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h00, // T
        8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h3C, 8'h00, // U
        8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h3C, 8'h18, 8'h00, // V
        8'h63, 8'h63, 8'h63, 8'h6B, 8'h7F, 8'h77, 8'h63, 8'h00, // W
        8'h66, 8'h66, 8'h3C, 8'h18, 8'h3C, 8'h66, 8'h66, 8'h00, // X
        8'h66, 8'h66, 8'h66, 8'h3C, 8'h18, 8'h18, 8'h18, 8'h00, // Y
        8'h7E, 8'h06, 8'h0C, 8'h18, 8'h30, 8'h60, 8'h7E, 8'h00  // Z
    };

    logic [2:0] char_x, char_y;
    logic [5:0] char_index;
    
    always_comb begin
        char_x = x - text_x;
        char_y = y - text_y;
        
        // Determine the index in the font array
        if (character >= "A" && character <= "Z")
            char_index = character - "A" + 11; // A starts at index 11
        else if (character >= "0" && character <= "9")
            char_index = character - "0" + 1; // Numbers start at index 1
        else if (character == " ")
            char_index = 0;
        else if (character == "!")
            char_index = 1;
        else
            char_index = 0; // Default to space for any other character

        is_text_pixel = (x >= text_x && x < text_x + 8 && y >= text_y && y < text_y + 8) && 
                        (FONT_8X8[char_index][char_y] & (8'h80 >> char_x));
    end
endmodule