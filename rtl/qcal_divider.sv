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
// Module: qcal_divider
// Description: Unsigned iterative divider used by singleton Sugeno normalization (computes quotient = numerator/denominator).
// ============================================================
`timescale 1ns/1ps
module qcal_divider #(parameter int W=32)(
  input  logic clk, input logic rst_n, input logic start,
  input  logic [W-1:0] numerator, input logic [W-1:0] denominator,
  output logic busy, output logic done, output logic [W-1:0] quotient
);
  logic [W-1:0] denom_r, num_r, q;
  logic [W:0] rem;
  int cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin busy<=0; done<=0; quotient<='0; denom_r<='0; num_r<='0; q<='0; rem<='0; cnt<=0; end
    else begin
      done<=0;
      if(start && !busy) begin
        busy<=1; denom_r<=denominator; num_r<=numerator; q<='0; rem<='0; cnt<=W;
      end else if(busy) begin
        rem <= {rem[W-1:0], num_r[W-1]};
        num_r <= {num_r[W-2:0], 1'b0};
        if(rem >= {1'b0,denom_r}) begin rem <= rem - {1'b0,denom_r}; q <= {q[W-2:0],1'b1}; end
        else q <= {q[W-2:0],1'b0};
        cnt <= cnt-1;
        if(cnt==1) begin busy<=0; done<=1; quotient<=q; end
      end
    end
  end
endmodule
