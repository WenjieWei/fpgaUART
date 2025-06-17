`timescale 1ns / 1ps

/**
 *  UART AXI Interface
 *  This module serves as an interface between the UART generator and AXI bus.
 *  It will handle the AXI transactions and connect to the UART generator.
 */
module uart_axi_interface#(
        parameter TDATA_WIDTH = 32,                 // Width of the data bus
        parameter NUM_BYTES = 4                     // Number of bytes in the AXI transaction
    )(
        input logic clk,                            // Clock input
        input logic arstn,                          // Reset input
        input logic tready,                         // AXI transaction ready signal

        output logic tvalid,                        // AXI transaction valid signal
        output logic [TDATA_WIDTH-1:0] tdata        // AXI data bus
    );

    // AXI output logic
    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            tvalid <= 1'b0;
            tdata <= '0;
        end else begin
            if (tready) begin                       // tready = uart_gen not busy
                // Generate a new transaction when ready
                tvalid <= 1'b1;
                // For demonstration, we will just increment the data
                tdata <= tdata + 1;
            end else begin
                tvalid <= 1'b0; // Not ready, so not valid
            end
        end
    end
endmodule
