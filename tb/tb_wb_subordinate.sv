`timescale 1ns/1ps

module tb_wb_subordinate ();

    logic clk;
    logic rst;

    logic[31:0] wb_address;
    logic[31:0] write_data;
    logic[31:0] read_data;

    logic cycle;
    logic strobe;
    logic write_read_n;
    logic[3:0] select;
    logic stall;
    logic ack;

    parameter ADDRESS = 'h4000_0000;
    parameter WRONG_ADDRESS = 'h4001_0000;

    parameter VERSION = 'hAAAAAAAA;
    parameter DEVICE_ID = 'h12345678;

    logic[31:0] irq;
    logic[15:0] ip_addr;
    logic[31:0] ip_rdata, ip_wdata;
    logic write_enable, read_enable;

    initial
        $timeformat(-9, 0, " ns", 10);

    wb_subordinate_interface #(.WB_BASE_ADDRESS(ADDRESS),
                               .IP_VERSION(VERSION),
                               .IP_DEVICE_ID(DEVICE_ID)) DUT (
                                 .i_wb_clk(clk),
                                 .i_wb_rst(rst),

                                 // Wishbone data signals
                                 .i_wb_addr(wb_address),
                                 .i_wb_dat(write_data),
                                 .o_wb_dat(read_data),

                                 // Wishbone control signals
                                 .i_wb_cyc(cycle),
                                 .i_wb_stb(strobe),
                                 .i_wb_we(write_read_n),
                                 .i_wb_sel(select),
                                 .o_wb_stall(stall),
                                 .o_wb_ack(ack),

                                 // IP data signals
                                 .o_ip_address(ip_addr),
                                 .i_ip_rdata(ip_rdata),
                                 .o_ip_wdata(ip_wdata),

                                 // IP control signals
                                 .o_ip_read_en(read_enable),
                                 .o_ip_write_en(write_enable),
                                 .i_ip_ack(1'b0),
                                 .i_ip_stall(1'b0),

                                 // Interface Standard registers
                                 .o_ip_control(),
                                 .i_ip_status(32'hDEADBEEF),
                                 // o_ip_irq_mask,
                                 .i_ip_irq(irq)
                             );

    initial
    begin
        wb_address = 0;
        write_data = 0;
        cycle = 0;
        strobe = 0;
        write_read_n = 0;
        clk = 0;
        rst = 1;
        # 20 rst = 0;
    end

    initial
        irq = 0;

    always
        #10 clk = ~clk;

    task wb_write_single(input[31:0] address, input[3:0] sel, input[31:0] data, input valid_address = 1, input ip_reg = 0);
        #200;
        @(posedge clk);
        // Clock Edge 0
        // MASTER presents a valid address on [ADR_O()]
        wb_address = address;
        // MASTER presents valid data on [DAT_O()]
        write_data = data;
        // MASTER asserts [WE_O] to indicate a WRITE cycle.
        write_read_n = 1'b1;
        // MASTER presents bank select [SEL_O()]
        select = sel;
        // MASTER asserts [CYC_O]
        cycle = 1'b1;
        // MASTER asserts [STB_O]
        strobe = 1'b1;

        @(posedge clk);
        //Clock Edge 1
        strobe = 0;
        if(ip_reg)
        begin
            if(valid_address)
            begin
                if(!write_enable)
                    $display("ERROR: %t Expected o_ip_write_en to be high", $time);
                if(address[15:0] != ip_addr)
                    $display("ERROR: %t Expected to o_ip_address %x but got %x", $time, address[15:0], ip_addr);
                if(valid_address && data != ip_wdata)
                    $display("ERROR: %t Expected to o_ip_wdata %x but got %x", $time, data, ip_wdata);
            end
        end

        @(posedge clk);
        //Clock Edge 2
        cycle = 0;
        @(posedge clk);

    endtask

    task wb_read_single(input[31:0] address, input[3:0] sel, input[31:0] expected_data, input valid_address = 1, input ip_reg = 0);
        #200;
        @(posedge clk);
        // Clock Edge 0
        // MASTER presents a valid address on [ADR_O()]
        wb_address = address;
        // MASTER negates [WE_O]
        write_read_n = 1'b0;
        // MASTER presents bank select [SEL_O()]
        select = sel;
        // MASTER asserts [CYC_O]
        cycle = 1'b1;
        // MASTER asserts [STB_O]
        strobe = 1'b1;

        @(posedge clk);
        // Clock Edge 1
        strobe = 1'b0;
        if(ip_reg)
        begin
            if(valid_address)
            begin
                if(!read_enable)
                    $display("ERROR: %t Expected o_ip_read_en to be high", $time);
                if(address[15:0] != ip_addr)
                    $display("ERROR: %t Expected to o_ip_address %x but got %x", $time, address[15:0], ip_addr);
                ip_rdata = expected_data;
            end
        end

        @(posedge clk);
        // Clock Edge 2
        cycle = 0;

        if(valid_address && expected_data != read_data)
            $display("ERROR: %t Expected to read %x but got %x at address 0x%x", $time, expected_data, read_data, address);

        @(posedge clk);
    endtask

    // Operates as a FIFO write, needs to in IP register region to work
    task wb_write_block(input[31:0] base_address, input[3:0] sel, input[31:0] data);
        logic [31:0] local_data;
        local_data = data;
        #200;

        @(posedge clk);
        // Clock Edge 0
        wb_address = base_address;
        write_data = local_data;
        write_read_n = 1'b1;
        select = sel;
        cycle = 1'b1;
        strobe = 1'b1;


        // Clock Edge 1
        @(posedge clk);
        if(ip_wdata != local_data)
            $display("ERROR: %t Expected to o_ip_wdata %x but got %x", $time, data, ip_wdata);
        local_data = {local_data[23:0], local_data[31:24]};
        write_data = local_data;


        // Clock Edge 2
        @(posedge clk);
        if(ip_wdata != local_data)
            $display("ERROR: %t Expected to o_ip_wdata %x but got %x", $time, data, ip_wdata);
        local_data = {local_data[23:0], local_data[31:24]};
        write_data = local_data;


        // Clock Edge 3
        @(posedge clk);
        if(ip_wdata != local_data)
            $display("ERROR: %t Expected to o_ip_wdata %x but got %x", $time, data, ip_wdata);
        local_data = {local_data[23:0], local_data[31:24]};
        write_data = local_data;


        // Clock Edge 4
        @(posedge clk);
        if(ip_wdata != local_data)
            $display("ERROR: %t Expected to o_ip_wdata %x but got %x", $time, data, ip_wdata);
        strobe = 1'b0;

        // Clock Edge 5
        @(posedge clk);
        cycle = 1'b0;


    endtask

    // Operates as a FIFO read, needs to in IP register region to work
    task wb_read_block(input[31:0] base_address, input[3:0] sel, input[31:0] expected_data);
        logic [31:0] data;
        data = expected_data;
        #200;
        @(posedge clk);
        // Clock Edge 0
        wb_address = base_address;
        write_read_n = 1'b0;
        select = sel;
        cycle = 1'b1;
        strobe = 1'b1;


        // Clock Edge 1
        @(posedge clk);
        ip_rdata = data;
        data = {data[23:0], data[31:24]};

        // Clock Edge 2
        @(posedge clk);
        if(ip_rdata != read_data)
            $display("ERROR: %t Expected to read %x but got %x", $time, ip_rdata, read_data);
        ip_rdata = data;
        data = {data[23:0], data[31:24]};

        // Clock Edge 3
        @(posedge clk);
        if(ip_rdata != read_data)
            $display("ERROR: %t Expected to read %x but got %x", $time, ip_rdata, read_data);
        ip_rdata = data;
        data = {data[23:0], data[31:24]};

        // Clock Edge 4
        @(posedge clk);
        if(ip_rdata != read_data)
            $display("ERROR: %t Expected to read %x but got %x", $time, ip_rdata, read_data);
        ip_rdata = data;
        data = {data[23:0], data[31:24]};

        // Clock Edge 5
        @(posedge clk);
        if(ip_rdata != read_data)
            $display("ERROR: %t Expected to read %x but got %x", $time, ip_rdata, read_data);
        strobe = 1'b0;

        // Clock Edge 6
        cycle = 1'b0;
    endtask

    task set_irq(input[31:0] irqvalue);
        @(negedge clk);
        irq = irqvalue;
        @(negedge clk);
        irq = 0;

    endtask

    initial
    begin

        // Wait until reset is finished
        @(negedge rst);
        #100;

        // Vailidate REQ-FUNC-04
        $display("Vailidate REQ-FUNC-04: Support single reads and writes");
        wb_read_single(ADDRESS, 'hF, VERSION);
        wb_read_single(ADDRESS | 32'h4, 'hF, DEVICE_ID);
        wb_read_single(ADDRESS | 32'h10, 'hF, 32'h00000000);
        wb_read_single(ADDRESS | 32'h14, 'hF, 32'hDEADBEEF);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h12345678);
        wb_write_single(ADDRESS| 32'h8, 'hF, 32'hDEADBEEF);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'hDEADBEEF);

        wb_write_single(ADDRESS| 32'hC, 'hF, 32'h12345678);
        wb_read_single(ADDRESS | 32'hC, 'hF, 32'h12345678);
        wb_write_single(ADDRESS| 32'hC, 'hF, 32'hDEADBEEF);
        wb_read_single(ADDRESS | 32'hC, 'hF, 32'hDEADBEEF);

        $display("Validate read only registers are read only");
        // Version
        wb_write_single(ADDRESS| 32'h0, 'hF, 32'h22222222);
        wb_read_single(ADDRESS | 32'h0, 'hF, VERSION);
        // Device ID
        wb_write_single(ADDRESS| 32'h4, 'hF, 32'h22222222);
        wb_read_single(ADDRESS | 32'h4, 'hF, DEVICE_ID);
        // Status
        wb_write_single(ADDRESS| 32'h14, 'hF, 32'h22222222);
        wb_read_single(ADDRESS | 32'h14, 'hF, 32'hDEADBEEF);

        $display("Validate Clearing IRQ does not set any bits");
        wb_read_single(ADDRESS | 32'h10, 'hF, 32'h00000000);
        wb_write_single(ADDRESS| 32'h10, 'hF, 32'hFFFFFFFF);
        wb_read_single(ADDRESS | 32'h10, 'hF, 32'h00000000);

        $display("Validate IRQ_MASK correctly masks IRQ");
        wb_write_single(ADDRESS| 32'hC, 'hF, 32'h00000000);
        set_irq(32'hFFFFFFFF);
        wb_read_single(ADDRESS | 32'h10, 'hF, 32'h00000000);

        wb_write_single(ADDRESS| 32'hC, 'hF, 32'hFFFFFFFF);
        set_irq(32'hFFFFFFFF);
        wb_read_single(ADDRESS | 32'h10, 'hF, 32'hFFFFFFFF);


        $display("Validate Clearing IRQ resets bits");
        wb_write_single(ADDRESS| 32'h10, 'hF, 32'hFFFFFFFF);
        wb_read_single(ADDRESS | 32'h10, 'hF, 32'h00000000);

        $display("Validate passing of read and write to IP");
        wb_read_single(ADDRESS | 32'h20, 'hF, 32'h12345678, 1, 1);
        wb_write_single(ADDRESS | 32'h20, 'hF, 32'h12345678, 1, 1);


        $display("Vailidate REQ-FUNC-02: Support 8-bit granularity");
        wb_write_single(ADDRESS| 32'h8, 'hF, 32'h00000000);
        wb_write_single(ADDRESS| 32'h8, 'h1, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h00000078);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'h00000000);
        wb_write_single(ADDRESS| 32'h8, 'h2, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h00005600);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'h00000000);
        wb_write_single(ADDRESS| 32'h8, 'h4, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h00340000);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'h00000000);
        wb_write_single(ADDRESS| 32'h8, 'h8, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h12000000);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'h00000000);
        wb_write_single(ADDRESS| 32'h8, 'h3, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h00005678);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'h00000000);
        wb_write_single(ADDRESS| 32'h8, 'hC, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h12340000);

        //
        wb_write_single(ADDRESS| 32'h8, 'hF, 32'hFFFFFFFF);
        wb_write_single(ADDRESS| 32'h8, 'h1, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'hFFFFFF78);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'hFFFFFFFF);
        wb_write_single(ADDRESS| 32'h8, 'h2, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'hFFFF56ff);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'hFFFFFFFF);
        wb_write_single(ADDRESS| 32'h8, 'h4, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'hFF34FFFF);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'hFFFFFFFF);
        wb_write_single(ADDRESS| 32'h8, 'h8, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h12FFFFFF);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'hFFFFFFFF);
        wb_write_single(ADDRESS| 32'h8, 'h3, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'hFFFF5678);

        wb_write_single(ADDRESS| 32'h8, 'hF, 32'hFFFFFFFF);
        wb_write_single(ADDRESS| 32'h8, 'hC, 32'h12345678);
        wb_read_single(ADDRESS | 32'h8, 'hF, 32'h1234FFFF);

        $display("Vailidate REQ-FUNC-05: Support block read and write");
        wb_read_block(ADDRESS | 32'h20, 'hF, 32'h12345678);
        wb_write_block(ADDRESS | 32'h20, 'hF, 32'h12345678);

        $finish;
    end

endmodule
