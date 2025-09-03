`timescale 1ns / 1ps

module tb_mac;

    // Testbench Variables
    reg [31:0] In1, In2;      // Inputs to MAC unit
    reg CLK, rst;             // Clock and Reset
    wire [31:0] MacOut;       // Output of MAC unit

    // Instantiate the MAC Unit
    mac uut (
        .In1(In1),
        .In2(In2),
        .CLK(CLK),
        .rst(rst),
        .MacOut(MacOut)
    );

    // Clock Generation
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK; // Clock with a period of 10ns
    end

    // Test Vectors
    initial begin
        // Enable waveform dumping
        $dumpfile("mac_tb.vcd"); // Dump to "mac_tb.vcd" for GTKWave
        $dumpvars(0, tb_mac);    // Dump all variables in this testbench

        // Initialize Inputs
        In1 = 32'b0;
        In2 = 32'b0;
        rst = 0;

        //   reset
        #10;
        rst = 1;

        // Test Case 1: Multiply 1.5 * 2.5 and accumulate
        In1 = 32'b00111111110000000000000000000000; // 1.5 in IEEE 754
        In2 = 32'b01000000001000000000000000000000; // 2.5 in IEEE 754
        #10;
        $display("Test 1: Time = %0t | In1 = %h | In2 = %h | MacOut = %h", 
                 $time, In1, In2, MacOut);

        // Test Case 2: Multiply 0.5 * -4.0 and accumulate
        In1 = 32'b00111111000000000000000000000000; // 0.5 in IEEE 754
        In2 = 32'b11000000100000000000000000000000; // -4.0 in IEEE 754
        #10;
        $display("Test 2: Time = %0t | In1 = %h | In2 = %h | MacOut = %h", 
                 $time, In1, In2, MacOut);

        // Test Case 3: Multiply 10.0 * 0.1 and accumulate
        In1 = 32'b01000001001010000000000000000000; // 10.0 in IEEE 754
        In2 = 32'b00111101110011001100110011001101; // 0.1 in IEEE 754
        #10;
        $display("Test 3: Time = %0t | In1 = %h | In2 = %h | MacOut = %h", 
                 $time, In1, In2, MacOut);

        // Test Case 4: Reset the MAC Unit
        rst = 0;
        #10;
        rst = 1;
        $display("Test 4: Time = %0t | Reset Applied | MacOut = %h", 
                 $time, MacOut);

        // Test Case 5: Multiply 7.0 * 3.0 and accumulate
        In1 = 32'b01000000111000000000000000000000; // 7.0 in IEEE 754
        In2 = 32'b01000000010000000000000000000000; // 3.0 in IEEE 754
        #10;
        $display("Test 5: Time = %0t | In1 = %h | In2 = %h | MacOut = %h", 
                 $time, In1, In2, MacOut);

        // End Simulation
        $finish;
    end

    // Monitor Outputs
    initial begin
        $monitor("Time = %0t | In1 = %h | In2 = %h | MacOut = %h | rst = %b", 
                 $time, In1, In2, MacOut, rst);
    end

endmodule
