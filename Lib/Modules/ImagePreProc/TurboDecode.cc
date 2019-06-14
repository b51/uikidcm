/*************************************************************************
 *
 *              Author: b51
 *                Mail: b51live@gmail.com
 *            FileName: TurboDecode.cc
 *
 *          Created On: Fri 14 Jun 2019 11:25:11 PM CST
 *     Licensed under The MIT License [see LICENSE for details]
 *
 ************************************************************************/

#include "TurboDecode.h"

void TurboDecode::Init() { m_jpegDecompressor = tjInitDecompress(); }

void TurboDecode::DecodeMJPG2BGR(unsigned char* jpgBuffer,
                                 unsigned long jpgSize,
                                 unsigned char* bgrBuffer) {
  int jpegSubsamp, width, height;
  /*-- turbo jpeg decode --*/
  tjDecompressHeader2(m_jpegDecompressor, jpgBuffer, jpgSize, &width, &height,
                      &jpegSubsamp);
  /*== turbo jpeg decode ==*/
  tjDecompress2(m_jpegDecompressor, jpgBuffer, jpgSize, bgrBuffer, width, 0,
                height, TJPF_BGR, TJFLAG_FASTDCT);
}
