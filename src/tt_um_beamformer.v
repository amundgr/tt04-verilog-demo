`default_nettype none
`include "parameters.v"

module i2s_to_pcm(clk, ws, data_in, reset, data_left_output, data_right_output);

        input wire clk;
        input wire ws;
        input wire data_in;
        input wire reset;
        output wire [NUMBER_OF_BITS-1:0] data_left_output;
        output wire [NUMBER_OF_BITS-1:0] data_right_output;

    reg [NUMBER_OF_BITS-1:0] data_left;
    reg [NUMBER_OF_BITS-1:0] data_right;

    assign data_left_output = data_left;
    assign data_right_output = data_right;

    reg [$clog2(NUMBER_OF_BITS):0] bit_counter = 0;

    always @(posedge clk) begin
        if (bit_counter != NUMBER_OF_BITS+1) begin // + 1 because of the initial bit before data
            if (bit_counter != 0) begin
                if (!ws) begin
                    data_left <= data_left << 1;
                    data_left[0] <= data_in;
                end else begin 
                    data_right <= data_right << 1;
                    data_right[0] <= data_in;
                end
            end
            bit_counter <= bit_counter + 1;
        end
    end
    
    always @(posedge ws) begin
        bit_counter <= 0;
    end
    always @(negedge ws) begin
        bit_counter <= 0;
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

    /*
        ui_in - data inputs to the i2s modules

        # Probably safe to set all uio_oe to input (0=input)
        uio_in[2:0] - delay register enable inputs beamformer
        uio_in[3] - data input for delay registers
        uio_in[4] - clock input for delay registers

        # Use same as provided clock to get data out
        uo_out[0] - data output from beamformer
        uo_out[1] - ws output from beamformer
    */

    wire reset = ! rst_n;

    // Might want to set to Z?
    assign uo_out[7:2] = 0;// dummy_byte_zero[7:2];
    assign uio_out = 0;// dummy_byte_zero[7:1];
    assign uio_oe = 0;// dummy_byte_zero;

    wire ws_clk;
    reg [4:0] ws_counter;
    assign ws_clk = ws_counter[4];
    assign uo_out[1] = ws_clk;

    always @ (negedge clk) begin
        if (reset) begin
            ws_counter <= 0;
        end else begin
            ws_counter <= ws_counter + 1;
        end
    end

    wire delay_data;
    wire delay_data_clock;
    wire [2:0] delay_data_register_select;

    assign delay_data_register_select = uio_in[2:0];
    assign delay_data = uio_in[3];
    assign delay_data_clock = uio_in[4];

    reg [7:0] data_output;
    assign uo_out[0] = data_output[7];
    
    wire [7:0] data_left;
    wire [7:0] data_right;
    
    wire [7:0] data_output_1;
    wire [7:0] data_output_2;

    reg [$clog2(BUFFER_SIZE):0] read_index [2:0]; // Set hard to 3 as 8 is max

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
        .read_index(read_index[0]),
        .data_out(data_output_1)
    );

    channel_buffer test_design_channel_buffer_2(
        .clk(ws_clk),
        .data_in(data_right),
        .read_index(read_index[1]),
        .data_out(data_output_2)
    );

    always @ (posedge delay_data_clock) begin
        read_index[delay_data_register_select] <= (read_index[delay_data_register_select] << 1 ) | delay_data;
    end

    always @ (posedge clk) begin
        data_output <= data_output << 1;
    end

endmodule
