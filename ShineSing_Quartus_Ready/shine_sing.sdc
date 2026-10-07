create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
create_clock -name AUD_BCLK -period 325.521 [get_ports AUD_BCLK]
derive_pll_clocks
derive_clock_uncertainty
# All four functional domains exchange data only through held-payload mailboxes.
# Group derived clocks by PLL, including their internal VCO clocks. Do not ask the
# fitter to close arbitrary 50 MHz / fractional audio PLL phase relationships.
set_clock_groups -asynchronous -group [get_clocks CLOCK_50] -group [get_clocks AUD_BCLK] -group [get_clocks {*audio_pll*}] -group [get_clocks {*pixel_pll*}]
# Cut only the first synchronizer stage and held mailbox payload capture paths.
# Source payload is held for the entire request/acknowledge round trip.
set_false_path -to [get_registers {*|ack_sync[0] *|req_sync[0]}]
set_false_path -from [get_registers {*|payload[*]}] -to [get_registers {*|dst_data[*]}]
set_false_path -from [get_ports {KEY[*] SW[*]}] -to [get_registers {*|sync1[*] *|pipe[*]}]
# LJ serial data is launched on the falling BCLK edge; board flight allowance 10 ns.
set_input_delay -clock AUD_BCLK -clock_fall -max 10.0 [get_ports {AUD_ADCDAT AUD_ADCLRCK}]
set_input_delay -clock AUD_BCLK -clock_fall -min 0.0 [get_ports {AUD_ADCDAT AUD_ADCLRCK}]
