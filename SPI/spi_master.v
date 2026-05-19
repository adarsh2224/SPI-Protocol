`timescale 1ns/1ps

module spi_master #(
    parameter integer DATA_WIDTH = 8,
    parameter integer CLK_DIV    = 4
) (
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] tx_data,
    output reg  [DATA_WIDTH-1:0] rx_data,
    output reg                   busy,
    output reg                   done,

    output reg                   sclk,
    output reg                   mosi,
    input  wire                  miso,
    output reg                   cs_n
);

    localparam integer DIV_WIDTH = (CLK_DIV <= 2) ? 1 : $clog2(CLK_DIV);
    localparam integer CNT_WIDTH = (DATA_WIDTH <= 2) ? 1 : $clog2(DATA_WIDTH);

    reg [DATA_WIDTH-1:0] tx_shift;
    reg [DATA_WIDTH-1:0] rx_shift;
    reg [CNT_WIDTH:0]    bit_count;
    reg [DIV_WIDTH-1:0]  clk_count;

    wire div_tick = (clk_count == CLK_DIV - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data   <= {DATA_WIDTH{1'b0}};
            busy      <= 1'b0;
            done      <= 1'b0;
            sclk      <= 1'b0;
            mosi      <= 1'b0;
            cs_n      <= 1'b1;
            tx_shift  <= {DATA_WIDTH{1'b0}};
            rx_shift  <= {DATA_WIDTH{1'b0}};
            bit_count <= {CNT_WIDTH+1{1'b0}};
            clk_count <= {DIV_WIDTH{1'b0}};
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                busy      <= 1'b1;
                cs_n      <= 1'b0;
                sclk      <= 1'b0;
                tx_shift  <= tx_data;
                rx_shift  <= {DATA_WIDTH{1'b0}};
                bit_count <= DATA_WIDTH;
                clk_count <= {DIV_WIDTH{1'b0}};
                mosi      <= tx_data[DATA_WIDTH-1];
            end else if (busy) begin
                if (div_tick) begin
                    clk_count <= {DIV_WIDTH{1'b0}};
                    sclk      <= ~sclk;

                    if (!sclk) begin
                        rx_shift  <= {rx_shift[DATA_WIDTH-2:0], miso};
                        bit_count <= bit_count - 1'b1;
                    end else begin
                        tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};

                        if (bit_count == 0) begin
                            busy    <= 1'b0;
                            done    <= 1'b1;
                            cs_n    <= 1'b1;
                            sclk    <= 1'b0;
                            mosi    <= 1'b0;
                            rx_data <= rx_shift;
                        end else begin
                            mosi <= tx_shift[DATA_WIDTH-2];
                        end
                    end
                end else begin
                    clk_count <= clk_count + 1'b1;
                end
            end
        end
    end

endmodule
