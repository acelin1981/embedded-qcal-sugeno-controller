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

package qcal_pkg;
  parameter int FP_W = 16;
  parameter int FP_F = 12;
  typedef logic signed [FP_W-1:0] fp_t;

  function automatic fp_t fp_from_int(input int x);
    fp_from_int = fp_t'(x <<< FP_F);
  endfunction

  function automatic fp_t fp_from_real(input real x);
    fp_from_real = fp_t'($rtoi(x * (1<<FP_F)));
  endfunction

  function automatic fp_t fp_sat32(input logic signed [31:0] x);
    logic signed [31:0] maxv, minv;
    begin
      maxv = (32'sh1 <<< (FP_W-1)) - 1;
      minv = -(32'sh1 <<< (FP_W-1));
      if (x > maxv) fp_sat32 = fp_t'(maxv[FP_W-1:0]);
      else if (x < minv) fp_sat32 = fp_t'(minv[FP_W-1:0]);
      else fp_sat32 = fp_t'(x[FP_W-1:0]);
    end
  endfunction

  function automatic fp_t fp_abs(input fp_t x);
    if (x[FP_W-1]) fp_abs = -x;
    else fp_abs = x;
  endfunction

  function automatic logic [31:0] sx16_to32(input fp_t x);
    sx16_to32 = {{16{x[FP_W-1]}}, x};
  endfunction
endpackage
