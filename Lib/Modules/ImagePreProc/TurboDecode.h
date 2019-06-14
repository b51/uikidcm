/*************************************************************************
 *
 *              Author: b51
 *                Mail: b51live@gmail.com
 *            FileName: TurboDecode.h
 *
 *          Created On: Fri 14 Jun 2019 11:23:04 PM CST
 *     Licensed under The MIT License [see LICENSE for details]
 *
 ************************************************************************/
#ifndef TURBO_DECODE_H_
#define TURBO_DECODE_H_

#include <setjmp.h>
#include <stdio.h>
#include <turbojpeg.h>
#include <iostream>

class TurboDecode {
 public:
  TurboDecode() {}
  ~TurboDecode() { tjDestroy(m_jpegDecompressor); }

  void Init();
  void DecodeMJPG2BGR(unsigned char* jpgBuffer, unsigned long jpgSize,
                      unsigned char* bgrBuffer);

 private:
  tjhandle m_jpegDecompressor;
  int width_;
  int height_;
};

#endif
