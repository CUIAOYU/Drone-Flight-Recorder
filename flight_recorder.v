module flight_recorder #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter MAX_STORAGE_ADDRESS = 1024
) (
    input wire clk,
    input wire rst,
    input wire MODE_SELECT,
    input wire RECORD_CMD,
    input wire PLAYBACK_CMD,
    input wire STOP_CMD,
    input wire [DATA_WIDTH-1:0] sensor_din,
    output logic GreenLED,
    output logic BlueLED,
    output logic RedLED,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic data_out_valid
);

    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        RECORDING= 2'b01,
        PLAYBACK = 2'b10,
        ERROR    = 2'b11
    } state_t;

    state_t current_state, next_state;
    logic IsRecording;
    logic IsPlayback;
    logic ErrorState;

    logic [DATA_WIDTH-1:0] memory [0:MAX_STORAGE_ADDRESS-1];
    logic [ADDR_WIDTH-1:0] WritePointer;
    logic [ADDR_WIDTH-1:0] ReadPointer;
    logic [ADDR_WIDTH-1:0] EndOfRecordPointer;

    logic MemoryFull;
    logic PlaybackComplete_Condition;
    logic PlaybackComplete;

    logic WriteEnable;
    logic ReadEnable;
    logic TimestampIncEnable;
    logic WritePointerInc;
    logic ReadPointerInc;
    logic TimestampReset;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            WritePointer <= '0;
            ReadPointer <= '0;
            EndOfRecordPointer <= '0;
            ErrorState <= 1'b0;
        end else begin
            current_state <= next_state;
            ErrorState <= 1'b0; // Default: clear error unless set below

            // Pointer logic is now fully inside the sequential block
            case(next_state)
                RECORDING: begin
                    if (current_state != RECORDING) begin // Entering RECORDING state
                        WritePointer <= '0; // Reset WritePointer on state entry
                    end else if (WriteEnable) begin
                        WritePointer <= WritePointer + 1; // Increment during recording
                    end
                    // ReadPointer remains unchanged or resets depending on desired behavior
                    // ReadPointer <= ReadPointer; // Hold value
                end
                PLAYBACK: begin
                     if (current_state != PLAYBACK) begin // Entering PLAYBACK state
                         ReadPointer <= '0; // Reset ReadPointer on state entry
                     end else if (ReadEnable) begin
                         ReadPointer <= ReadPointer + 1; // Increment during playback
                     end
                     // WritePointer remains unchanged
                     // WritePointer <= WritePointer; // Hold value
                end
                IDLE: begin
                    // Optionally reset pointers when entering IDLE, or hold last value
                    // WritePointer <= '0;
                    // ReadPointer <= '0;
                    ErrorState <= 1'b0; // Ensure error is cleared in IDLE
                end
                ERROR: begin
                    // Hold pointers in ERROR state
                    // WritePointer <= WritePointer;
                    // ReadPointer <= ReadPointer;
                    ErrorState <= 1'b1; // Set error flag if ERROR state is used explicitly
                end
                default: begin
                    // Default case, potentially reset pointers
                    WritePointer <= '0;
                    ReadPointer <= '0;
                end
            endcase


            // Latch EndOfRecordPointer when recording stops (moving from RECORDING to another state)
            if (current_state == RECORDING && next_state != RECORDING) begin
                 EndOfRecordPointer <= WritePointer;
            end

             // Example Error Condition (can be expanded)
             // if (some_error_condition && next_state != ERROR) begin
             //    ErrorState <= 1'b1; // Set error flag based on condition
             // end

        end
    end

    // Combinational logic for next state calculation remains the same
    always_comb begin
        next_state = current_state;
            case (current_state)
                IDLE: begin
                    if (RECORD_CMD) begin
                        next_state = RECORDING;
                        // DO NOT assign pointers here
                    end else if (PLAYBACK_CMD) begin
                        if (EndOfRecordPointer > 0) begin
                           next_state = PLAYBACK;
                           // DO NOT assign pointers here
                        end else begin
                        end
                    end
                end
                RECORDING: begin
                    if (STOP_CMD) begin
                        next_state = IDLE;
                    end else if (MemoryFull) begin
                         next_state = IDLE;
                    end
                end
                PLAYBACK: begin
                    if (STOP_CMD) begin
                        next_state = IDLE;
                    end else if (PlaybackComplete) begin
                        next_state = IDLE;
                    end
                end
                ERROR: begin
                    if (STOP_CMD) begin
                        next_state = IDLE;
                    end
                end
                default: next_state = IDLE;
            endcase
    end

    assign IsRecording = (current_state == RECORDING);
    assign IsPlayback = (current_state == PLAYBACK);

    assign MemoryFull = (WritePointer == MAX_STORAGE_ADDRESS);

    assign PlaybackComplete_Condition = (ReadPointer >= EndOfRecordPointer);
    assign PlaybackComplete = PlaybackComplete_Condition && (EndOfRecordPointer > 0) ;

    assign WriteEnable = IsRecording && !MemoryFull;

    assign ReadEnable = IsPlayback && !PlaybackComplete;

    assign TimestampIncEnable = IsRecording;
    assign TimestampReset = rst;

    // These are just wires now, not driving registers
    assign WritePointerInc = WriteEnable;
    assign ReadPointerInc = ReadEnable;

    assign GreenLED = IsRecording;
    assign BlueLED = IsPlayback;
    assign RedLED = MemoryFull || (current_state == ERROR) || ErrorState;

    always_ff @(posedge clk) begin
        if (WriteEnable) begin
            memory[WritePointer] <= sensor_din;
        end
    end

    logic [DATA_WIDTH-1:0] data_out_comb;
    assign data_out_comb = memory[ReadPointer];

    always_ff @(posedge clk) begin
        if (rst) begin
            data_out <= '0;
            data_out_valid <= 1'b0;
        end else if (ReadEnable) begin
            data_out <= data_out_comb;
            data_out_valid <= 1'b1;
        end else begin
            data_out_valid <= 1'b0;
        end
    end

endmodule
