/*
 * Copyright (c) 2015, NVIDIA CORPORATION. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#ifndef __YUV2RGB_CUH__
#define __YUV2RGB_CUH__

typedef enum {
  YUYV_422_PACKED = 0,
  YUYV_422_PLANNAR,
  YUYV_420_PLANNAR
}e_yuyv_type;

void gpuConvertYUYVtoRGB(e_yuyv_type type, unsigned char* src, unsigned char* dst,
                         unsigned int width, unsigned int height);


void gpuConvertYUYVtoRGB(e_yuyv_type type,
                         unsigned char* Y, unsigned char* U, unsigned char* V,
                         unsigned char* dst, int y_stride, int u_stride,
                         int v_stride, unsigned int width,
                         unsigned int height);
#endif