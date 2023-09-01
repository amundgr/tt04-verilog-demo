`default_nettype none

module i2s_to_pcm(clk, ws, data_in, reset, data_left_output, data_right_output);

    parameter NUMBER_OF_BITS = 8;

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
reg [2:0] bit_counter = 0;


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
                        data_left <= data_left << 1 | data_in;
                    end 
                    else begin 
                        data_right <= data_right << 1 | data_in;
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

    parameter NUMBER_OF_BITS = 8;
    parameter SAMPLES_BUFFER_SIZE = 10;

    input wire clk;
    input wire [log2(NUMBER_OF_BITS)-1:0] read_index;
    input wire [NUMBER_OF_BITS-1:0] data_in;
    output wire [NUMBER_OF_BITS-1:0] data_out;
    
    reg [NUMBER_OF_BITS-1:0] data [SAMPLES_BUFFER_SIZE-1:0];

    assign data_out = data[read_index];

    always @(posedge clk) begin
        data <= {data[SAMPLES_BUFFER_SIZE-2:0], data_in};
    end

endmodule

module tt_um_seven_segment_seconds (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

localparam NUMBER_OF_CHANNELS = 8;
localparam NUMBER_OF_BITS = 8;
localparam SAMPLES_BUFFER_SIZE = 10;
localparam BUFFER_SIZE = NUMBER_OF_BITS * SAMPLES_BUFFER_SIZE;

wire reset = ! rst_n;


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

// wire [7:0] data_left;
// wire [7:0] data_right;

reg [7:0] data_output = 0;
reg [7:0] read_index = 0;

i2s_to_pcm test_design_i2s(
    .clk(clk),
    .ws(ws_clk),
    .data_in(ui_in[0]),
    .reset(reset),
    .data_left_output(uio_out),
    .data_right_output(uo_out)
);

channel_buffer test_design_channel_buffer(
    .clk(clk),
    .data_in(uio_out),
    .read_index(read_index),
    .data_out(data_output)
);

always @ (posedge ws_clk) begin
    if (reset) begin
        read_index <= 0;
    end else begin
        read_index <= read_index + 3;
    end
end



/*
reg [ NUMBER_OF_BITS - 1 : 0 ] channels [ 0 : NUMBER_OF_CHANNELS-1 ][SAMPLES_BUFFER_SIZE -1 : 0];

// use bidirectionals as outputs
assign uio_out = 8'b00000000;

generate
    genvar i;
    for ( i = 0; i < NUMBER_OF_CHANNELS; i = i + 1 ) begin
        assign uo_out[i] = channels[i][SAMPLES_BUFFER_SIZE-1];
    end 
endgenerate

integer j;
integer k;




always @(posedge ws_clk) begin
    // if reset, set counter to 0
    if (reset) begin
        // digit <= 0;
    end else begin
        if (ena) begin
            for( j = 0; j < NUMBER_OF_CHANNELS; j = j + 1 ) begin
                for( k = SAMPLES_BUFFER_SIZE-1; k > 0; k = k - 1 ) begin
                    channels[j][k] <= channels[j][k-1];
                end
                channels[j][0] <= ui_in;
                // channels[j] = channels[j][SAMPLES_BUFFER_SIZE-2:0] >> 1 // {channels[j][SAMPLES_BUFFER_SIZE-2:0], ui_in[j]};
            end
        end
    end
end
*/
endmodule
