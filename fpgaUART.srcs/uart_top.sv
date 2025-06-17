`timescale 1ns / 1ps

// This module is the top-level module for the UART design. 
module uart_top(

    );
endmodule

module uart_gen #(
    parameter CLK_FREQ = 100000000,     // 100MHz clock
    parameter BAUD_RATE = 9600          // Chose 9600 as the most common baud rate
)(
    input var logic clk,                // Clock input
    input var logic arstn,              // Reset input
    input var logic [7:0] data_in,      // Data input
    input var logic start,              // Start signal for transmission

    output var logic tx_output,         // Transmit output
    output var logic tx_busy,           // Transmission busy signal
    output var logic [7:0] data_out     // Data output
);

// UART baud rate generator
// Internal parameters for baud rate generation and couunters
localparam int BAUD_PERIOD = CLK_FREQ / BAUD_RATE;
logic [15:0] baud_counter; // Counter for baud rate generation
logic [3:0] bit_counter; // Counter for the number of bits transmitted
logic [7:0] tx_shift_reg; // Shift register for data transmission
logic baud_tick; // Baud tick signal, indicating when to sample the next bit when 1

// UART FSM definition
typedef enum logic [1:0] {
    IDLE, START, DATA, STOP
} uart_state_t;
uart_state_t state, state_next;

// State transition logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        state <= IDLE;
    end else begin
        state <= state_next;
    end
end

// State machine next state logic
always_comb begin
    state_next = state;
    case (state)
        IDLE: state_next = (start) ? START : IDLE;        
        START: state_next = (baud_tick) ? DATA : START;        
        DATA: state_next = (bit_counter == 4'd7 && baud_tick) ? STOP : DATA;        
        STOP: state_next = (baud_tick) ? IDLE : STOP;
        default: state_next = IDLE; // Default case to handle unexpected states   
    endcase
end

// Baud tick generation logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        baud_counter <= 0;
        baud_tick <= 1'b0; // No tick on reset
    end else begin
        if (baud_counter < BAUD_PERIOD - 1) begin
            baud_counter <= baud_counter + 1;
            baud_tick <= 1'b0; // No tick until counter reaches period
        end else begin
            baud_counter <= 0; // Reset counter after reaching period
            baud_tick <= 1'b1; // Generate tick signal
        end
    end
end

// Bit counter and baud rate counter logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn)
        bit_counter <= 0;  
    else if (baud_tick) begin
        if (state == DATA)
            bit_counter <= bit_counter + 1;
        else
            bit_counter <= 0; // Reset bit counter in other states
    end
end

// Shift register logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn)
        tx_shift_reg <= 0;
    else if (state == START && baud_tick)
        tx_shift_reg <= data_in;                    // Load data with start bit
    else if (state == DATA && baud_tick)
        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};  // Shift left for next bit
end

// TX output logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) tx_output <= 1'b1; // Idle state is high
    else if (baud_tick) begin
        case (state)
            START: tx_output <= 1'b0; // Start bit is low
            DATA: tx_output <= tx_shift_reg[0]; // Transmit current bit
            STOP: tx_output <= 1'b1; // Stop bit is high
            default: tx_output <= 1'b1; // Default to idle state
        endcase
    end
end

// Busy flag logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn)
        tx_busy <= 1'b0; // Not busy on reset
    else
        tx_busy <= (state != IDLE); // Busy if not in IDLE state
end
endmodule