# 50 MHz board clock; the 25 MHz pixel clock comes from video_pll (derive_pll_clocks reads it).
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty
# The two domains only meet through cdc_latch (toggle synchroniser + stable bundle) and the profile
# view RAM (a debug view); treat them as asynchronous.
set_clock_groups -asynchronous -group [get_clocks CLOCK_50] -group [get_clocks {*video_pll*}]
