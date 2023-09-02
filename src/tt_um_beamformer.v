`default_nettype none

module i2s_to_pcm(clk, ws, data_in, reset, data_left_output, data_right_output);

    input wire clk;
    input wire ws;
    input wire data_in;
    input wire reset;
    output wire [NUMBER_OF_BITS-1:0] data_left_output;
    output wire [NUMBER_OF_BITS-1:0] data_right_output;

localparam [1:0]
    wait_clk       = 2'b00,
    samplig        = 2'b01,
    not_sampling   = 2'b10,
    edge_case      = 2'b11;

reg [NUMBER_OF_BITS-1:0] data_left;
reg [NUMBER_OF_BITS-1:0] data_right;

assign data_left_output = data_left;
assign data_right_output = data_right;

reg [1:0] state = not_sampling;
reg prev_ws = 0;
reg [$clog2(NUMBER_OF_BITS):0] bit_counter = 0;


always @(posedge clk) begin
    if (reset) begin
        prev_ws <= 0;
        bit_counter <= 0;
    end else begin
        case (state) 
            wait_clk: begin
                state <= samplig;
            end
            samplig: begin
                if (bit_counter == NUMBER_OF_BITS-1) begin
                    state <= not_sampling;
                    bit_counter <= 0;
                end else begin
                    if (!ws) begin
                        data_left <= data_left << 1;
                        data_left[0] <= data_in;
                    end 
                    else begin 
                        data_right <= data_right << 1;
                        data_right[0] <= data_in;
                    end
                    bit_counter <= bit_counter + 1;
                end
            end
            not_sampling: begin
                if (ws != prev_ws) begin
                    state <= wait_clk;
                end
            end
            edge_case: begin
                state <= not_sampling;
            end
        endcase
    end
end

endmodule



module channel_buffer (clk, data_in, read_index, data_out);

    input wire clk;
    input wire [$clog2(BUFFER_SIZE):0] read_index;
    input wire [NUMBER_OF_BITS-1:0] data_in;
    output wire [NUMBER_OF_BITS-1:0] data_out;
    
    reg [NUMBER_OF_BITS-1:0] data [BUFFER_SIZE-1:0];

    assign data_out = data[read_index];

    always @(posedge clk) begin
        for (int i = BUFFER_SIZE-1; i > 0; i = i - 1) begin
            data[i] <= data[i-1];
        end
        data[0] <= data_in;
    end

endmodule

module tt_um_beamformer (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

localparam NUMBER_OF_CHANNELS = 1;
localparam NUMBER_OF_BITS = 8;
localparam BUFFER_SIZE = 10;

wire reset = ! rst_n;

reg [7:0] dummy_1 = 0;
reg [7:0] dummy_2 = 0;

assign uio_out = dummy_1;
assign uio_oe = dummy_2;

reg ws_clk = 0;
reg [4:0] ws_counter = 0;

always @ (posedge clk) begin
    if (reset) begin
        ws_clk <= 0;
        ws_counter <= 0;
    end else begin
        if (ws_counter == 31) begin
            ws_clk <= ~ws_clk;
        end
        ws_counter <= ws_counter + 1;
    end
end

wire [7:0] data_left;
wire [7:0] data_right;

wire [7:0] data_output_1;
wire [7:0] data_output_2;

reg [7:0] data_output;

assign uo_out = data_output;

reg [$clog2(SAMPLES_BUFFER_SIZE):0] read_index = 0;

i2s_to_pcm test_design_i2s(
    .clk(clk),
    .ws(ws_clk),
    .data_in(ui_in[0]),
    .reset(reset),
    .data_left_output(data_left),
    .data_right_output(data_right)
);

channel_buffer test_design_channel_buffer_1(
    .clk(ws_clk),
    .data_in(data_left),
    .read_index(read_index),
    .data_out(data_output_1)
);

channel_buffer test_design_channel_buffer_2(
    .clk(ws_clk),
    .data_in(data_right),
    .read_index(read_index),
    .data_out(data_output_2)
);

always @ (posedge ws_clk) begin
    if (reset) begin
        read_index <= 0;
    end else begin
        read_index <= read_index + 3;
        data_output <= data_output_1[6:0] + data_output_2[6:0];
    end
end
