module BLDCVelocityController(
        input logic clk, reset,
        input logic [15:0] desired_velocity,
        input logic encoder_a, encoder_b,
       output logic pwm_phase_a, pwm_phase_b, pwm_phase_c,
       output logic bridge_side_a, bridge_side_b, bridge_side_c);

logic encoder_change;
logic encoder_direction; // unused

logic [31:0] encoder_count;
logic [31:0] time_per_tick;
logic [12:0] torque_vector_pos;
logic [15:0] raw_velocity;
logic [15:0] raw_velocity_mux_out;

logic reset_encoder_count;
logic apply_initial_commutation;

/// TODO: add synchronizer
QuadratureEncoder encoder_instance(.clk(clk),
                                   .sig_a(encoder_a), .sig_b(encoder_b),
                                   .encoder_count(encoder_count),
                                   .state_change(encoder_change),
                                   .direction(encoder_direction));

TickTimer tick_timer_instance( .clk(clk), .reset(reset),
                                .state_change(encoder_change),
                                .time_per_tick(time_per_tick));

motor_control_unit control_unit_instance(
                        .clk(clk),
                        .reset(reset),
                        .reset_encoder_count(reset_encoder_count),
                        .apply_initial_commutation(apply_initial_commutation));

TickTimeToVelocityLookup(.time_per_tick(time_per_tick[13:0]),
                         .velocity(raw_velocity));

assign raw_velocity_mux_out = (time_per_tick > 32'h000007FF) ?
                                    'b0 :
                                     raw_velocity;

iirFilter iir_filter_instance(
            .clk(clk), .reset(reset), .enable('b1),
            .raw_velocity(raw_velocity_mux_out),
            .filtered_velocity(filtered_velocity));

PIController pi_controller_instance(
                .clk(clk), .desired_velocity(desired_velocity),
                .actual_velocity(filtered_velocity),
                .kp(10), .ki(1),
                .output_gain(output_gain));

torque_vector_pos( .encoder_ticks(encoder_count[12:0]),
                   .direction(desired_velocity[15]),
                   .torque_vector_pos(torque_vector_pos));

fastModulo1170 fast_module_1170_instance(
                    .clk(clk), .reset(reset),
                    .encoder_input(torque_vector_pos),
                    .input_mod_1170(input_mod_1170));

motorCommutation motor_commutation_instance(
                    .clk(clk), .reset(reset), .enable(enable),
                    .gain(output_gain),
                    .cycle_position(input_mod_1170),
                    .pwm_phase_a(pwm_phase_a),
                    .pwm_phase_b(pwm_phase_b),
                    .pwm_phase_c(pwm_phase_c),
                    .bridge_side_a(bridge_side_a),
                    .bridge_side_b(bridge_side_b),
                    .bridge_side_c(bridge_side_c));
endmodule