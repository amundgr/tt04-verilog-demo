`default_nettype none

module tt_um_seven_segment_seconds #( parameter MAX_COUNT = 24'd10_000_000 ) (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    localparam NUMBER_OF_CHANNELS = 14;
    localparam NUMBER_OF_BITS = 8;
    localparam SAMPLES_BUFFER_SIZE = 10;
    localparam BUFFER_SIZE = NUMBER_OF_BITS * SAMPLES_BUFFER_SIZE;

    wire reset = ! rst_n;

    reg [ BUFFER_SIZE - 1 : 0 ] channels [ 0 : NUMBER_OF_CHANNELS-1 ];

    // use bidirectionals as outputs
    assign uio_oe = 8'b11111111;
    assign uio_out = 8'b00000000;

    integer i;
    always @(posedge clk) begin
        // if reset, set counter to 0
        if (reset) begin
            test_reg <= 0;
            //digit <= 0;
        end else begin
            for( int i = 0; i < NUMBER_OF_CHANNELS; i = i + 1 ) begin
                channels[i] = channels[i] >> NUMBER_OF_BITS;
                channels[BUFFER_SIZE-1:BUFFER_SIZE-NUMBER_OF_BITS] = ui_in;
            end

        end
    end

endmodule
