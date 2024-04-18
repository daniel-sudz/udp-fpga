// Test module for Arty cycles the LEDs

module leds(mainclk,
led0_b,led0_g,led0_r,
led1_b,led1_g,led1_r,
led2_b,led2_g,led2_r,
led3_b,led3_g,led3_r);

input wire mainclk;
output logic led0_b,led0_g,led0_r;
output logic led1_b,led1_g,led1_r;
output logic led2_b,led2_g,led2_r;
output logic led3_b,led3_g,led3_r;

logic [31:0] led0_counter;
logic [31:0] led1_counter;
logic [31:0] led2_counter;
logic [31:0] led3_counter;
logic [2:0] global_led_pwm;

always_comb begin : LED_drivers
    if(&global_led_pwm) begin
        led0_b = led0_counter[26];
        led1_b = led1_counter[26];
        led2_b = led2_counter[26];
        led3_b = led3_counter[26];
        led0_g = led0_counter[27];
        led1_g = led1_counter[27];
        led2_g = led2_counter[27];
        led3_g = led3_counter[27];
        led0_r = led0_counter[28];
        led1_r = led1_counter[28];
        led2_r = led2_counter[28];
        led3_r = led3_counter[28];
    end else begin
        led0_b = 0;
        led1_b = 0;
        led2_b = 0;
        led3_b = 0;
        led0_g = 0;
        led1_g = 0;
        led2_g = 0;
        led3_g = 0;
        led0_r = 0;
        led1_r = 0;
        led2_r = 0;
        led3_r = 0;
    end
end

always_ff @(posedge mainclk ) begin : LED_counters
    led0_counter <= led0_counter + 1;
    led1_counter <= led1_counter + 3;
    led2_counter <= led2_counter + 5;
    led3_counter <= led3_counter + 7;
    global_led_pwm <= global_led_pwm + 1;
end

endmodule