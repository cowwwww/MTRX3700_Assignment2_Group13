Paste this into draw.io: **Extras → Edit Diagram → select all → paste → OK**. Or save it as `shine_sing_block.drawio` and open it.

It's laid out as four horizontal lanes, one per clock domain, with the three mailbox crossings drawn in red dashed lines.

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Shine &amp; Sing block diagram" id="blk1">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="826" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />

        <!-- ===================== DOMAIN 1: AUD_BCLK ===================== -->
        <mxCell id="d1" value="AUD_BCLK domain — 3.072 MHz (from codec, master mode)" style="swimlane;horizontal=0;startSize=28;fillColor=#dae8fc;strokeColor=#6c8ebf;fontStyle=1;align=center;verticalAlign=middle;" vertex="1" parent="1">
          <mxGeometry x="40" y="40" width="1080" height="110" as="geometry" />
        </mxCell>
        <mxCell id="mic_in" value="MIC jack&#10;WM8731 codec&#10;(external)" style="rounded=0;whiteSpace=wrap;html=1;dashed=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="d1">
          <mxGeometry x="50" y="25" width="130" height="60" as="geometry" />
        </mxCell>
        <mxCell id="mic_load" value="mic_load.sv&#10;(reused, L3 2.2)&#10;left-justified RX" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#6c8ebf;" vertex="1" parent="d1">
          <mxGeometry x="250" y="25" width="150" height="60" as="geometry" />
        </mxCell>
        <mxCell id="e_mic" value="ADCDAT / BCLK / ADCLRC&#10;1 bit serial" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d1" source="mic_in" target="mic_load">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="n_mic" value="1 PCM sample per 64 BCLK = 48 kHz, signed 16-bit" style="text;html=1;fontSize=9;fontColor=#333333;align=left;" vertex="1" parent="d1">
          <mxGeometry x="450" y="40" width="300" height="20" as="geometry" />
        </mxCell>

        <!-- ===================== DOMAIN 2: FFT CLOCK ===================== -->
        <mxCell id="d2" value="PLL domain — 18.432 MHz (audio DSP + classifier)" style="swimlane;horizontal=0;startSize=28;fillColor=#d5e8d4;strokeColor=#82b366;fontStyle=1;align=center;verticalAlign=middle;" vertex="1" parent="1">
          <mxGeometry x="40" y="190" width="1080" height="210" as="geometry" />
        </mxCell>
        <mxCell id="frontend" value="audio_frontend.sv&#10;41-tap FIR (Q16, s40 acc, &gt;&gt;18, sat PCM16)&#10;/4 decimate → 12 kHz&#10;Hamming ROM 1024 × Q1.15&#10;2 × 1024 ping-pong banks" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#82b366;fontSize=10;" vertex="1" parent="d2">
          <mxGeometry x="50" y="30" width="200" height="90" as="geometry" />
        </mxCell>
        <mxCell id="fft" value="FFT (provided)&#10;radix-2² SDF, 1024-pt&#10;out: bit-reversed, 1/N scaled" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontSize=10;" vertex="1" parent="d2">
          <mxGeometry x="285" y="40" width="160" height="70" as="geometry" />
        </mxCell>
        <mxCell id="magsq" value="fft_mag_sq.sv&#10;(reused)&#10;2 × s16×16 → u33" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#82b366;fontSize=10;" vertex="1" parent="d2">
          <mxGeometry x="480" y="40" width="140" height="70" as="geometry" />
        </mxCell>
        <mxCell id="feat" value="audio_features.sv&#10;bit-reverse index&#10;8 bands, bins 8–511&#10;8 × u48 accum + u48 total&#10;16-cycle restoring divider" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#82b366;fontSize=10;" vertex="1" parent="d2">
          <mxGeometry x="655" y="30" width="180" height="90" as="geometry" />
        </mxCell>
        <mxCell id="clf" value="classifier.sv (provided)&#10;L1 nearest template&#10;M=3 vote, DMAX=50000&#10;ρ=7/10, conf ≥ 76" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontSize=10;" vertex="1" parent="d2">
          <mxGeometry x="870" y="30" width="170" height="90" as="geometry" />
        </mxCell>
        <mxCell id="gate" value="audio_level.sv (gate)&#10;level = mean|x| over 256 samples (5.33 ms)&#10;noise trained 188 blocks ≈ 1.003 s&#10;open 2·nf+64 / close nf+64&#10;dB = 20log10(level), 00–90" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#82b366;fontSize=10;" vertex="1" parent="d2">
          <mxGeometry x="285" y="130" width="335" height="65" as="geometry" />
        </mxCell>

        <mxCell id="e1" value="windowed s16&#10;12 kHz" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d2" source="frontend" target="fft">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" value="do_re/do_im s16" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d2" source="fft" target="magsq">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" value="mag_sq u33&#10;+ valid" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d2" source="magsq" target="feat">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e4" value="feature[7:0][15:0] Q0.16&#10;+ feature_valid, 1 pulse / 85.33 ms frame" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d2" source="feat" target="clf">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e5" value="enable (voice gate)&#10;closing clears vote" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;dashed=1;" edge="1" parent="d2" source="gate" target="clf">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>

        <!-- ===================== DOMAIN 3: 50 MHz ===================== -->
        <mxCell id="d3" value="50 MHz oscillator domain — config, controls, image analysis, game" style="swimlane;horizontal=0;startSize=28;fillColor=#ffe6cc;strokeColor=#d79b00;fontStyle=1;align=center;verticalAlign=middle;" vertex="1" parent="1">
          <mxGeometry x="40" y="440" width="1080" height="230" as="geometry" />
        </mxCell>
        <mxCell id="codec_cfg" value="codec_config.sv&#10;11 WM8731 I2C writes&#10;(R9 Active last)" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#d79b00;fontSize=10;" vertex="1" parent="d3">
          <mxGeometry x="50" y="25" width="150" height="60" as="geometry" />
        </mxCell>
        <mxCell id="ctrls" value="board_controls.sv&#10;debounce; SW0 + KEY1/KEY2&#10;threshold ±8; KEY3 enrol" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#d79b00;fontSize=10;" vertex="1" parent="d3">
          <mxGeometry x="50" y="110" width="150" height="70" as="geometry" />
        </mxCell>
        <mxCell id="imgrom" value="image_store.sv&#10;3 × 320×240 8-bit ROM&#10;(piano0/1/2.mif)&#10;dual port: 50 MHz + 25 MHz" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#d79b00;fontSize=10;" vertex="1" parent="d3">
          <mxGeometry x="245" y="30" width="180" height="80" as="geometry" />
        </mxCell>
        <mxCell id="detector" value="piano_detector.sv  (FSM)&#10;sweep 1 px / 3 clk&#10;SW5: |I[x]−I[x−1]| or conv3x3 Sobel&#10;profile rows 0.70H–0.85H, u20&#10;normalise 0–255 (8-cyc divider)&#10;NMS → hysteresis 96 / 32&#10;MIN_GAP = 12, max 16 boundaries" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#d79b00;fontSize=10;" vertex="1" parent="d3">
          <mxGeometry x="470" y="25" width="230" height="110" as="geometry" />
        </mxCell>
        <mxCell id="edgebuf" value="edge-map RAM&#10;double-buffered&#10;4 bits/px display&#10;(full precision → profile)" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;fontSize=10;" vertex="1" parent="d3">
          <mxGeometry x="470" y="150" width="230" height="60" as="geometry" />
        </mxCell>
        <mxCell id="game" value="game.sv  (new wrapper)&#10;beat = 500 ms, hit window = 1 beat&#10;fixed 2-beat countdown, cyclic lanes&#10;+ 4 × reaction_time_fsm.sv (A1, 1 change)&#10;+ game_controller.sv (A1, unchanged)" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#d79b00;fontSize=10;" vertex="1" parent="d3">
          <mxGeometry x="745" y="25" width="290" height="110" as="geometry" />
        </mxCell>
        <mxCell id="hex" value="HEX5–HEX0, LEDR&#10;peak bin / vowel / dB / bar" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;fontSize=10;" vertex="1" parent="d3">
          <mxGeometry x="745" y="155" width="290" height="50" as="geometry" />
        </mxCell>
        <mxCell id="e6" value="8-bit px&#10;+ (x, y)" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d3" source="imgrom" target="detector">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e7" value="edge px" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d3" source="detector" target="edgebuf">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e8" value="4 lane boundaries" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d3" source="detector" target="game">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e9" value="thresholds" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;dashed=1;" edge="1" parent="d3" source="ctrls" target="detector">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>

        <!-- ===================== DOMAIN 4: 25 MHz ===================== -->
        <mxCell id="d4" value="PLL domain — 25 MHz pixel clock (Avalon-ST video)" style="swimlane;horizontal=0;startSize=28;fillColor=#e1d5e7;strokeColor=#9673a6;fontStyle=1;align=center;verticalAlign=middle;" vertex="1" parent="1">
          <mxGeometry x="40" y="710" width="1080" height="110" as="geometry" />
        </mxCell>
        <mxCell id="vsrc" value="video_source.sv&#10;Avalon-ST source, 640×480 @ 60 Hz&#10;30-bit RGB (3 × 8 + 2 pad)&#10;views: game / edge map / profile / masks&#10;ROM lookahead only on valid &amp; ready" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#9673a6;fontSize=10;" vertex="1" parent="d4">
          <mxGeometry x="245" y="20" width="275" height="80" as="geometry" />
        </mxCell>
        <mxCell id="vsink" value="vga_sink.qsys&#10;VGA Controller IP&#10;(University Program)" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontSize=10;" vertex="1" parent="d4">
          <mxGeometry x="580" y="30" width="170" height="60" as="geometry" />
        </mxCell>
        <mxCell id="mon" value="VGA DAC&#10;→ monitor" style="rounded=0;whiteSpace=wrap;html=1;dashed=1;fillColor=#f5f5f5;strokeColor=#666666;fontSize=10;" vertex="1" parent="d4">
          <mxGeometry x="810" y="35" width="120" height="50" as="geometry" />
        </mxCell>
        <mxCell id="e10" value="data[29:0], valid, ready&#10;startofpacket / endofpacket" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=9;" edge="1" parent="d4" source="vsrc" target="vsink">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e11" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="d4" source="vsink" target="mon">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>

        <!-- ===================== CDC CROSSINGS (red dashed) ===================== -->
        <mxCell id="cdc1" value="cdc_mailbox #1&#10;req / ack handshake&#10;16-bit PCM payload" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;fontStyle=1;fontSize=10;" vertex="1" parent="1">
          <mxGeometry x="180" y="155" width="170" height="40" as="geometry" />
        </mxCell>
        <mxCell id="xa" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#b85450;strokeWidth=2;dashed=1;" edge="1" parent="1" source="mic_load" target="cdc1">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="xb" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#b85450;strokeWidth=2;dashed=1;" edge="1" parent="1" source="cdc1" target="frontend">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>

        <mxCell id="cdc2" value="cdc_mailbox #2&#10;req / ack handshake&#10;result + confidence + reject" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;fontStyle=1;fontSize=10;" vertex="1" parent="1">
          <mxGeometry x="880" y="405" width="200" height="40" as="geometry" />
        </mxCell>
        <mxCell id="xc" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#b85450;strokeWidth=2;dashed=1;" edge="1" parent="1" source="clf" target="cdc2">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="xd" value="vowel = hit input" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#b85450;strokeWidth=2;dashed=1;fontSize=9;" edge="1" parent="1" source="cdc2" target="game">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>

        <mxCell id="cdc3" value="cdc_mailbox #3&#10;req / ack handshake — accepted ONLY in the 8-pixel-clock gap between packets&#10;payload: bank index, profile, boundaries, image index, score, note state" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;fontStyle=1;fontSize=10;" vertex="1" parent="1">
          <mxGeometry x="330" y="678" width="520" height="52" as="geometry" />
        </mxCell>
        <mxCell id="xe" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#b85450;strokeWidth=2;dashed=1;" edge="1" parent="1" source="edgebuf" target="cdc3">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="xf" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#b85450;strokeWidth=2;dashed=1;" edge="1" parent="1" source="cdc3" target="vsrc">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>

        <mxCell id="xg" value="port B, 8-bit px" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#9673a6;dashed=1;fontSize=9;exitX=0.25;exitY=1;entryX=0.1;entryY=0;" edge="1" parent="1" source="imgrom" target="vsrc">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>

        <!-- ===================== LEGEND ===================== -->
        <mxCell id="leg" value="Legend" style="swimlane;startSize=22;fillColor=none;strokeColor=#999999;fontSize=10;fontStyle=1;" vertex="1" parent="1">
          <mxGeometry x="40" y="840" width="1080" height="70" as="geometry" />
        </mxCell>
        <mxCell id="l1" value="white = module we wrote / modified" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#666666;fontSize=9;" vertex="1" parent="leg">
          <mxGeometry x="15" y="30" width="200" height="28" as="geometry" />
        </mxCell>
        <mxCell id="l2" value="yellow = provided IP (FFT, classifier, VGA)" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontSize=9;" vertex="1" parent="leg">
          <mxGeometry x="230" y="30" width="230" height="28" as="geometry" />
        </mxCell>
        <mxCell id="l3" value="red = clock-domain crossing (handshake)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;fontSize=9;" vertex="1" parent="leg">
          <mxGeometry x="475" y="30" width="230" height="28" as="geometry" />
        </mxCell>
        <mxCell id="l4" value="grey dashed = off-chip" style="rounded=0;whiteSpace=wrap;html=1;dashed=1;fillColor=#f5f5f5;strokeColor=#666666;fontSize=9;" vertex="1" parent="leg">
          <mxGeometry x="720" y="30" width="160" height="28" as="geometry" />
        </mxCell>
        <mxCell id="l5" value="All 4 domains are asynchronous clock groups in the .sdc." style="text;html=1;fontSize=9;align=left;" vertex="1" parent="leg">
          <mxGeometry x="890" y="30" width="180" height="28" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

Two things to fix before you submit it:

- Check the module names against your actual RTL. I took them from DESIGN.md, so `audio_level.sv` and `board_controls.sv` may be named differently in the repo.
- The specification wants every interface quantified and every crossing named on the diagram. I've put widths and rates on the edges, but double-check the ones I inferred rather than read, especially the edge-map payload contents.

Export as PDF or PNG, not JPEG, so the small text stays readable at 5-page scale.
