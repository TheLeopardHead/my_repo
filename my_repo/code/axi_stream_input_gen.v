module axi_stream_input_gen #(
parameter DATA_WD = 32,
parameter DATA_BYTE_WD = DATA_WD / 8,
parameter NUM_PACKETS_PER_STREAM = 10 // number of package
)(
input wire clk,
input wire rst_n,
input wire axi_tready,
output wire axi_tvalid,
output wire axi_tlast,
output wire [DATA_BYTE_WD-1 : 0] axi_keep,
output wire [DATA_WD-1 : 0] axi_tdata
);

// wire clk;
// wire rst_n;
// wire axi_tvalid;
// wire axi_tlast;
// wire axi_keep;
// wire [DATA_WD-1 : 0] axi_tdata;

reg [DATA_WD-1 : 0] axi_tdata_pre;
reg [4:0] packet_count; // count for number of package
reg [31:0] stream_count; // count for number of stream

//define axi_tvalid
assign axi_tvalid = (axi_tdata == 0)? 0 : 1;

//data generation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        axi_tdata_pre <= 0;
    else
        if (axi_tready) 
            axi_tdata_pre <= $random;
        else
            axi_tdata_pre <= axi_tdata_pre;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        packet_count <= 0;
    else    
        if (axi_tready & (packet_count < NUM_PACKETS_PER_STREAM - 1))
            packet_count <= packet_count + 1;
        else
            packet_count <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        stream_count <= 0;
    else    
        if (axi_tready & axi_tvalid & (packet_count == NUM_PACKETS_PER_STREAM - 1))
            stream_count <= stream_count + 1;
        else
            stream_count <= 0;
end

assign axi_tlast = (packet_count == NUM_PACKETS_PER_STREAM - 1)? 1 : 0;

assign axi_keep = (axi_tlast)? 4'b1110 : (axi_tready & axi_tvalid)? 4'b1111 : 0;

// Output axi_tdata_pre on valid signal
assign axi_tdata = axi_tdata_pre;
assign axi_tvalid = (axi_tdata == 0)? 0 : 1;

endmodule
