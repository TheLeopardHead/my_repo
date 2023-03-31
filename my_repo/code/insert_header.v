module insert_headeraxi_stream_insert_header #(
parameter DATA_WD = 32,
parameter DATA_BYTE_WD = DATA_WD / 8,
parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
input wire clk,
input wire rst_n,
// AXI Stream input original data
input wire valid_in,
input wire [DATA_WD-1 : 0] data_in,
input wire [DATA_BYTE_WD-1 : 0] keep_in,
input wire last_in,
output wire ready_in,
// AXI Stream output with header inserted
output wire valid_out,
output wire [DATA_WD-1 : 0] data_out,
output wire [DATA_BYTE_WD-1 : 0] keep_out,
output wire last_out,
input wire ready_out,
// The header to be inserted to AXI Stream input
input wire valid_insert,
input wire [DATA_WD-1 : 0] data_insert,
input wire [DATA_BYTE_WD-1 : 0] keep_insert,
input wire [BYTE_CNT_WD-1 : 0] byte_insert_cnt,
output wire ready_insert
);
// Your code here

// wire clk;
// wire rst_n;
// // AXI Stream input original data
// wire valid_in;
// wire [DATA_WD-1 : 0] data_in;
// wire [DATA_BYTE_WD-1 : 0] keep_in;
// wire last_in;
// wire ready_in;
// // AXI Stream output with header inserted
// wire valid_out;
// wire [DATA_WD-1 : 0] data_out;
// wire [DATA_BYTE_WD-1 : 0] keep_out;
// wire last_out;
// wire ready_out;
// // The header to be inserted to AXI Stream input
// wire valid_insert;
// wire [DATA_WD-1 : 0] data_insert;
// wire [DATA_BYTE_WD-1 : 0] keep_insert;
// wire [BYTE_CNT_WD-1 : 0] byte_insert_cnt;
// wire ready_insert;

parameter STREAM_LENGTH = 6;
parameter ODELAY_PERIOD = 3;

//define valid_out
assign valid_out = (data_out == 0)? 0 : 1;

//define ready_insert
assign ready_insert = valid_in & ready_in;

//define data_in_r
reg [DATA_WD-1 : 0] data_in_r;
always @(posedge clk or negedge rst_n)  begin
    if(!rst_n)
        data_in_r <= 0;
    else
        data_in_r <= data_in;
end

//define data_insert_r
reg [DATA_WD-1 : 0] data_insert_r;
always @(posedge clk or negedge rst_n)  begin
    if(!rst_n)
        data_insert_r <= 0;
    else
        data_insert_r <= data_insert;
end

//define last_delay_cnt
reg [3:0] last_delay_cnt;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        last_delay_cnt <= 0;
    else
        if(last_delay_cnt == ODELAY_PERIOD)         
            last_delay_cnt <= 0;
        else
            if(last_in | (last_delay_cnt != 0))
                last_delay_cnt <= last_delay_cnt + 1;
end

//define datain_counter, counting the numbers of data_in
reg [STREAM_LENGTH-1:0] datain_counter; 
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        datain_counter <= 0;
    else
        if(last_in)
            datain_counter <= 0;
        else
            if(valid_in & ready_in)
                datain_counter <= datain_counter + 1;
            else
                datain_counter <= 0;
end

//if there is a header inserted to the stream, flag_insert will be pull up
reg flag_insert;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        flag_insert <= 0;
    else
        if(last_in)
            flag_insert <= 0;
        else
            if(valid_in & ready_in & valid_insert & ready_insert & !valid_out & (datain_counter == 0))
                flag_insert <= 1;
            else
                flag_insert <= flag_insert;
end

reg flag_insert_r;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        flag_insert_r <= 0;
    else
        flag_insert_r <= flag_insert;
end

reg flag_insert_rr;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        flag_insert_rr <= 0;
    else
        flag_insert_rr <= flag_insert_r;
end

//if there is a inserted header, header_out is the first DATA_WD of data_out
wire [DATA_WD-1 : 0] header_out;

assign header_out = (flag_insert)? ((data_insert_r << 8*(DATA_BYTE_WD-byte_insert_cnt)) ^ (data_in_r >> 8*byte_insert_cnt)) : 0;

//if there is a inserted header, flag_header_out is uesd to indicate that header_out is currently being transmitted
wire flag_header_out;

assign flag_header_out = ({flag_insert , flag_insert_r} == 2'b10)? 1 : 0;

//if there is a inserted header, data_buffer is a bunch of data after header_out
reg [DATA_WD-1 : 0] data_buffer;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        data_buffer <= 0;
    else    
        if(flag_insert | flag_insert_r)
            data_buffer <= (data_in_r << 8*(DATA_BYTE_WD-byte_insert_cnt));
        else
            data_buffer <= 0;
end

//define data_out and data_out_pre
reg [DATA_WD-1 : 0] data_out_pre;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        data_out_pre <= 0;
    else
        if({(flag_insert | flag_insert_r) , flag_header_out} == 2'b11)
            data_out_pre <= header_out;
        else
            if({(flag_insert | flag_insert_r | flag_insert_rr) , flag_header_out} == 2'b10)
                data_out_pre <= (data_buffer ^ (data_in_r >> 8*byte_insert_cnt));
            else
                if(last_delay_cnt == 3)
                    data_out_pre <= 0;
                else
                    data_out_pre <= data_in_r;
end

assign data_out = data_out_pre;

//define byte_datain_cnt and byte_datain_cnt_r
reg [BYTE_CNT_WD-1 : 0] byte_datain_cnt;

integer i;
always @(*) begin
    byte_datain_cnt = 0;
        for (i=0; i<DATA_BYTE_WD; i=i+1) begin
            if (keep_in[i]==1'b1) begin
                byte_datain_cnt = byte_datain_cnt + keep_in[i];
        end
    end
end

reg [BYTE_CNT_WD-1 : 0] byte_datain_cnt_r;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        byte_datain_cnt_r <= 0;
    else
        if(last_in)
            byte_datain_cnt_r <= byte_datain_cnt;
        else
            byte_datain_cnt_r <= byte_datain_cnt_r;
end 

//define byte_insert_cnt_r
reg [BYTE_CNT_WD-1 : 0] byte_insert_cnt_r;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        byte_insert_cnt_r <= 0;
    else
        if(!(flag_insert | flag_insert_r))
            byte_insert_cnt_r <= 0;
        else
            if(last_in)
                byte_insert_cnt_r <= byte_insert_cnt;
            else
                byte_insert_cnt_r <= byte_insert_cnt_r;
end 


//define last_out
reg last_out_pre;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        last_out_pre <= 0;
    else
        if((byte_datain_cnt_r + byte_insert_cnt_r) <= 4)
            last_out_pre  = (last_delay_cnt == 1);
        else
            last_out_pre  = (last_delay_cnt == 2);
end

assign last_out = last_out_pre;

//define ready_in
assign ready_in = ((last_delay_cnt == 0) & !last_in)? 1 : 0;

//define keep_out


endmodule
