# Verilog Flight Recorder

## Overview

This project is a simple digital "flight recorder" module implemented in Verilog. Its core function is to capture a stream of data, store it in an internal memory block, and play it back on command.

The module's operation is managed by a straightforward state machine that handles idle, recording, playback, and error conditions, with a clear set of LEDs for status indication.

## Features

*   **Record & Playback**: The module can be commanded to start recording an input data stream and later play back the stored contents.
*   **State Machine Control**: A four-state FSM (`IDLE`, `RECORDING`, `PLAYBACK`, `ERROR`) governs the module's logic, ensuring predictable and stable operation.
*   **Parameterized Design**: Key attributes like data width (`DATA_WIDTH`) and storage depth (`MAX_STORAGE_ADDRESS`) are defined as parameters for easy instantiation in different use cases.
*   **Command-Driven**: Operation is controlled via simple, single-cycle pulse commands (`RECORD_CMD`, `PLAYBACK_CMD`, `STOP_CMD`) for a clean interface.
*   **Status Indicators**: Three dedicated output signals (`GreenLED`, `BlueLED`, `RedLED`) provide an immediate visual status of the module's current state (e.g., recording, playback, memory full).

## Module Interface

### Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `DATA_WIDTH` | 32 | The bit width of the data bus. |
| `ADDR_WIDTH` | 10 | The bit width of the internal memory address bus. |
| `MAX_STORAGE_ADDRESS` | 1024 | The depth of the internal memory, defining how many samples can be recorded. |

### Ports

| Port | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | System clock. |
| `rst` | Input | 1 | Active-high synchronous reset. |
| `MODE_SELECT` | Input | 1 | **Reserved Port**. Not used in the current logic; intended for future expansion. |
| `RECORD_CMD` | Input | 1 | **Record Command**. A single high pulse triggers the recording state. |
| `PLAYBACK_CMD` | Input | 1 | **Playback Command**. A single high pulse triggers the playback state. |
| `STOP_CMD` | Input | 1 | **Stop Command**. A single high pulse will interrupt an ongoing record or playback operation. |
| `sensor_din` | Input | `DATA_WIDTH` | The external sensor data to be recorded. |
| `GreenLED` | Output | 1 | **Green LED**. Asserted high during the `RECORDING` state. |
| `BlueLED` | Output | 1 | **Blue LED**. Asserted high during the `PLAYBACK` state. |
| `RedLED` | Output | 1 | **Red LED**. Asserted high when the memory is full or an error condition occurs. |
| `data_out` | Output | `DATA_WIDTH` | The recorded data output during playback. |
| `data_out_valid`| Output | 1 | `data_out` valid signal. Asserted high during each cycle of a playback operation. |

## How It Works

The module is built around a simple finite state machine (FSM) with the following behavior:

1.  **IDLE**: The default and standby state. The module waits here for a `RECORD_CMD` or `PLAYBACK_CMD`.

2.  **RECORDING**:
    *   A `RECORD_CMD` pulse transitions the module from `IDLE` to this state, and the `GreenLED` is turned on.
    *   On each clock cycle, the module captures the data on `sensor_din` and writes it to the internal BRAM, incrementing the write pointer.
    *   The module returns to `IDLE` if it receives a `STOP_CMD` or if the memory becomes full. Upon exiting this state, it latches the total number of entries that were recorded.

3.  **PLAYBACK**:
    *   If data has been previously recorded, a `PLAYBACK_CMD` pulse in the `IDLE` state will initiate the playback sequence, lighting the `BlueLED`.
    *   The module outputs one recorded entry on `data_out` per clock cycle, with `data_out_valid` asserted high.
    *   The module automatically returns to `IDLE` once all recorded data has been played back or upon receiving a `STOP_CMD`.

4.  **ERROR**:
    *   This state is defined but the current design primarily uses the `RedLED` to indicate specific issues like memory full. The state itself is reserved for future, more complex error-handling logic.

## Simulation and Testing

A comprehensive testbench (`flight_recorder_tb.v`) is included to verify the module's functionality.

The test script covers the following key scenarios:
*   A standard **record -> stop -> playback** sequence.
*   Automatic return to `IDLE` state after playback completes.
*   A **memory full** condition to verify that recording stops and the `RedLED` is asserted correctly.
*   Correctness checks for all pointers and LED indicators in various states.

### How to Run the Simulation

1.  Add `flight_recorder.v` and `flight_recorder_tb.v` to your Verilog simulator (e.g., Vivado).
2.  Set `flight_recorder_tb` as the top-level module for the simulation.
3.  Run the simulation.
    *   The testbench includes a `$monitor` task that continuously prints the state of key signals to the console, making it easy to trace and debug the module's behavior.
