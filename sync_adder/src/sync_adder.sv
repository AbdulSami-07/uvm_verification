module sync_adder
#(
    parameter DATA_WIDTH = 32
)
(
    input clk,
    input rst,
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,
    output [DATA_WIDTH:0] y
);
    reg [DATA_WIDTH:0] y_r = 'd0;

    always_ff @(posedge clk) begin
        if (rst) begin
            y_r <= 'd0;
        end
        else begin
            y_r <= a + b;
        end
    end

    assign y = y_r;
endmodule

interface sync_adder_if
#(
    parameter DATA_WIDTH = 32
)
();
    logic clk;
    logic rst;
    logic [DATA_WIDTH-1:0] a;
    logic [DATA_WIDTH-1:0] b;
    logic [DATA_WIDTH:0] y;
endinterface
