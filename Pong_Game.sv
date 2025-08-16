/*


```verilog
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X

```

## Position Allocation

```verilog
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X
X X X X X X X X X X X X X X X X

*/

module pong_game (
    input CLOCK_50,
    input [9:0] SW,
    input [3:0] KEY,
    output reg [35:0] GPIO_1,
    output reg [9:0] LEDR,
    output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    // screen dimensions 
    // quick settings for changing game functions
    localparam DISPLAY_WIDTH = 16;
    localparam DISPLAY_HEIGHT = 16;
    localparam PADDLE_LENGTH = 5;
    localparam MAX_SCORE = 3;


    localparam SPEED_SLOW = 24'd25000000; // 0.5hz
    localparam SPEED_NORMAL = 24'd12500000; //1hz
    localparam SPEED_FAST = 24'd5000000; //2.5hz
    localparam SPEED_FASTEST = 24'd2500000; //5hz

    localparam REFRESH_RATE = 24'd10000;

    typedef enum logic [1:0] {
        RESET_STATE = 2'b00,
        PLAYING = 2'b01,
        GAME_OVER = 2'b10
    } game_state_t;

    game_state_t game_state;
    reg [3:0] p1_score, p2_score;
    reg [3:0] paddle1_pos, paddle2_pos;
    reg [3:0] ball_x, ball_y;

    // 0 means moving left, 1 means moving right
    // 0 means up, 1 means down
    reg ball_dir_x, ball_dir_y;

    // mapping to given row
    reg [15:0] red_rows[16];
    reg [15:0] green_rows[16];

    reg[23:0] refresh_counter;
    reg[23:0] game_counter;

    reg[3:0] current_row;

    reg[3:0] key_pressed;
    reg[3:0] key_prev; // debounce

    reg[6:0] hex_patterns [0:9];

    // all hex numbers
    initial begin
        hex_patterns[0] = 7'b1000000; // 0
        hex_patterns[1] = 7'b1111001; // 1
        hex_patterns[2] = 7'b0100100; // 2
        hex_patterns[3] = 7'b0110000; // 3
        hex_patterns[4] = 7'b0011001; // 4
        hex_patterns[5] = 7'b0010010; // 5
        hex_patterns[6] = 7'b0000010; // 6
        hex_patterns[7] = 7'b1111000; // 7
        hex_patterns[8] = 7'b0000000; // 8
        hex_patterns[9] = 7'b0010000; // 9
    end


    // game first run state
    initial begin
        game_state = RESET_STATE;

        for(int i = 0; i < 16; i++) begin
            red_rows[i] = 16'h0000; // hexadecimal
            green_rows[i] = 16'h0000;
        end

        p1_score = 0;
        p2_score = 0;
        paddle1_pos = 6;
        paddle2_pos = 6;

        ball_x = 8;
        ball_y = 8;

        ball_dir_x = 0;
        ball_dir_y = 0;

        refresh_counter = 0;
        game_counter = 0;
        current_row = 0;
    end

    always_ff @(posedge CLOCK_50) begin
        key_prev <= KEY;
        for(int i = 0; i < 4; i++) begin
            // key press transition
            key_pressed[i] <= (key_prev[i] == 1'b1) && (KEY[i] == 1'b0);
        end
    end

    always_ff @(posedge CLOCK_50) begin
        logic[23:0] current_game_speed;

        if(SW[9]) begin
            game_state <= RESET_STATE;

            p1_score <= 4'd0;
            p2_score <= 4'd0;

            paddle1_pos <= 4'd6;
            paddle2_pos <= 4'd6;

            ball_x <= 4'd8;
            ball_y <= 4'd8;

            ball_dir_x <= 1'b0;
            ball_dir_y <= 1'b0;

            game_counter <= 24'd0;
        end

        case (game_state)
            RESET_STATE: begin
                game_state <= PLAYING;
            end

            PLAYING: begin
                // moving up
                if(key_pressed[0] && paddle1_pos > 4'd0) begin
                    paddle1_pos <= paddle1_pos - 4'd1;
                end

                //moving down
                if(key_pressed[1] && paddle1_pos < (DISPLAY_HEIGHT - PADDLE_LENGTH)) begin
                    paddle1_pos <= paddle1_pos + 4'd1;
                end

                if (key_pressed[2] && paddle2_pos > 4'd0) begin
                    paddle2_pos <= paddle2_pos - 4'd1;
                end

                if(key_pressed[3] && paddle2_pos < (DISPLAY_HEIGHT - PADDLE_LENGTH)) begin
                    paddle2_pos <= paddle2_pos + 4'd1;
                end


                case(SW[8:7]) 
                    2'b00: current_game_speed = SPEED_NORMAL;
                    2'b01: current_game_speed = SPEED_FAST;
                    2'b10: current_game_speed = SPEED_FASTEST;
                    2'b11: current_game_speed = SPEED_SLOW;

                endcase

                if(SW[6]) begin
                    current_game_speed = SPEED_SLOW;
                end

                if(game_counter >= current_game_speed) begin
                    game_counter <= 24'd0;

                    // remember
                    // 0 = left/up

                    // 1 = right/down

                    // checking paddle collision
                    if(ball_dir_x == 0 && ball_x == 1 && ball_y >= paddle1_pos && ball_y < (paddle1_pos + PADDLE_LENGTH)) begin

                        // left paddle hit, bounce right
                        ball_dir_x <= 1'b1;
                        ball_x <= ball_x + 4'd1; // moving right

                        // make vertical movement with collision
                        if(ball_dir_y == 0 && ball_y > 0) begin
                            ball_y <= ball_y - 4'd1;
                        end

                        else if (ball_dir_y == 1 && ball_y < 15) begin
                            ball_y <= ball_y + 4'd1;
                        end

                    end

                    // right paddle collision
                    else if (ball_dir_x == 1 && ball_x == 14 && ball_y >= paddle2_pos && ball_y < (paddle2_pos + PADDLE_LENGTH)) begin
                        ball_dir_x <= 1'b0;
                        ball_x <= ball_x - 4'd1; // left movement

                        if(ball_dir_y == 0 && ball_y > 0) begin
                            ball_y <= ball_y - 4'd1;
                        end
                        else if (ball_dir_y == 1 && ball_y < 15) begin
                            ball_y <= ball_y + 4'd1;
                        end

                    end

                    else if (ball_dir_x == 0 && ball_x == 0) begin
                        p2_score <= p2_score + 4'd1;
                        ball_x <= 4'd8;
                        ball_y <= 4'd8;
                        ball_dir_x <= 1'b1; // reset to right

                        if(p2_score == MAX_SCORE - 1) begin
                            game_state <= GAME_OVER;
                        end


                    end

                    else if (ball_dir_x == 1 && ball_x == 15) begin
                        p1_score <= p1_score + 4'd1;
                        ball_x <= 4'd8;
                        ball_y <= 4'd8;
                        ball_dir_x <= 1'b0; // reset to left

                        if(p1_score == MAX_SCORE - 1) begin
                            game_state <= GAME_OVER;
                        end

                    end

                    else begin 
                        if(ball_dir_y == 0 && ball_y == 0) begin
                            // top wall collision
                            ball_dir_y <= 1'b1;
                            ball_y <= ball_y + 4'd1; // doown 

                            if(ball_dir_x == 0 && ball_x > 0) begin
                                ball_x <= ball_x - 4'd1;
                            end
                            else if(ball_dir_x == 1 && ball_x < 15) begin
                                ball_x <= ball_x + 4'd1;
                            end
                        end

                        else if (ball_dir_y == 1 && ball_y == 15) begin
                            // bottom wall
                            ball_dir_y <= 1'b0;
                            ball_y <= ball_y - 4'd1;

                            // continue horizontal movement
                            if(ball_dir_x == 0 && ball_x > 0) begin
                                ball_x <= ball_x - 4'd1;
                            end
                            else if(ball_dir_x == 1 && ball_x > 15) begin
                                ball_x <= ball_x + 4'd1;
                            end
                        end

                         else begin
                            // update both axes simultaneously
                            if (ball_dir_y == 0)
                                ball_y <= ball_y - 4'd1;
                            else
                                ball_y <= ball_y + 4'd1;
                                
                            if (ball_dir_x == 0)
                                ball_x <= ball_x - 4'd1;
                            else
                                ball_x <= ball_x + 4'd1;
                        end

                    end
                end
                else begin
                    game_counter <= game_counter + 24'd1;
                end
            end


            GAME_OVER: begin
                if (SW[9])
                    game_state <= RESET_STATE;
            end
        endcase 

        // display portion of project

        for(int row = 0; row < 16; row++) begin

            // row clearing
            red_rows[row] <= 16'h0000;
            green_rows[row] <= 16'h0000;

            // draw paddle 1 (left)
            if(row >= paddle1_pos && row < (paddle1_pos + PADDLE_LENGTH)) begin
                red_rows[row][0] <= 1'b1;
            end

            // draw paddle 2 (right)
            if(row >= paddle2_pos && row < (paddle2_pos + PADDLE_LENGTH)) begin
                red_rows[row][15] <= 1'b1;
            end

            // draw greeen ball 
            if(row == ball_y) begin
                green_rows[row][ball_x] <= 1'b1;
            end

            // game over 
            if(game_state == GAME_OVER) begin
                if(row==0 || row == 15) begin
                    red_rows[row] <= 16'hFFFF; // full row red
                    green_rows[row] <= 16'hFFFF;

                end

                else begin
                    red_rows[row][0] <= 1'b1; // left boarder
                    red_rows[row][15] <= 1'b1; // right boarder
                    green_rows[row][0] <= 1'b1; // left boarder
                    green_rows[row][15] <= 1'b1; // right boarder
                end
            end
        end

            // debug: write this on operational manual

            LEDR[9] <= (game_state == GAME_OVER);
            LEDR[8] <= (game_state == PLAYING);
            LEDR[7:6] <= SW[8:7]; // show selected speed
            LEDR[5] <= SW[6];     // show debug mode
            LEDR[3:0] <= p1_score;


    end // end of game logic always ff

    // display refresh logic 

    always_ff @(posedge CLOCK_50) begin
        if(refresh_counter >= REFRESH_RATE) begin
            refresh_counter <= 24'd0;


            if (current_row == 4'd15) begin
                current_row <= 4'd0; // reset to 0
            end

            else begin
                current_row <= current_row + 4'd1; // increment by 1
            end


        end
        else begin
            refresh_counter <= refresh_counter + 24'd1;
        end

        GPIO_1 <= 36'h0; // all pins cleared 

        GPIO_1[15:0] <= red_rows[current_row];

        GPIO_1[31:16] <= green_rows[current_row];

        GPIO_1[35:32] <= current_row;

    end

    assign HEX5 = hex_patterns[p1_score];  // Player 1 score
    assign HEX4 = 7'b0001100;             // "1"
    assign HEX3 = 7'b1111001;             // "P"
    
    assign HEX2 = 7'b0001100;             // "2"
    assign HEX1 = 7'b0100100;             // "P"
    assign HEX0 = hex_patterns[p2_score];  // Player 2 score

endmodule