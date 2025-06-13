`timescale 1ns / 1ps

module flight_recorder_tb;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 10;
    parameter MAX_STORAGE_ADDRESS = 1024;
    parameter CLK_PERIOD = 10;

    logic clk;
    logic rst;
    logic MODE_SELECT;
    logic RECORD_CMD;
    logic PLAYBACK_CMD;
    logic STOP_CMD;
    logic [DATA_WIDTH-1:0] sensor_din;
    logic GreenLED;
    logic BlueLED;
    logic RedLED;
    logic [DATA_WIDTH-1:0] data_out;
    logic data_out_valid;

    flight_recorder #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAX_STORAGE_ADDRESS(MAX_STORAGE_ADDRESS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .MODE_SELECT(MODE_SELECT),
        .RECORD_CMD(RECORD_CMD),
        .PLAYBACK_CMD(PLAYBACK_CMD),
        .STOP_CMD(STOP_CMD),
        .sensor_din(sensor_din),
        .GreenLED(GreenLED),
        .BlueLED(BlueLED),
        .RedLED(RedLED),
        .data_out(data_out),
        .data_out_valid(data_out_valid)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin
        $display("Starting Testbench...");
        rst = 1;
        RECORD_CMD = 0;
        PLAYBACK_CMD = 0;
        STOP_CMD = 0;
        MODE_SELECT = 0;
        sensor_din = 32'hAAAAAAAA;
        repeat (2) @(posedge clk);
        rst = 0;
        @ (posedge clk);
        $display("Reset released at time %t", $time);

        $display("Sending RECORD command at time %t", $time);
        RECORD_CMD = 1;
        @ (posedge clk);
        RECORD_CMD = 0;
        @ (posedge clk);
        if (dut.GreenLED !== 1'b1) $error("GreenLED should be ON during recording at %t", $time);
        if (dut.BlueLED !== 1'b0) $error("BlueLED should be OFF during recording at %t", $time);
        if (dut.RedLED !== 1'b0) $error("RedLED should be OFF during recording (not full/error) at %t", $time);

        $display("Recording data...");
        for (int i = 0; i < 10; i++) begin
            sensor_din = $urandom();
            @(posedge clk);
             if (dut.GreenLED !== 1'b1) $error("GreenLED went OFF during recording at %t", $time);
             $display("Time %t: Recording Cycle %d, WritePointer=%h, SensorData=%h", $time, i, dut.WritePointer, sensor_din);
        end
        $display("Finished recording initial data at %t. Expected WritePointer = %h", $time, 10);
        if (dut.WritePointer !== 10) $error("WritePointer mismatch after recording 10 items. Expected 10, got %h", dut.WritePointer);


        $display("Sending STOP command at time %t", $time);
        STOP_CMD = 1;
        @ (posedge clk);
        STOP_CMD = 0;
        @ (posedge clk);
        if (dut.GreenLED !== 1'b0) $error("GreenLED should be OFF after STOP at %t", $time);
        if (dut.BlueLED !== 1'b0) $error("BlueLED should be OFF after STOP at %t", $time);
        $display("EndOfRecordPointer latched to %h (Expected 10)", dut.EndOfRecordPointer);
         if (dut.EndOfRecordPointer !== 10) $error("EndOfRecordPointer mismatch. Expected 10, got %h", dut.EndOfRecordPointer);


        $display("Sending PLAYBACK command at time %t", $time);
        PLAYBACK_CMD = 1;
        @ (posedge clk);
        PLAYBACK_CMD = 0;
        @ (posedge clk);
        if (dut.BlueLED !== 1'b1) $error("BlueLED should be ON during playback at %t", $time);
        if (dut.GreenLED !== 1'b0) $error("GreenLED should be OFF during playback at %t", $time);
        if (dut.RedLED !== 1'b0) $error("RedLED should be OFF during playback (not full/error) at %t", $time);


        $display("Playing back data...");
        @ (posedge clk);
        for (int i = 0; i < 10; i++) begin
             if (dut.data_out_valid !== 1'b1) $error("data_out_valid should be HIGH during playback at %t, cycle %d", $time, i);
             $display("Time %t: Playback Cycle %d, ReadPointer=%h, Data Out=%h, Valid=%b", $time, i, dut.ReadPointer, dut.data_out, dut.data_out_valid);
             if (dut.BlueLED !== 1'b1) $error("BlueLED went OFF during playback at %t", $time);
             @ (posedge clk);
        end
         if (dut.ReadPointer != dut.EndOfRecordPointer) $error("ReadPointer (%h) did not reach EndOfRecordPointer (%h) at %t", dut.ReadPointer, dut.EndOfRecordPointer, $time);
         if (dut.PlaybackComplete !== 1'b1) $error("PlaybackComplete should be HIGH after reading all data at %t", $time);

        @ (posedge clk);
        $display("Playback finished, current state = %s at time %t", dut.current_state.name(), $time);
        if (dut.current_state != dut.IDLE) $error("Should be in IDLE state after playback completion at %t", $time);
        if (dut.BlueLED !== 1'b0) $error("BlueLED should be OFF after playback completion at %t", $time);
        if (dut.data_out_valid !== 1'b0) $error("data_out_valid should be LOW after playback completion at %t", $time);

        $display("Testing Memory Full condition...");
        RECORD_CMD = 1; @(posedge clk); RECORD_CMD = 0; @(posedge clk);
        STOP_CMD = 1; @(posedge clk); STOP_CMD = 0; @(posedge clk);
        RECORD_CMD = 1; @(posedge clk); RECORD_CMD = 0; @(posedge clk);

        if (dut.GreenLED !== 1'b1) $error("GreenLED should be ON for MemFull test at %t", $time);

        $display("Recording until memory is full (MAX_STORAGE_ADDRESS = %d)...", MAX_STORAGE_ADDRESS);
        for (int i = 0; i < MAX_STORAGE_ADDRESS ; i++) begin
             sensor_din = $urandom();
             @(posedge clk);
             if (dut.MemoryFull) begin
                 $display("MemoryFull asserted prematurely at WritePointer %h, time %t", dut.WritePointer, $time);
             end
             if(i == MAX_STORAGE_ADDRESS - 1) begin
                $display("Recorded last item at address %h, time %t", dut.WritePointer, $time);
             end
        end
         @ (posedge clk);

        $display("After filling memory: WritePointer = %h, MemoryFull = %b, RedLED = %b, State = %s", dut.WritePointer, dut.MemoryFull, dut.RedLED, dut.current_state.name());

        if (dut.WritePointer != MAX_STORAGE_ADDRESS) $error("WritePointer should be MAX_STORAGE_ADDRESS (%h) after filling memory, but is %h", MAX_STORAGE_ADDRESS, dut.WritePointer);
        if (!dut.MemoryFull) $error("MemoryFull flag should be HIGH at %t", $time);
        if (dut.RedLED !== 1'b1) $error("RedLED should be ON when MemoryFull at %t", $time);
        if (dut.current_state != dut.IDLE) $error("State should return to IDLE when MemoryFull at %t", $time);
        if (dut.GreenLED !== 1'b0) $error("GreenLED should turn OFF when MemoryFull forces state to IDLE at %t", $time);

        $display("Testbench finished at time %t", $time);
        $finish;
    end

     initial begin
         $monitor("Time=%t, Rst=%b, RecCmd=%b, PlayCmd=%b, StopCmd=%b, State=%s, WP=%h, RP=%h, EORP=%h, MemFull=%b, PlayComp=%b, Green=%b, Blue=%b, Red=%b, Dout=%h, Valid=%b",
                  $time, rst, RECORD_CMD, PLAYBACK_CMD, STOP_CMD, dut.current_state.name(), dut.WritePointer, dut.ReadPointer, dut.EndOfRecordPointer, dut.MemoryFull, dut.PlaybackComplete, GreenLED, BlueLED, RedLED, data_out, data_out_valid);
     end

endmodule
