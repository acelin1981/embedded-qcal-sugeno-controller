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
// Module: qcal_membership_tri
// Description: Symmetric triangular membership functions for fuzzification of e and de into N/Z/P degrees (fixed-point, piecewise-linear).
// ============================================================
`timescale 1ns/1ps
module qcal_membership_tri #(
  parameter int IN_W = 16,
  parameter logic signed [IN_W-1:0] N0 = -16'sd4096,
  parameter logic signed [IN_W-1:0] N1 =  16'sd0,
  parameter logic signed [IN_W-1:0] Z1 =  16'sd2048,
  parameter logic signed [IN_W-1:0] P0 =  16'sd4096,
  parameter logic signed [IN_W-1:0] P1 =  16'sd0
)(
  input  logic signed [IN_W-1:0] x,
  output logic [15:0] mu_neg,
  output logic [15:0] mu_zero,
  output logic [15:0] mu_pos
);
  function automatic logic [15:0] clamp01_q16(input logic signed [31:0] v);
    logic signed [31:0] t;
    begin
      t=v; if(t<0) t=0; if(t>32'sh0001_0000) t=32'sh0001_0000; clamp01_q16=t[15:0];
    end
  endfunction

  function automatic logic [15:0] ramp01(
    input logic signed [IN_W-1:0] xin,
    input logic signed [IN_W-1:0] xa,
    input logic signed [IN_W-1:0] xb,
    input bit rising
  );
    logic signed [31:0] num, den, frac_q16;
    logic signed [31:0] tmp_q16;
    begin
      den = (xb-xa);
      if (den==0) ramp01 = rising ? 16'hFFFF : 16'h0000;
      else begin
        num = (xin-xa) <<< 16;
        frac_q16 = num/den;
        frac_q16 = {16'h0, clamp01_q16(frac_q16)};
        if (rising) ramp01 = frac_q16[15:0];
        else begin
          // Icarus Verilog: avoid slicing an expression directly.
          tmp_q16 = 32'sh0001_0000 - frac_q16;
          ramp01 = tmp_q16[15:0];
        end
      end
    end
  endfunction

  // Icarus Verilog: prefer plain always @* over always_comb
  always @* begin
    if (x<=N0) mu_neg=16'hFFFF; else if (x>=N1) mu_neg=16'h0000; else mu_neg=ramp01(x,N0,N1,1'b0);
    if (x>=P0) mu_pos=16'hFFFF; else if (x<=P1) mu_pos=16'h0000; else mu_pos=ramp01(x,P1,P0,1'b1);

    if (x==0) mu_zero=16'hFFFF;
    else if (x>=Z1 || x<=-Z1) mu_zero=16'h0000;
    else if (x>0) mu_zero=ramp01(x,0,Z1,1'b0);
    else mu_zero=ramp01(x,-Z1,0,1'b1);
  end
endmodule
