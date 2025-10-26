`timescale 1ns / 1ps

module adder 
#(
    parameter DATA_WIDTH = 32 
)
(
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,

    output [DATA_WIDTH:0] y
);
    reg [DATA_WIDTH:0] y_r = 'd0;
    
    always @(*) begin
        y_r = a + b;
    end

    assign y = y_r;
endmodule

interface adder_if #(parameter DATA_WIDTH = 32)();
    logic [DATA_WIDTH-1:0] a;
    logic [DATA_WIDTH-1:0] b;
    logic [DATA_WIDTH:0] y;
endinterface
