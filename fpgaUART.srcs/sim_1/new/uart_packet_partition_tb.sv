`timescale 1ns / 1ps

/**
 * UART Packet Partition Testbench
 * This module serves as a testbench for the UART packet partitioning logic.
 * It will instantiate the uart_packet_partition module and provide necessary signals.
 */

module uart_packet_partition_tb;
    logic clk, arstn;
    logic uart_ready;
    logic axi_valid, axi_ready;
    logic [15:0] axi_data; // 16-bit AXI data input
    logic [7:0] uart_data; // 8-bit UART data output
    logic start;           // Start signal for UART transmission

    // Instantiate the DUT (uart_packet_partition)
    uart_packet_partition dut (
        .clk(clk),
        .arstn(arstn),
        .uart_ready(uart_ready),
        .axi_valid(axi_valid),
        .axi_ready(axi_ready),
        .axi_data(axi_data),
        .uart_data(uart_data),
        .start(start)
    );

    // Generate clock signal
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Testbench stimulus
    initial begin
        arstn = 0;
        uart_ready = 1;
        axi_valid = 0;
        axi_ready = 1;
        axi_data = 16'hA74B; // Example AXI data

        // Reset the DUT
        #10 arstn = 1;

        // Send AXI data
        #10 axi_valid = 1;

        // Wait for partitioning to complete
        #100;

        $finish; // End simulation
    end

endmodule
