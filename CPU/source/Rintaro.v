module Rintaro (
    input wire fastClk,
    input wire clk1,
    input wire clk2,
    input wire rst,
    input wire[1:0] dig,
    input wire[2:0] switch,
    output wire[3:0] tubeDig,
    output wire[7:0] tubeSeg,
    output wire[10:0] lcdPins,
    inout wire ps2CLK,
    inout wire ps2DATA,
    output wire irqOut,
    input wire ir,
    output wire err,
    output wire stateOut,
    output wire[1:0] cpuClkMode
    );

    wire[31:0] addr, intAddr;
    wire[15:0] read;
    wire[15:0] write;
    reg[15:0] intData;
    wire we;
    wire re;
    wire ready;
    wire irq;
    assign irqOut = irq;
    wire turnOffIRQ;

    wire[31:0] PC;
    wire[15:0] A, B, C, FP, SP, BPH, BPL;
    wire[5:0] state;
    wire[15:0] page;
    wire[3:0] F;


    wire[31:0] bp0Addr, bp1Addr, bp2Addr, bp3Addr, bpAddr, keyboardAddr, irAddr;
    wire bp0En, bp1En, bp2En, bp3En, keyboardEn, irEn;

    wire[1:0] inMask, outMask;
    wire[15:0] lcdIn;

    RAM ram (
        .rst (rst),
        .clk (clk1),
        .addrIn (addr),
        .write (write),
        .we (we),
        .read (read),
        .re (re),
        .inMask (inMask),
        .outMask (outMask),
        .ready (ready),
        .lcdPins (lcdPins),
        .page (page),
        .switch (switch),
        .bp0Addr (bp0Addr),
        .bp1Addr (bp1Addr),
        .bp2Addr (bp2Addr),
        .bp3Addr (bp3Addr),
        .bpAddr (bpAddr),
        .keyboardAddr (keyboardAddr),
        .irAddr (irAddr),
        .bp0En (bp0En),
        .bp1En (bp1En),
        .bp2En (bp2En),
        .bp3En (bp3En),
        .keyboardEn (keyboardEn),
        .irEn (irEn),
        .lcdIn (lcdIn)
        );

    rcpu cpu(
        .clk (clk2),
        .rst (rst),
        .memAddr (addr),
        .memReadIn (read),
        .memWrite (write),
        .memWE (we),
        .memRE (re),
        .memReady (ready),
        .irq (irq),
        .turnOffIRQ (turnOffIRQ),
        .intAddr (intAddr),
        .intData (intData),
        .page (page),
        .inMask (inMask),
        .outMask (outMask),

        .PC (PC),
        .FP (FP),
        .SP (SP),
        .A (A),
        .B (B),
        .C (C),
        .state (state),
        .F (F)
        );

    wire[3:0] irData;
    wire irPressed;

    InterruptController intCtrl (
        .rst (rst),
        .clk (clk1),
        .fastClk (fastClk),
        .irq (irq),
        .turnOffIRQ (turnOffIRQ),
        .intAddr (intAddr),
        .intData (intData),

        .ps2CLK (ps2CLK),
        .ps2DATA (ps2DATA),
        .addr (addr),
        .re (re),
        .we (we),
        .irData (irData),
        .irPressed (irPressed),

        .bp0Addr (bp0Addr),
        .bp1Addr (bp1Addr),
        .bp2Addr (bp2Addr),
        .bp3Addr (bp3Addr),
        .bpAddr (bpAddr),
        .keyboardAddr (keyboardAddr),
        .irAddr (irAddr),
        .bp0En (bp0En),
        .bp1En (bp1En),
        .bp2En (bp2En),
        .bp3En (bp3En),
        .keyboardEn (keyboardEn),
        .irEn (irEn)
    );

    reg[15:0] value;
    reg[3:0] auxs;
    wire[3:0] mode;
    wire showName;


    DebugIR irModule (fastClk, rst, ir, mode, showName, err, stateOut, cpuClkMode, irData, irPressed);

    always @ (*) begin
        if (showName) begin
            case (mode)
                4'h0: begin value = 16'h1C00; auxs = 4'b1011; end // PC__
                4'h1: begin value = 16'hA000; auxs = 4'b0111; end // A___
                4'h2: begin value = 16'hB000; auxs = 4'b0111; end // B___
                4'h3: begin value = 16'hC000; auxs = 4'b0111; end // C___
                4'h4: begin value = 16'h52A2; auxs = 4'b0101; end // 5tAt // Stat
                4'h5: begin value = 16'h3044; auxs = 4'b1111; end // r_vv // r/w
                4'h6: begin value = 16'hADD5; auxs = 4'b0001; end // AddH
                4'h7: begin value = 16'hADD6; auxs = 4'b0001; end // AddL
                4'h8: begin value = 16'hDA2A; auxs = 4'b0010; end // dAtA
                4'h9: begin value = 16'h5100; auxs = 4'b0111; end // 5P__ // SP
                4'hA: begin value = 16'hF100; auxs = 4'b0111; end // FP__
                4'hB: begin value = 16'h8B12; auxs = 4'b0001; end // 8B1t
                4'hC: begin value = 16'h6CD0; auxs = 4'b1001; end // LCD_
                4'hD: begin value = 16'hF000; auxs = 4'b0111; end // F___
                default: begin value = 16'h0000; auxs = 4'b1111; end // ____
            endcase
        end else begin
            auxs = 4'b0000;
            case (mode)
                4'd0: value = PC[15:0];
                4'd1: value = A;
                4'd2: value = B;
                4'd3: value = C;
                4'd4: value = {3'b000, irq, 3'b000, keyboardEn, 2'b00, state};
                4'd5: begin
                    if (re) begin
                        value = 16'h3EAD;
                        auxs = 4'b1000;
                    end else if (we) begin
                        value = 16'h4432;
                        auxs = 4'b1111;
                    end else begin
                        value = 16'h0000;
                        auxs = 4'b1111;
                    end
                end
                4'd6: value = addr[31:16];
                4'd7: value = addr[15:0];
                4'd8: value = re? read : we? write : read;
                4'd9: value = SP;
                4'd10: value = FP;
                4'd11: value = {3'b000, inMask[1], 3'b000, inMask[0], 3'b000, outMask[1], 3'b000, outMask[0]};
                4'd12: value = lcdIn;
                4'd13: value = {3'b000, F[3], 3'b000, F[2], 3'b000, F[1], 3'b000, F[0]};
                default: value = 16'h0000;
            endcase
        end
    end

    TubeController tube (
        .dig (dig),
        .dig4 (value[15:12]),
        .dig3 (value[11:8]),
        .dig2 (value[7:4]),
        .dig1 (value[3:0]),
        .dots (4'b0000),
        .auxs (auxs),
        .tubeDig (tubeDig),
        .tubeSeg (tubeSeg)
        );


endmodule
