// SPDX-License-Identifier: MIT
//
// MIT License
//
// Copyright (c) 2026 Che-Ping Lin (Ace Lin)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

// ============================================================
// Module: qcal_pulse_sequencer_stub
// Description: Stub pulse/window sequencer: generates shot_tick and window control for a fixed number of shots per poll (simulation model).
// ============================================================
`timescale 1ns/1ps
module qcal_pulse_sequencer_stub (
  input  logic clk, input logic rst_n,
  input  logic seq_start,
  input  logic [15:0] nshots,
  output logic win_active,
  output logic shot_tick,
  output logic win_done
);
  logic [15:0] cnt;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin win_active<=0; shot_tick<=0; win_done<=0; cnt<=0; end
    else begin
      shot_tick<=0; win_done<=0;
      if (seq_start && !win_active) begin win_active<=1; cnt<=0; end
      else if (win_active) begin
        shot_tick<=1;
        cnt<=cnt+1;
        if (cnt==(nshots-1)) begin win_active<=0; win_done<=1; end
      end
    end
  end
endmodule
