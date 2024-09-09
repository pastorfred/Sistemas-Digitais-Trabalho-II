module timer
(
    input wire clock, reset, start, stop, pause,
    input wire [6:0] min, sec,
    output wire done,
    output wire [7:0] an, dec_cat
);
    // Declaração de localparams
    localparam STATE_IDLE = 2'b00;
    localparam STATE_ON = 2'b01;
    localparam STATE_PAUSE = 2'b10;

    // Declaração dos sinais
    reg [6:0] min_reg, sec_reg;
    reg [31:0] counter;
    reg [1:0] EA, PE;
    reg ck1seg;
    wire pause_ed, start_ed, stop_ed, ck1seg_ed;

    // Divisor de clock para gerar o ck1seg
    always @(posedge clock or posedge reset)
    begin
        if (reset) begin
            ck1seg <= 0;
            counter <= 31'd0;
        end
        else begin
            if (counter == 31'd49999999) begin
                ck1seg <= ~ck1seg;
                counter <= 31'd0;
            end
            else begin
                counter <= counter + 31'd1;
            end
        end
    end

    // Máquina de estados
    always @(posedge clock or posedge reset)
    begin
        if (reset) begin
            EA <= STATE_IDLE;
        end
        else begin
            EA <= PE;
        end
    end

    // Lógica de troca de estados
    always @(*)
    begin
        case (EA)
            STATE_IDLE: begin
                if (start_ed) begin
                    PE <= STATE_ON;
                end
                else begin
                    PE <= EA;
                end
            end
            STATE_ON: begin
                if (stop_ed == 1 | (min_reg == 0 & sec_reg == 0)) begin
                    PE <= STATE_IDLE;
                end
                else if (pause_ed == 1) begin
                    PE <= STATE_PAUSE;
                end
                else begin
                    PE <= EA;
                end
            end
            STATE_PAUSE: begin
                if (pause_ed == 1 | start_ed == 1) begin
                    PE <= STATE_ON;
                end
                else if (stop_ed == 1) begin
                    PE <= STATE_IDLE;
                end
                else begin
                    PE <= EA;
                end
            end
            default: begin
                PE <= STATE_IDLE;
            end
        endcase
    end

    // Decrementador de tempo (minutos e segundos)
    always @(posedge clock or posedge reset)
    begin
        if (reset) begin
            min_reg <= 0;
            sec_reg <= 0;
        end
        else if (EA == STATE_IDLE) begin
            min_reg <= min;
            sec_reg <= sec;
            if (sec_reg > 7'd59) begin
                sec_reg <= 7'd59;
            end
            if (min_reg > 7'd99) begin
                min_reg <= 7'd99;
            end
        end
        else if (ck1seg_ed == 1) begin
            if (EA == STATE_ON & (sec_reg != 0 | min_reg != 0)) begin
                if (sec_reg == 7'd0) begin
                    min_reg <= min_reg - 7'd1;
                    sec_reg <= 7'd59;
                end
                else begin
                    sec_reg <= sec_reg - 7'd1;
                end
            end
        end
    end
    
    // Instanciação dos edge detectors
    edge_detector ed_pause(.reset(reset), .clock(clock), .din(pause), .rising(pause_ed)); 
    edge_detector ed_start(.reset(reset), .clock(clock), .din(start), .rising(start_ed)); 
    edge_detector ed_stop(.reset(reset), .clock(clock), .din(stop), .rising(stop_ed));
    edge_detector ed_ck1seg(.reset(reset), .clock(clock), .din(ck1seg), .rising(ck1seg_ed)); 

    // Instaciação do display
    wire [3:0] display_sec_u, display_sec_d, display_min_u, display_min_d;

    assign display_sec_u = sec_reg % 10;
    assign display_sec_d = sec_reg / 10;
    assign display_min_u = min_reg % 10;
    assign display_min_d = min_reg / 10;

    dspl_drv_NexysA7 driver (.reset(reset), .clock(clock), .d1({1'b1, display_sec_u, 1'b0}), .d2({1'b1, display_sec_d, 1'b0}), .d3({1'b1, display_min_u, 1'b0}), .d4({1'b1, display_min_d, 1'b0}), .d5(1'b1, 4'b0, 1'b0), .d6(6'b0), .d7(6'b0), .d8(6'b0), .an(an), .dec_cat(dec_cat));

    

    assign done = (EA == STATE_IDLE & sec_reg == 0 & min_reg == 0) ? 1 : 0;

endmodule