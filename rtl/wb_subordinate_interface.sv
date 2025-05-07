`default_nettype none

module wb_subordinate_interface #(
        parameter WB_ADDRESS_WIDTH = 32,
        parameter logic[WB_ADDRESS_WIDTH-1:0] WB_BASE_ADDRESS = 'h4000_0000,
        parameter WB_REGISTER_ADDRESS_WIDTH = 16,
        parameter WB_DATA_WIDTH = 32,
        parameter WB_DATA_GRANULARITY = 8,

        parameter logic[WB_DATA_WIDTH-1:0] IP_VERSION = 'hFFFFFFFF, // To be set by IP
        parameter logic[WB_DATA_WIDTH-1:0] IP_DEVICE_ID = 'hFFFFFFFF // To be set by IP
    ) (
        // Wishbone clocking signals
        i_wb_clk,
        i_wb_rst,

        // Wishbone data signals
        i_wb_addr,
        i_wb_dat,
        o_wb_dat,

        // Wishbone control signals
        i_wb_cyc,
        i_wb_stb,
        i_wb_we,
        i_wb_sel,
        o_wb_stall,
        o_wb_ack,

        // IP data signals
        o_ip_address,
        i_ip_rdata,
        o_ip_wdata,

        // IP control signals
        o_ip_read_en,
        o_ip_write_en,
        i_ip_ack,
        i_ip_stall,

        // Interface Standard registers
        o_ip_control,
        i_ip_status,
        // o_ip_irq_mask,
        i_ip_irq,
        o_ip_irq
    );

    localparam SELECT_WIDTH = WB_DATA_WIDTH / WB_DATA_GRANULARITY;

    input wire logic i_wb_clk;
    input wire logic i_wb_rst;

    input wire logic[WB_ADDRESS_WIDTH-1:0] i_wb_addr;
    input wire logic[WB_DATA_WIDTH-1:0] i_wb_dat;
    output logic[WB_DATA_WIDTH-1:0] o_wb_dat;

    input wire logic i_wb_cyc;
    input wire logic i_wb_stb;
    input wire logic i_wb_we;
    input wire logic[SELECT_WIDTH-1:0] i_wb_sel;
    output logic o_wb_stall;
    output logic o_wb_ack;

    output logic[WB_REGISTER_ADDRESS_WIDTH-1:0] o_ip_address;
    input wire logic[WB_DATA_WIDTH-1:0] i_ip_rdata;
    output logic[WB_DATA_WIDTH-1:0] o_ip_wdata;

    output logic o_ip_read_en;
    output logic o_ip_write_en;
    input wire logic i_ip_ack;
    input wire logic i_ip_stall;

    output logic[WB_DATA_WIDTH-1:0] o_ip_control;
    input wire logic[WB_DATA_WIDTH-1:0] i_ip_status;
    // output logic[WB_DATA_WIDTH-1:0] o_ip_irq_mask;
    input wire logic[WB_DATA_WIDTH-1:0] i_ip_irq;
    output wire logic[WB_DATA_WIDTH-1:0] o_ip_irq;


    /*
    Declarations
    */
    logic[WB_REGISTER_ADDRESS_WIDTH-1:0] register_address;
    logic[WB_ADDRESS_WIDTH-WB_REGISTER_ADDRESS_WIDTH-1:0] core_address;
    logic targeted_core;
    logic valid_transaction;

    logic [WB_DATA_WIDTH-1:0] read_data;

    logic [WB_DATA_WIDTH-1:0] version_reg;
    logic [WB_DATA_WIDTH-1:0] device_id_reg;
    logic [WB_DATA_WIDTH-1:0] control_reg;
    logic [WB_DATA_WIDTH-1:0] irq_mask_reg;
    logic [WB_DATA_WIDTH-1:0] irq_reg;
    logic [WB_DATA_WIDTH-1:0] status;

    logic ip_action;

    logic [WB_DATA_WIDTH-1:0] irq_value;

    logic[WB_DATA_WIDTH-1:0] sel_wb_dat;
    logic[WB_DATA_WIDTH-1:0] current_dat;

    /*
    Assignments
    */
    assign register_address = i_wb_addr[WB_REGISTER_ADDRESS_WIDTH-1:0];
    assign o_ip_address = register_address;
    assign core_address = i_wb_addr[WB_ADDRESS_WIDTH -1:WB_REGISTER_ADDRESS_WIDTH];
    assign targeted_core = (core_address == WB_BASE_ADDRESS[WB_ADDRESS_WIDTH -1:WB_REGISTER_ADDRESS_WIDTH]) ? 1'b1 : 1'b0;
    assign valid_transaction = (i_wb_stb) & (i_wb_cyc) & (!o_wb_stall) & (targeted_core);

    assign version_reg = IP_VERSION;
    assign device_id_reg = IP_DEVICE_ID;
    assign o_wb_stall = (i_wb_rst || !i_wb_cyc) ? 1'b0 : i_ip_stall;


    /*
    Wishbone Interface
    */

    assign o_ip_control = control_reg;
    assign status = i_ip_status;


    always_ff @(posedge i_wb_clk)
        if (i_wb_rst)
            read_data <= 0;
        else
            if(valid_transaction && (!i_wb_we))
            begin
                case(register_address)
                    16'h0:
                        read_data <= version_reg;
                    16'h4:
                        read_data <= device_id_reg;
                    16'h8:
                        read_data <= control_reg;
                    16'hC:
                        read_data <= irq_mask_reg;
                    16'h10:
                        read_data <= irq_reg;
                    16'h14:
                        read_data <= status;
                    16'h18:
                        read_data <= 0;
                    16'h1C:
                        read_data <= 0;
                    default:
                        read_data <= i_ip_rdata;
                endcase
            end

    always_comb
    begin
        for(int i = 0; i < SELECT_WIDTH; i++)
        begin
            if(i_wb_sel[i])
                o_wb_dat[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY] = read_data[i * WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY];
            else
                o_wb_dat[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY] = 0;
        end
    end

    always_comb
    begin
        for(int i = 0; i < SELECT_WIDTH; i++)
        begin
            // sel_wb_dat
            if(i_wb_sel[i])
                sel_wb_dat[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY] = i_wb_dat[i * WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY];
            else
                sel_wb_dat[i*WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY] = current_dat[i * WB_DATA_GRANULARITY +: WB_DATA_GRANULARITY];
        end
    end

    always_comb
    begin
        current_dat = 0;
        if(valid_transaction && i_wb_we)
        case(register_address)
            16'h0:
                ;
            16'h4:
                ;
            16'h8:
                current_dat = control_reg;
            16'hC:
                current_dat = irq_mask_reg;
            16'h10:
                current_dat = irq_reg;
            16'h14:
                ;
            16'h18:
                ;
            16'h1C:
                ;
            default:
                current_dat = i_ip_rdata;
        endcase
    end

    assign o_ip_read_en = (i_wb_stb) & (i_wb_cyc) & (register_address >= 16'h20);
    // assign o_ip_read_en = (i_wb_stb) & (i_wb_cyc) & (!i_wb_we) & (register_address >= 16'h20);
    assign o_ip_write_en = (i_wb_stb) & (i_wb_cyc) & (i_wb_we) & (register_address >= 16'h20);
    assign o_ip_wdata = (o_ip_write_en) ? sel_wb_dat : 0;
    assign ip_action = o_ip_write_en | o_ip_read_en;

    assign irq_value = (valid_transaction && i_wb_we && register_address == 16'h10) ? ((irq_reg) | (irq_mask_reg & i_ip_irq)) & (~sel_wb_dat) : ((irq_reg) | (irq_mask_reg & i_ip_irq));
    assign o_ip_irq = irq_reg;

    always_ff @(posedge i_wb_clk)
        if (i_wb_rst)
            irq_reg <= 0;
        else
            irq_reg <= irq_value;


    always_ff @(posedge i_wb_clk)
        if (i_wb_rst)
        begin
            control_reg <= 0;
            irq_mask_reg <= 0;
        end
        else
            if(valid_transaction && i_wb_we)
            begin
                case(register_address)
                    16'h0:
                        ;
                    16'h4:
                        ;
                    16'h8:
                        control_reg <= sel_wb_dat;
                    16'hC:
                        irq_mask_reg <= sel_wb_dat;
                    16'h10:
                        ;
                    16'h14:
                        ;
                    16'h18:
                        ;
                    16'h1C:
                        ;
                    default:
                        ;
                endcase
            end

    // assign o_wb_ack = 0;
    logic ack;
    assign ack = (targeted_core & (i_wb_stb) & (!o_wb_stall) & ((!ip_action) | (ip_action & i_ip_ack)));
    always_ff @(posedge i_wb_clk)
        if(i_wb_rst)
            o_wb_ack <= 0;
        else
            // o_wb_ack <= 0;
            o_wb_ack <= ack;

`ifdef	FORMAL

    parameter		F_LGDEPTH = 4;
    logic [(F_LGDEPTH-1):0] f_nreqs, f_nacks;

    logic f_past_valid;
    logic[66:0] f_request;
    logic good_address;

    assign good_address = (i_wb_addr[31:16] == 16'h4000) ? 1'b1 : 1'b0;

    assign f_request = {i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_dat};

    initial
        f_nreqs = 0;
    always_ff @(posedge i_wb_clk)
        if(i_wb_rst)
            f_nreqs <= 0;
        else if (!i_wb_cyc)
            f_nreqs <= 0;
        else if((i_wb_stb))
            f_nreqs <= f_nreqs + 1;

    initial
        f_nacks = 0;
    always_ff @(posedge i_wb_clk)
        if(i_wb_rst)
            f_nacks <= 0;
        else if (!i_wb_cyc)
            f_nacks <= 0;
        else if((o_wb_ack))
            f_nacks <= f_nacks + 1;

    initial
        f_past_valid = 0;

    initial
        assume(!i_wb_cyc);

    always @(*)
        if(!f_past_valid)
            assume(i_wb_rst);

    initial
        assert(i_wb_rst);

    always_ff @(posedge i_wb_clk)
        f_past_valid <= 1;

    // Make sure CYC stay high until received all acks
    always @(*)
        if(!i_wb_rst && (f_nacks != f_nreqs))
            assume(i_wb_cyc);

    always_ff @(posedge i_wb_clk)
        if(f_past_valid && $past(!i_wb_rst && i_wb_stb && o_wb_stall))
            assume(i_wb_cyc);


    // Make sure bus it idle at reset
    always_ff @(posedge i_wb_clk)
        if((f_past_valid) && ($past(i_wb_rst)))
        begin
            assume(!i_wb_cyc);
            assume(!i_wb_stb);

            assert(!o_wb_ack);
            assert(!o_wb_stall);
        end

    // Assume that i_wb_stb is always low when i_wb_cyc is low
    always_ff @(*)
        if(!i_wb_cyc)
            assume (!i_wb_stb);

    // Assume that input is synchronous
    always_ff @($global_clock)
        if((f_past_valid) && (!$rose(i_wb_clk)))
        begin
            assume($stable(i_wb_rst));
            assume($stable(i_wb_cyc));
            assume($stable(f_request));
        end

    // Assume bas input does not change when stalled
    always_ff @(posedge i_wb_clk)
        if((f_past_valid) && (!($past(i_wb_rst))) &&($past(i_wb_stb)) && ($past(o_wb_stall)) && (i_wb_cyc))
        begin
            assume(i_wb_stb);
            assume(i_wb_cyc);
            assume(i_wb_we == $past(i_wb_we));
            assume (i_wb_sel == $past(i_wb_sel));
            assume (i_wb_addr == $past(i_wb_addr));
            if(i_wb_we)
                assume(i_wb_dat == $past(i_wb_dat));
        end

    // Assume write enable does change during a block transaction
    always_ff @(posedge i_wb_clk)
        if((f_past_valid) && ($past(i_wb_stb)) && (i_wb_stb))
            assume(i_wb_we == $past(i_wb_we));

    // Assume at lest 1 bit of i_wb_sel is high when during a bus cycle
    always @(*)
        if((i_wb_stb))
            assume(|i_wb_sel);

    // Assume address is word aligned
    always @(*)
        assume(i_wb_addr[1:0] == 2'b00);

    // Assume address the top 16 bits are 0x4000 (IP address) or 0x4001(different address)
    always @(*)
        assume((i_wb_addr[31:16] == 16'h4000) || (i_wb_addr[31:16] == 16'h4001) );

    always_ff @(posedge i_wb_clk)
        if((f_past_valid) && ($past(i_wb_cyc)))
            assume(i_wb_addr[31:16] == $past(i_wb_addr[31:16]));

    // Assert that o_wb_stall and o_wb_ack is low when not in a cycle
    always_ff @(posedge i_wb_cyc)
        if((f_past_valid) && (!$past(i_wb_cyc)) && (!i_wb_cyc))
        begin
            assert(!o_wb_stall);
            assert(!o_wb_ack);
        end

    // Assert that o_wb_stall and o_wb_ack it not high at the same time
    always @(*)
        assert((!o_wb_ack) || (!o_wb_stall));

    // Assert that o_wb_ack is high if o_wb_stall is not high and i_wb_stb was high last clock cycle
    always_ff @(posedge i_wb_clk)
        if((f_past_valid) && (!$past(i_wb_rst)) && ($past(i_wb_stb)) && (!$past(o_wb_stall)))
            if(good_address)
                assert(o_wb_ack);
            else
                assert(!o_wb_ack);


    // Assert only o_ip_read_en or o_ip_write_en is high at a time
    always @(*)
        assert((!o_ip_read_en) || (!o_ip_write_en));

    // Assume that if o_ip_read_en or o_ip_write_en is high i_ip_ack is high
    always @(*)
        if(o_ip_read_en || o_ip_write_en)
            assume(i_ip_ack);

    // Assert o_ip_write_en is high when targting IP register
    // always_ff @(posedge i_wb_clk)
    always @(*)
        if((f_past_valid) && (i_wb_addr[15:2] >= 14'h8) && ((i_wb_stb)) && ((i_wb_we)))
            assert(o_ip_write_en);

    // Assert o_ip_read_en is high when targting IP register
    always_ff @(posedge i_wb_clk)
        if((f_past_valid) && (i_wb_addr[15:2] >= 14'h8) && ((i_wb_stb)) && ((!i_wb_we)))
            assert(o_ip_read_en);

    // Assume i_ip_stall is low if o_ip_read_en and o_ip_write_en is low
    always @(*)
        if ((!o_ip_read_en) && (!o_ip_write_en))
            assume(!i_ip_stall);


`endif

endmodule
