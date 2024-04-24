// Driver I2S2 Protocol 24-bit
`timescale 1ns/1ps

module i2s2(rch1, rch2, wch1, wch2, datain, dataout, valid, lrclk, sclk, mclk, rst);

/*************************************************************************************************
* This module implements a multipurpose I2S (Inter-IC Sound) driver capable of converting analog 
* signals to digital format and vice versa, specifically designed for a 24-bit bit depth and a 
* 44.1kHz sampling rate. 44.1kHz is the standard CD sampling rate. CDs usually only use 16-bit
* audio, however, our module supports higher bit depths. Other sampling rates are supported but our
* FPGA might not be able to handle the required clock frequency. The module interfaces with audio data 
* through its inputs and outputs, utilizing a master clock (mclk), a left-right clock (lrclk), and 
* a serial clock (sclk) to manage the timing and synchronization of audio data transmission. We built
* this module to work with the Digilent Pmod I2S2.
*
* Inputs:
*   - datain: Serial input data stream.
*   - mclk: Main clock input, serves as the master clock for the module.
*   - lrclk: Left-Right clock input, determines the current channel (left or right) for audio data.
*   - sclk: Serial clock input, governs the serial data transmission timing.
*   - rst: Reset input, asynchronously resets the module to a known state.
*   - wch1, wch2: Input channels for writing audio data, 24 bits each.
*
* Outputs:
*   - rch1, rch2: Output channels for reading audio data, 24 bits each.
*   - dataout: Serial output data stream.
*   - valid: Output flag indicating valid data transfer.
*
* The module is set up to move between FSM states on clock edges, this is done via an
* edge detector that finds positive and negative edges. This ensures proper transitions.
*************************************************************************************************/


parameter N = 24; //unused

input wire datain, lrclk, sclk, mclk, rst;
input wire [N-1:0] wch1, wch2;
output logic [N-1:0] rch1, rch2;
output logic dataout, valid;

wire possclk, negsclk, poslrclk, neglrclk;
logic lredge;

logic [N-1:0] wlreg, wrreg;
logic [4:0] counter;
logic [2:0] delay;

  enum logic [2:0]{ //state variables for FSM (COM is legacy, unused)
  S_ERROR=0,
  S_IDLE=1,
  S_COM=2,
  S_REC=3
} state;

  enum logic { //state variables for SCLK sync
  S_LEFT=0,
  S_RIGHT=1
} lr_state;

edge_detector S(.clk(mclk), .rst(rst), .in(sclk), .positive_edge(possclk), .negative_edge(negsclk)); //SCLK edge detector relative to mclk
edge_detector LR(.clk(sclk), .rst(rst), .in(lrclk), .positive_edge(poslrclk), .negative_edge(neglrclk)); //LRCLK edge detector relative to sclk
always_comb lredge=poslrclk|neglrclk; //detect both edges of LRCLK

always_ff @(posedge mclk) begin //Left-Right transition FSM
    if(rst) begin //start on left channel
        lr_state<=S_LEFT;
        delay<=0;
    end
    if(&delay) begin //transition on lredge to opposite state
        if(lredge&(lr_state==S_RIGHT)) begin
            lr_state<=S_LEFT;
            delay<=0;
        end
        if(lredge&(lr_state==S_LEFT)) begin
            lr_state<=S_RIGHT;
            delay<=0;
        end
    end
    if(delay<7) begin //add delay to prevent switching multiple times per SCLK
        delay<=delay+1;
    end
end

// FSM driver
always_ff @(posedge mclk) begin
    if(rst) begin //reset system
        state<=S_IDLE;
        rch1<='0;
        rch2<='0;
        dataout<=1'b0;
        valid<=1'b1;
        counter<=0;
        wlreg<='0;
        wrreg<='0;
    end
    case(state)
        S_IDLE : begin
            dataout<=0;
            if(lredge) begin //if LRCLK changes, start I2S cycle
                state<=S_REC;
                counter<=0;
                if(lr_state==S_LEFT) begin
                    wlreg<=wch1;
                    wrreg<=wch2;
                end
            end
        end
        S_COM : begin //this state is unused for timing reasons
            if(negsclk|(lr_state==S_LEFT)) begin
                state<=S_REC;
                counter<=0;
                if(lr_state==S_LEFT) begin
                    wlreg<=wch1;
                    wrreg<=wch2;
                end
            end
        end
        S_REC : begin
            valid<=0;
            if(negsclk) begin //on negative edges, write data
                if(lr_state==S_LEFT) begin
                    dataout<=wlreg[23];
                    wlreg[23:1]<=wlreg[22:0];
                end
                if(lr_state==S_RIGHT) begin
                    dataout<=wrreg[23];
                    wrreg[23:1]<=wrreg[22:0];
                end
                counter<=counter+1;
            end
            if(possclk) begin //on positive edges, read data
                if(lr_state==S_LEFT) begin
                    rch1[0]<=datain;
                    rch1[23:1]<=rch1[22:0];
                end
                if(lr_state==S_RIGHT) begin
                    rch2[0]<=datain;
                    rch2[23:1]<=rch2[22:0];
                end
                if(counter>=5'd24) begin //return to IDLE after 24 datapoints
                    state<=S_IDLE;
                    valid<=1;
                end
            end
        end
    endcase
end

endmodule
