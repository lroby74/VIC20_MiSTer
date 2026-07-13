//-----------------------------------------------------------------------------
// VIC20 C1530 IEC Interface - Tape Control Module
// Extracted from C64_MiSTer fpga64_sid_iec.vhd and adapted for VIC20
// Contains tape control signals: PLAY, STOP, REW (Rewind), FF (Fast Forward), Counter Reset
// Plus cassette motor control and tape read/write signals
//-----------------------------------------------------------------------------

module vic20_c1530_iec (
	input  logic        clk32,
	input  logic        reset_n,
	
	// Tape control outputs (command pulses from OSD/keyboard)
	output logic        tape_play,
	output logic        tape_rew,
	output logic        tape_stop,
	output logic        tape_ff,
	output logic        tape_reset_counter,
	
	// Cassette interface
	output logic        cass_motor,
	output logic        cass_write,
	input  logic        cass_sense,
	input  logic        cass_read,
	output logic        cass_run,
	
	// Keyboard interface for tape shortcuts
	input  logic        mod_key,        // Modifier key (Shift+Ctrl)
	input  logic [10:0] ps2_key,        // PS2 keyboard input
	
	// VIA user port (for VIC20)
	input  logic [7:0]  via_pb_out,     // VIA Port B output
	input  logic [7:0]  via_pb_dir      // VIA Port B data direction
);

// Tape control command registers
logic tape_play_r;
logic tape_rew_r;
logic tape_stop_r;
logic tape_ff_r;
logic tape_reset_counter_r;

// Keyboard scanning signals
logic        extended;
logic        pressed;
logic [10:0] ps2_key_prev;

// Cassette control
logic cass_motor_r;
logic cass_write_r;

always_ff @(posedge clk32 or negedge reset_n) begin
	if (!reset_n) begin
		tape_play_r <= 1'b0;
		tape_rew_r <= 1'b0;
		tape_stop_r <= 1'b0;
		tape_ff_r <= 1'b0;
		tape_reset_counter_r <= 1'b0;
		cass_motor_r <= 1'b0;
		cass_write_r <= 1'b0;
		ps2_key_prev <= 11'h000;
	end else begin
		// Tape control pulses - only active for one cycle
		tape_play_r <= 1'b0;
		tape_rew_r <= 1'b0;
		tape_stop_r <= 1'b0;
		tape_ff_r <= 1'b0;
		tape_reset_counter_r <= 1'b0;
		
		// Detect PS2 key changes
		ps2_key_prev <= ps2_key;
		
		if (ps2_key[10] != ps2_key_prev[10]) begin
			pressed <= ps2_key[9];
			extended <= ps2_key[8];
			
			// Tape control shortcuts with modifier key
			if (mod_key) begin
				case (ps2_key[7:0])
					8'h6B: tape_rew_r <= pressed;              // Numpad-4 + Mod = Rewind
					8'h71: tape_reset_counter_r <= pressed;  // Numpad-Del + Mod = Counter Reset
					8'h72: tape_stop_r <= pressed;            // Numpad-2 + Mod = Stop
					8'h74: tape_ff_r <= pressed;              // Numpad-6 + Mod = Fast Forward
					8'h75: tape_play_r <= pressed;            // Numpad-8 + Mod = Play
					8'h7D: if (extended) tape_play_r <= pressed; // Extended key for Play
					default: ;
				endcase
			end
		end
		
		// Cassette motor control from VIA Port B
		// Bit 5 of VIA PB controls motor (0 = on, 1 = off)
		cass_motor_r <= via_pb_out[5] | ~via_pb_dir[5];
		
		// Cassette write signal from VIA Port B
		// Bit 3 of VIA PB controls write signal
		cass_write_r <= via_pb_out[3] | ~via_pb_dir[3];
	end
end

// Output assignments
assign tape_play = tape_play_r;
assign tape_rew = tape_rew_r;
assign tape_stop = tape_stop_r;
assign tape_ff = tape_ff_r;
assign tape_reset_counter = tape_reset_counter_r;

assign cass_motor = cass_motor_r;
assign cass_write = cass_write_r;
assign cass_run = cass_motor_r;  // Motor momentum is handled in c1530 module

endmodule
