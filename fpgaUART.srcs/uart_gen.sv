`timescale 1ns / 1ps

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
    output var logic tx_complete,       // Transmission complete signal
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
uart_state_t state;

//assign tx_complete = (state == STOP);
// State transition logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        state <= IDLE; // Reset to IDLE state
        data_out <= 8'b0; // Clear output data on reset
        tx_complete <= 1'b0; // Clear transmission complete flag
    end else begin
        case (state)
            IDLE: 
                if (start) begin
                    state <= START; // Transition to START state on start signal
                    tx_complete <= 1'b0; // Indicate transmission is complete
                end
            START:
                if (baud_tick) state <= DATA; // Transition to DATA state after start bit
            DATA: 
                if (bit_counter == 4'd7 && baud_tick)
                    state <= STOP; // If all 8 bits are sent, transition to STOP
                else if (baud_tick)
                    state <= DATA; // Remain in DATA state until all bits are sent
            STOP:           
                if (baud_tick) begin
                    state <= IDLE; // Transition back to IDLE after stop bit
                    data_out <= tx_shift_reg; // Output the transmitted data
                    tx_complete <= 1'b1; // Set transmission complete flag
                end

            default:  
                state <= IDLE; // Default case to handle unexpected states
        endcase
    end
end

// TX output logic
always_comb begin
    case (state)
        IDLE:  tx_output = 1'b1;
        START: tx_output = 1'b0;
        DATA:  tx_output = tx_shift_reg[0];
        STOP:  tx_output = 1'b1;
    endcase
end

// Baud tick generation logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        baud_counter <= 0;
        baud_tick <= 1'b0; // No tick on reset
    end else if (state != IDLE) begin
        if (baud_counter == BAUD_PERIOD - 1) begin
            baud_counter <= 0;
            baud_tick <= 1'b1; // Generate tick signal
        end else begin
            baud_counter <= baud_counter + 1;
            baud_tick <= 1'b0; // No tick signal until counter reaches period
        end
    end else begin
        baud_counter <= 0; // Reset counter when not busy
        baud_tick <= 1'b0; // No tick signal when not busy
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
    else if (state == START)
        tx_shift_reg <= data_in;                    // Load data with start bit
    else if (state == DATA && baud_tick)
        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};  // Shift right for next bit
end

// Busy flag logic
always_comb begin
    if (!arstn)
        tx_busy = 1'b0; // Not busy on reset
    else
        tx_busy = (state != IDLE); // Busy if not in IDLE state
end
endmodule
/*
module uart_packet_partition #(
        parameter TDATA_WIDTH = 16,                 // Width of the data bus
        parameter UART_PACKET_SIZE = 8              // Size of the UART packet
    )(
        // System ports
        input logic clk,                            // Clock input
        input logic arstn,                          // Reset input

        // Inputs from UART generator
        input logic uart_ready,                     // UART ready signal

        // Inputs from AXI interface 
        input logic axi_valid,                      // AXI valid signal from AXI interface
        input logic axi_ready,                      // AXI ready signal from AXI interface
        input logic [TDATA_WIDTH-1:0] axi_data,     // Data input from AXI interface
        
        // Outputs
        output logic [7:0] uart_data,               // Data output to UART generator
        output logic start                          // Start signal for UART transmission
    );

// Internal signals
parameter int UART_PACKETS = TDATA_WIDTH / UART_PACKET_SIZE; // Number of 8-bit packets in the AXI data 
logic [TDATA_WIDTH-1:0] data_buffer;                // Buffer to hold the AXI data
logic [$clog2(UART_PACKETS):0] packet_count;        // Counter for the number of packets sent
logic [7:0] packet_buffer;                          // Buffer to hold the current 8-bit packet
logic data_partition_complete;                      // Flag to indicate if the data partitioning is complete
logic data_loaded;                                  // Flag to indicate if data has been loaded into the buffer

// Logic to partition the data packet from AXI into 8-bit packets for UART transmission
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        data_buffer <= 'd0; // Clear the data buffer on reset
        packet_count <= 'd0; // Reset packet count
        packet_buffer <= 'd0; // Clear packet buffer
        data_partition_complete <= 1'b0; // Clear partition complete flag
        data_loaded <= 1'b0; // Clear data loaded flag
    end else begin
        if (!data_loaded) begin
            data_buffer <= axi_data; // Load data from AXI interface
            data_loaded <= 1'b1; // Set data loaded flag
        end 
        else if (!data_partition_complete && data_loaded && uart_ready) begin
            packet_buffer <= data_buffer[UART_PACKET_SIZE-1:0]; // Get the first 8 bits
            uart_data <= packet_buffer; // Output the 8-bit packet to UART generator
            data_buffer <= data_buffer >> UART_PACKET_SIZE; // Shift the buffer to get the next packet
            packet_count <= packet_count + 1; // Increment the packet count
            if (packet_count == UART_PACKETS - 1) 
                data_partition_complete <= 1'b1; // Set partition complete flag when all packets are sent
            start <= 1'b1; // Set start signal for UART transmission
        end
    end
end
endmodule
*/