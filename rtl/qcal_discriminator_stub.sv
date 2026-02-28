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
// Module: qcal_discriminator_stub
// Description: Stub discriminator: converts plant_bit stream into meas_valid/meas_bit aligned to shot_tick (simulation model).
// ============================================================
`timescale 1ns/1ps
module qcal_discriminator_stub (
  input  logic clk, input logic rst_n,
  input  logic shot_tick,
  input  logic plant_bit_valid,
  input  logic plant_bit,
  output logic meas_valid,
  output logic meas_bit
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin meas_valid<=0; meas_bit<=0; end
    else begin
      meas_valid <= shot_tick & plant_bit_valid;
      if (shot_tick & plant_bit_valid) meas_bit <= plant_bit;
    end
  end
endmodule
