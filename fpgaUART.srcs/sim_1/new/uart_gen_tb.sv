`timescale 1ns / 1ps
/**
 * UART Generator Testbench
 * This module serves as a testbench for the UART generator.
 * It will instantiate the uart_gen module and provide necessary signals.
 */

module uart_gen_tb;
    logic arstn, clk_uart;
    logic [7:0] data_in;
    logic start;
    logic tx_output, tx_busy;
    logic [7:0] data_out;
    // Instantiate the DUT (uart_gen)
    uart_gen dut (
        .clk(clk_uart),
        .arstn(arstn),
        .data_in(data_in),
        .start(start),
        .tx_output(tx_output),
        .tx_busy(tx_busy),
        .data_out(data_out)
    );

    // Generate 100MHz clock
    initial begin
        clk_uart = 0;
        forever begin
            #(5) clk_uart = ~clk_uart; // 100MHz clock period is 10ns
        end
    end

    // Initialization
    initial begin
        clk_uart = 0;
        arstn = 1;
        data_in = 8'h00; // Initialize data input
        start = 0; // Start signal is initially low

        // Toggle and clear reset after 20ns
        #5;
        arstn = 0;
        #15;
        arstn = 1;

        // Test case: Send a byte of data
        #10;
        data_in = 8'hA5; // Example data to send
        start = 1; // Assert start signal to begin transmission
        #10;
        start = 0; // Deassert start signal

        // Wait for transmission to complete
        wait(tx_busy == 0);
        
        // Check output data after transmission
        if (data_out == 8'hA5) begin
            $display("Test passed: Data transmitted correctly.");
        end else begin
            $display("Test failed: Expected 8'hA5, got %h", data_out);
        end

        // End simulation after some time
        #100 $finish;
    end
endmodule
