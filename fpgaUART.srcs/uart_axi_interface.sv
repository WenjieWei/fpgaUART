`timescale 1ns / 1ps

/**
 *  UART AXI Interface
 *  This module serves as an interface between the UART generator and AXI bus.
 *  It will handle the AXI transactions and connect to the UART generator.
 */
 /*
module uart_axi_interface#(
        parameter TDATA_WIDTH = 16,                 // Width of the data bus
        parameter NUM_WORD = 4                      // Number of words can be stored in buffer
    )(
        input logic clk,                            // Clock input
        input logic arstn,                          // Reset input
        input logic tready_in,                      // AXI transaction ready signal
        input logic tvalid_in,                      // AXI transaction valid signal
        input logic [TDATA_WIDTH-1:0] tdata_in,     // AXI data input

        output logic tvalid,                        // AXI transaction valid signal
        output logic tready_out,                    // AXI transaction ready output signal
        output logic [TDATA_WIDTH-1:0] tdata_out    // AXI data bus
        output logic buffer_ready                   // Buffer ready signal    
    );

    // AXI buffer logic
    logic [TDATA_WIDTH-1:0] buffer;                 // Buffer to hold AXI data
    logic buffer_valid;                             // Buffer valid = true when the buffer is full
    assign buffer_ready = !buffer_valid;            // Buffer is ready to accept new data when not valid

    // AXI output logic
    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            tvalid <= 1'b0;
            tready_out <= 1'b0;
            tdata <= '0;
        end else begin
            if (tready_in)                             // tready = uart_gen not busy

        end
    end
endmodule

/**
 *  Handler to process received data from AXI and packet them into 8-bit UART packets.
 *  For now, it will only handle 16-bit data. 
 */
 /*
module uart_packet_handler #(
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

// Logic to partition the data packet from AXI into 8-bit packets for UART transmission
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        uart_data <= '0;
        start <= 1'b0;
    end else begin
        if (axi_valid && axi_ready) begin
            // Assuming we are only handling 16-bit data for now
            uart_data <= axi_data[7:0]; // Take the lower byte for UART transmission
            start <= 1'b1; // Signal to start UART transmission
        end else begin
            start <= 1'b0; // No data to send, reset start signal
        end
    end
end
endmodule
*/