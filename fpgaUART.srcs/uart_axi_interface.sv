`timescale 1ns / 1ps

module uart_aix_interface #(
    parameter int TDATA_WIDTH = 16,
    parameter int NUM_BYTES = (TDATA_WIDTH + 7) / 8,
    parameter int CLK_FREQ = 100000000,                 // 100MHz clock
    parameter int BAUD_RATE = 9600                      // Chose 9600 as baud rate
)(
    input logic clk,                                    // Clock input
    input logic arstn,                                  // Reset input

    // Inputs from FFT
    input logic s_axis_tvalid,                          // Valid signal for AXI stream
    input logic [TDATA_WIDTH - 1:0] s_axis_tdata,       // Data input from AXI stream

    // Input from uart_gen
    input logic uart_busy,                              // UART busy signal
    input logic uart_tx_complete,                       // UART transmission complete signal

    // Outputs to uart_gen
    output logic [7:0] s_axis_data_output,              // Processed 8-bit data to be sent to UART
    output logic uart_start,                            // Start signal for UART transmission
    output logic s_axis_tready                          // Ready signal for AXI interface
);

// Define AXI statemachine
typedef enum logic [1:0] { IDLE, SEND_BYTE } state_t;
state_t state, next_state;

logic [$clog2(NUM_BYTES):0] byte_idx;

// Flag to indicate if a word has been sent, in case tvalid does not clear after the word is sent
logic word_sent; 

// Status register (including asynchronous reset)
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) state <= IDLE;
    else state <= next_state;
end

always_comb begin
    case (state)
        IDLE: 
            // tvalid indicates the upstream has a data word to send. 
            // need to consider if this is the previous already-sent word, or a new one.
            // If new word, start sending it. 
            // otherwise, wait until tvalid is cleared.
            if (s_axis_tvalid && !word_sent) 
                next_state = SEND_BYTE; // Transition to SEND_BYTE state
            else if (!s_axis_tvalid) begin
                next_state = IDLE; // Remain in IDLE state
                uart_start = 0; // Clear start signal
                byte_idx = 0; // Reset byte index
                word_sent = 0; // Reset word sent flag
            end

        SEND_BYTE:
            // UART busy = UART not in IDLE. 
            // tx_complete only happens during the last cycle of STOP state (still uart busy)            
            if (!uart_busy) begin
                // if uart is not busy, but we have come here from IDLE
                // that means we already have a new word to be sent. 
                // this will always be the first byte to be sent. 
                // so only need to issue uart_start and stay in this state
                next_state = SEND_BYTE;
                uart_start = 1;
            end 

            // if uart is busy but no tx_complete not detected, then we're still sending
            // if tx_complete is high, then we need to consider the following cases:
            // 1. do we have any more bytes to send? 
            //  if yes, increment byte index and stay in SEND_BYTE
            // 2. if not, return to IDLE. 
            // if tx_complete is low, consider below: 
            // 1. is this the first byte? 
            //  if yes, check s_axis_tvalid. if there's a valid data, start sending
            //  if not, return to IDLE
            else begin
                if (!uart_tx_complete) begin
                    next_state = SEND_BYTE; // Stay in SEND_BYTE state
                    uart_start = 0; // Reset the start signal once started
                end
                else begin
                    if (byte_idx < NUM_BYTES - 1) begin
                        byte_idx = byte_idx + 1; // Increment byte index
                        next_state = SEND_BYTE; // Continue sending next byte
                        uart_start = 1; // Set start signal for UART transmission
                    end else begin
                        next_state = IDLE; // All bytes sent, go back to IDLE
                        byte_idx = 0; // Reset byte index
                        uart_start = 0; // Clear start signal
                        word_sent = 1; // Indicate that a word has been sent
                    end
                end
            end
    endcase
end

// data output
always_comb begin
    case (state)
        IDLE: 
            s_axis_data_output = 8'b0; // No data to send in IDLE state
        SEND_BYTE:
            s_axis_data_output = s_axis_tdata[(byte_idx * 8) +: 8]; // Extract the byte to send
    endcase
end

assign s_axis_tready = (state == IDLE); // Ready to receive data when in IDLE state

endmodule
