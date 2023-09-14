`default_nettype none
`include "parameters.v"

module i2s_to_pcm(clk, ws, data_in, reset, data_left, data_right);

        input wire clk;
        input wire ws;
        input wire data_in;
        input wire reset;
        output reg [NUMBER_OF_BITS-1:0] data_left;
        output reg [NUMBER_OF_BITS-1:0] data_right;

    reg [3:0] bit_counter;

    always @(posedge clk) begin
        if (reset) begin
            bit_counter <= 1;
        end else begin
            if (bit_counter < NUMBER_OF_BITS+1+1) begin // + 1 because of the initial bit before data
                if (bit_counter != 1) begin
                    if (!ws) begin
                        data_left <= data_left << 1;
                        data_left[0] <= data_in;
                    end else begin 
                        data_right <= data_right << 1;
                        data_right[0] <= data_in;
                    end
                end
            end
            bit_counter <= bit_counter + 1;
        end
    end
    
endmodule


module channel_buffer (ws, data_in, read_index, data_out);

    input wire ws;
    input wire [$clog2(BUFFER_SIZE)-1:0] read_index;
    input wire [NUMBER_OF_BITS-1:0] data_in;
    output wire [NUMBER_OF_BITS-1:0] data_out;
    
    reg [NUMBER_OF_BITS-1:0] data [BUFFER_SIZE-1:0];

    assign data_out = data[read_index];

    always @(negedge ws) begin
        for (int i = BUFFER_SIZE-1; i > 0; i = i - 1) begin
            data[i] <= data[i-1];
        end
        data[0] <= data_in;
    end

endmodule

module complete_dual_buffer (clk, ws, data_in, reset, delay_index_l, delay_index_r, buffer_out_l, buffer_out_r);
    input wire clk;
    input wire ws;
    input wire data_in;
    input wire reset;
    input wire [$clog2(BUFFER_SIZE)-1:0] delay_index_l;
    input wire [$clog2(BUFFER_SIZE)-1:0] delay_index_r;
    output wire [NUMBER_OF_BITS-1:0] buffer_out_l;
    output wire [NUMBER_OF_BITS-1:0] buffer_out_r;

    wire [NUMBER_OF_BITS-1:0] buffer_in_l;
    wire [NUMBER_OF_BITS-1:0] buffer_in_r;

    i2s_to_pcm i2s_to_pcm_l(
        .clk(clk),
        .ws(ws),
        .data_in(data_in),
        .reset(reset),
        .data_left(buffer_in_l),
        .data_right(buffer_in_r)
    );

    channel_buffer channel_buffer_l(
        .ws(ws),
        .data_in(buffer_in_l),
        .read_index(delay_index_l),
        .data_out(buffer_out_l)
    );

    channel_buffer channel_buffer_r(
        .ws(ws),
        .data_in(buffer_in_r),
        .read_index(delay_index_r),
        .data_out(buffer_out_r)
    );
    
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
        uio_in[3:0] - delay register enable inputs beamformer
        uio_in[4] - data input for delay registers
        uio_in[5] - write enable fro delay registers

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
    wire delay_write_enable;
    wire [3:0] delay_data_register_select;

    assign delay_data_register_select = uio_in[3:0];
    assign delay_data = uio_in[4];
    assign delay_write_enable = uio_in[5];

    reg [$clog2(NUMBER_OF_CHANNELS) + NUMBER_OF_BITS - 1 :0] data_output; // Might be worng?
    assign uo_out[0] = data_output[NUMBER_OF_BITS-1];

    reg [$clog2(BUFFER_SIZE)-1:0] read_index [NUMBER_OF_CHANNELS * 2 - 1:0]; 
    
    wire [NUMBER_OF_BITS-1:0] buffer_data_output [NUMBER_OF_CHANNELS * 2 - 1:0];

    for (genvar i = 0; i < NUMBER_OF_CHANNELS; i = i + 1) begin
        complete_dual_buffer buffer_1 (
            .clk(clk),
            .ws(ws_clk),
            .data_in(ui_in[i]),
            .reset(reset),
            .delay_index_l(read_index[i*2]),
            .delay_index_r(read_index[i*2+1]),
            .buffer_out_l(buffer_data_output[i*2]),
            .buffer_out_r(buffer_data_output[i*2+1])
        );    
    end
  

    // Use ws_clk to give potenisal MCU more time, still fast enough.
    always @ (posedge ws_clk) begin
        if (reset) begin
            for (int i = 0; i < NUMBER_OF_CHANNELS * 2; i = i + 1) begin
                read_index[i] <= 0;
            end            
        end 
        if (delay_write_enable) begin
            read_index[delay_data_register_select] <= read_index[delay_data_register_select] << 1;
            read_index[delay_data_register_select][0] <= delay_data;
        end
    end

    reg [5:0] write_counter;
    
    always @(posedge clk) begin
        if (reset) begin
            write_counter <= 0;
        end else begin
            if (write_counter == 63) begin
                for (int i=0; i < NUMBER_OF_CHANNELS; i = i + 1) begin
                    data_output <= data_output + buffer_data_output[i*2] + buffer_data_output[i*2+1];
                end
            end else begin
                data_output <= data_output << 1;
            end
            write_counter <= write_counter + 1;
        end
    end

endmodule
