module ctrl_microondas 
(
    input wire clock, reset, start, stop, pause, porta, mais, menos, potencia, sec_mod,
    input wire [1:0] min_mod,
    input wire [2:0] presets,
    output wire [7:0] an, dec_cat,
    output wire [2:0] potencia_rgb
);

// Declaração de localparams
localparam STATE_PROG = 2'b00;
localparam STATE_ON = 2'b01;
localparam STATE_PAUSE = 2'b10;

localparam PRESET_NIL = 3'b000;
localparam PRESET_PIPOCA = 3'b001;
localparam PRESET_LASANHA = 3'b010;
localparam PRESET_BIFE = 3'b011;


// Declaração dos sinais
reg [3:0] pot;
reg [1:0] EA, PE;
reg [3:0] incremento_sec, incremento_min;
wire start_ed, stop_ed, pause_ed, mais_ed, menos_ed;
wire pause_porta, start_porta, done, luz;
wire [7:0] dec_cat_timer;
wire [6:0] min_wire, sec_wire;

integer min, sec;


// Atribuição dos incrementos
always @(posedge clock or posedge reset) begin
    if (reset) begin
        incremento_sec <= 4'd0;
        incremento_min <= 4'd0;
    end
    else begin
        case (min_mod)
            2'b00: begin
                incremento_min <= 4'd0;
                if (sec_mod == 0) begin
                    incremento_sec <= 4'd1;
                end
                else begin
                    incremento_sec <= 4'd10;
                end
            end
            2'b01: begin 
                incremento_min <= 4'd1;
                incremento_sec <= 4'd0; 
                end
            2'b10: begin
                incremento_min <= 4'd10;
                incremento_sec <= 4'd0;
            end
            2'b11: begin
                incremento_min <= 4'd10;
                incremento_sec <= 4'd0;
            end
            default: begin
                incremento_min <= 4'd0;
                incremento_sec <= 4'd0;
            end
        endcase
    end
end


// Máquina de estados
always @(posedge clock or posedge reset)
begin
    if (reset) begin
        EA <= STATE_PROG;
    end
    else begin
        EA <= PE;
    end
end

// Lógica de troca de estados
always @(*)
begin
    case (EA)
        STATE_PROG: begin
            if (start_ed & porta == 0) begin
                PE <= STATE_ON;
            end
            else begin
                PE <= EA;
            end
        end
        STATE_ON: begin
            if (stop_ed | done) begin
                PE <= STATE_PROG;
            end
            else if (pause_ed | porta == 1) begin
                PE <= STATE_PAUSE;
            end
            else begin
                PE <= EA;
            end
        end
        STATE_PAUSE: begin
            if ((pause_ed | start_ed) & porta == 0) begin
                PE <= STATE_ON;
            end
            else if (stop_ed) begin
                PE <= STATE_PROG;
            end
            else begin
                PE <= EA;
            end
        end
    endcase
end

// Lógica de estados
always @(posedge clock or posedge reset) begin
    if (reset) begin
        pot <= 4'hA;
        min <= 0;
        sec <= 0;
    end
    else begin
        case (EA)
            STATE_PROG: begin
                if (potencia == 0 & presets == PRESET_NIL) begin // Se nenhum preset esta ligado
                    // Lógica de incremento
                    if (mais_ed) begin
                        sec <= sec + incremento_sec;
                        min <= min + incremento_min;
                    end else if (menos_ed) begin
                        sec <= sec - incremento_sec;
                        min <= min - incremento_min;
                    end
                    // Correção de overflow
                    if (sec > 59) begin
                        sec <= sec - 60;
                        min <= min + 1;
                    end
                    if (min > 99) begin
                        min <= 99;
                    end
                    if (sec < 0 & min > 0) begin
                        sec <= sec + 60;
                        min <= min - 1;
                    end else if (sec < 0) begin
                        sec <= 0;
                    end
                    if (min < 0) begin
                        min <= 0;
                    end
                end
                else if (potencia == 1 & presets == PRESET_NIL) begin // Se nenhum preset & chave de potencia ligada
                    // Lógica de incremento
                    if (mais_ed) begin
                        pot <= pot + 4'h1;
                    end else if (menos_ed) begin
                        pot <= pot - 4'h1;
                    end
                    // Correção de overflow
                    if (pot > 4'hC) begin
                        pot <= 4'hC;
                    end
                    if (pot < 4'hA) begin
                        pot <= 4'hA;
                    end
                end
                else begin // Se preset != 000
                    case (presets)
                        PRESET_PIPOCA: begin
                            min <= 7'd2;
                            sec <= 7'd52;
                            pot <= 4'hC;
                        end
                        PRESET_LASANHA: begin
                            min <= 7'd12;
                            sec <= 7'd22;
                            pot <= 4'hB;
                        end
                        PRESET_BIFE: begin
                            min <= 7'd1;
                            sec <= 7'd36;
                            pot <= 4'hA;
                        end
                        default: begin
                            min <= 7'd0;
                            sec <= 7'd0;
                            pot <= 4'hA;
                        end
                    endcase
                end
                if (stop_ed) begin
                    min <= 0;
                    sec <= 0;
                end
            end
            STATE_ON: begin
                min <= 0;
                sec <= 0;
            end
            STATE_PAUSE: begin
            end
            default: begin
                min <= 7'd0;
                sec <= 7'd0;
                pot <= 4'hA;
            end
        endcase
    end
end

// Assigns
assign pause_porta = ((porta == 1 | pause_ed == 1) & EA != STATE_PAUSE) ? 1 : (EA == STATE_PAUSE & porta == 0 & pause_ed == 1) ? 1 : 0; // Se o micro não estiver pausado, pausa se a porta abrir ou o pause for apertado. Se ele já estiver pausado, despausa somente se a porta estiver fechada e o botão for pressionado
assign start_porta = (porta == 0 & start_ed == 1) ? 1 : 0; // Apenas habilita o start se a porta estiver fechada
assign potencia_rgb = luz == 1 ? ((pot == 4'hA) ? 3'b001 : (pot == 4'hB) ? 3'b010 : (pot == 4'hC) ? 3'b100 : 3'b000) : 3'b000;
assign luz = ~porta;
assign dec_cat = an[5] ? dec_cat_timer : (pot == 4'hA) ? 8'b11101111 : (pot == 4'hB) ? 8'b11111101 : (pot == 4'hC) ? 8'b01111111 : 8'b11111111;

assign min_wire = min;
assign sec_wire = sec;

// Instâncias
timer micro_timer
(.clock(clock), .reset(reset), .pause(pause_porta), .start(start_porta), .stop(stop), 
.min(min_wire), .sec(sec_wire), .done(done), .an(an), .dec_cat(dec_cat_timer));

edge_detector ed_pause(.reset(reset), .clock(clock), .din(pause), .rising(pause_ed)); 
edge_detector ed_start(.reset(reset), .clock(clock), .din(start), .rising(start_ed)); 
edge_detector ed_stop(.reset(reset), .clock(clock), .din(stop), .rising(stop_ed));
edge_detector ed_mais(.reset(reset), .clock(clock), .din(mais), .rising(mais_ed)); 
edge_detector ed_menos(.reset(reset), .clock(clock), .din(menos), .rising(menos_ed));




endmodule