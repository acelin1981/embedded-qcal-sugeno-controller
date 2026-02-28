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
// Module: qcal_rule_mem_singleton
// Description: 9-entry singleton consequent table D0..D8 with reset defaults, optional manual write, and dual read ports (core + debug).
// ============================================================
`timescale 1ns/1ps

module qcal_rule_mem_singleton (
  input  logic clk,
  input  logic rst_n,

  // manual write
  input  logic manual_en,
  input  logic manual_wr_en,
  input  logic [3:0] manual_addr,
  input  logic signed [15:0] manual_delta,

  // read port 0 (controller)
  input  logic [3:0] rd0_addr,
  output logic signed [15:0] rd0_delta,

  // read port 1 (debug/APB)
  input  logic [3:0] rd1_addr,
  output logic signed [15:0] rd1_delta
);
  localparam int FP_W = 16;
  typedef logic signed [FP_W-1:0] fp_t;

  fp_t D [0:8];

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      D[0] <= 16'sd  384;  D[1] <= 16'sd  256;  D[2] <= 16'sd  128;
      D[3] <= 16'sd   96;  D[4] <= 16'sd    0;  D[5] <= -16'sd  96;
      D[6] <= -16'sd 128;  D[7] <= -16'sd 256;  D[8] <= -16'sd 384;
    end else if (manual_en && manual_wr_en) begin
      if (manual_addr < 9) D[manual_addr] <= manual_delta;
    end
  end

  always_comb begin
    rd0_delta = (rd0_addr < 9) ? D[rd0_addr] : '0;
    rd1_delta = (rd1_addr < 9) ? D[rd1_addr] : '0;
  end
endmodule
