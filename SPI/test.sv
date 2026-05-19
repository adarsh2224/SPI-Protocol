`timescale 1ns/1ps

module tb_spi_master;
    localparam int DATA_WIDTH = 8;
    localparam int CLK_DIV    = 4;

    logic                  clk;
    logic                  rst_n;
    logic                  start;
    logic [DATA_WIDTH-1:0] tx_data;
    logic [DATA_WIDTH-1:0] rx_data;
    logic                  busy;
    logic                  done;
    logic                  sclk;
    logic                  mosi;
    logic                  miso;
    logic                  cs_n;

    logic [DATA_WIDTH-1:0] slave_tx;
    logic [DATA_WIDTH-1:0] slave_rx;
    int                    slave_bit;

    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always @(negedge cs_n) begin
        slave_rx  = '0;
        slave_bit = DATA_WIDTH - 1;
        miso      = slave_tx[DATA_WIDTH-1];
    end

    always @(posedge sclk) begin
        if (!cs_n) begin
            slave_rx[slave_bit] = mosi;
        end
    end

    always @(negedge sclk) begin
        if (!cs_n && slave_bit > 0) begin
            slave_bit = slave_bit - 1;
            miso      = slave_tx[slave_bit];
        end
    end

    task automatic reset_dut;
        begin
            rst_n   = 1'b0;
            start   = 1'b0;
            tx_data = '0;
            slave_tx = '0;
            miso    = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic spi_transfer(
        input logic [DATA_WIDTH-1:0] master_data,
        input logic [DATA_WIDTH-1:0] slave_data
    );
        begin
            tx_data  = master_data;
            slave_tx = slave_data;

            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            wait (done);
            @(posedge clk);

            if (rx_data !== slave_data) begin
                $error("RX mismatch: expected 0x%0h, got 0x%0h", slave_data, rx_data);
            end

            if (slave_rx !== master_data) begin
                $error("Slave RX mismatch: expected 0x%0h, got 0x%0h", master_data, slave_rx);
            end

            if (cs_n !== 1'b1 || busy !== 1'b0) begin
                $error("Transfer did not return to idle cleanly: cs_n=%0b busy=%0b", cs_n, busy);
            end

            $display("PASS transfer: master_tx=0x%0h slave_tx=0x%0h", master_data, slave_data);
        end
    endtask

    initial begin
        $dumpfile("spi_master.vcd");
        $dumpvars(0, tb_spi_master);

        reset_dut();

        spi_transfer(8'hA5, 8'h3C);
        spi_transfer(8'h00, 8'hFF);
        spi_transfer(8'hF0, 8'h0F);

        $display("All SPI tests passed");
        $finish;
    end
endmodule
