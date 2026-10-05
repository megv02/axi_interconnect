`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/19/2026 10:37:27 AM
// Design Name: 
// Module Name: dm_ram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// dm_ram.sv - Dual-port RAM used by the slave
module dm_ram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 256
)(
    input  logic                    clk,
    // Port A: Write
    input  logic                    we_a,
    input  logic [ADDR_WIDTH-1:0]  addr_a,
    input  logic [DATA_WIDTH-1:0]  wdata_a,
    // Port B: Read
    input  logic [ADDR_WIDTH-1:0]  addr_b,
    output logic [DATA_WIDTH-1:0]  rdata_b
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Initialize memory to zero
    initial begin
        for (int i = 0; i < DEPTH; i++)
            mem[i] = '0;
    end

    // Port A: Synchronous write
    always_ff @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= wdata_a;
    end

    // Port B: Synchronous read
    always_ff @(posedge clk) begin
        rdata_b <= mem[addr_b];
    end

endmodule