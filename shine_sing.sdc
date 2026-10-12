create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
create_clock -name AUD_BCLK -period 325.521 [get_ports AUD_BCLK]
derive_pll_clocks
derive_clock_uncertainty
# The four clock groups share data through mailboxes that hold it steady.
# Group each PLL with its internal clocks.
# Treat the 50 MHz and audio PLL clocks as separate clocks.
set_clock_groups -asynchronous -group [get_clocks CLOCK_50] -group [get_clocks AUD_BCLK] -group [get_clocks {*audio_pll*}] -group [get_clocks {*pixel_pll*}]
# Skip timing checks at the first sync stage and mailbox data capture.
# Keep source data steady until the receiver replies.
set_false_path -to [get_registers {*|ack_sync[0] *|req_sync[0]}]
set_false_path -from [get_registers {*|payload[*]}] -to [get_registers {*|dst_data[*]}]
set_false_path -from [get_ports {KEY[*] SW[*]}] -to [get_registers {*|sync1[*] *|pipe[*]}]
# Audio data starts on falling BCLK; allow 10 ns for board travel.
set_input_delay -clock AUD_BCLK -clock_fall -max 10.0 [get_ports {AUD_ADCDAT AUD_ADCLRCK}]
set_input_delay -clock AUD_BCLK -clock_fall -min 0.0 [get_ports {AUD_ADCDAT AUD_ADCLRCK}]
