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
// Module: qcal_meas_stats
// Description: Windowed statistics accumulator: counts ones and total shots, then emits stats_valid at window end.
// ============================================================
`timescale 1ns/1ps
module qcal_meas_stats #(
  parameter integer DBG = 1
) (
  input  logic clk, input logic rst_n,
  input  logic win_active,
  input  logic meas_valid,
  input  logic meas_bit,
  output logic [15:0] count1,
  output logic [15:0] N_total,
  output logic stats_valid
);
  logic win_active_d;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin count1<=0; N_total<=0; stats_valid<=0; win_active_d<=0; end
    else begin
      stats_valid<=0;
      win_active_d<=win_active;
      if (win_active && !win_active_d) begin count1<=0; N_total<=0; end
      if (win_active && meas_valid) begin
        N_total<=N_total+1;
        if (meas_bit) count1<=count1+1;
      end
      if (!win_active && win_active_d) begin stats_valid<=1; if (DBG) $display("[STDBG] t=%0t count1=%0d N=%0d", $time, count1, N_total); end
    end
  end
endmodule
