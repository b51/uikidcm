#ifndef IMAGE_DECODE_H_
#define IMAGE_DECODE_H_

#include <sys/stat.h>
#include <sys/types.h>
#include <chrono>
#include <fstream>
#include <iostream>

#include <boost/bind.hpp>
#include <boost/thread/condition.hpp>
#include <boost/thread/mutex.hpp>
#include <boost/thread/thread.hpp>

#include <cuda_runtime.h>
#include <glog/logging.h>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/opencv.hpp>

#include "NvLogging.h"
#include "NvUtils.h"
#include "jpeg_decode.h"
#include "yuv2rgb.cuh"

using namespace std;

static unsigned char* cuda_out_buffer = nullptr;
static bool cuda_zero_copy = false;

/**
 * Init CUDA for yuv2rgb convert.
 */
static void init_cuda(int w, int h) {
  /* Check unified memory support. */
  if (cuda_zero_copy) {
    cudaDeviceProp devProp;
    cudaGetDeviceProperties(&devProp, 0);
    if (!devProp.managedMemory) {
      LOG(ERROR) << "CUDA device does not support managed memory.";
      cuda_zero_copy = false;
    }
  }
  /* Allocate output buffer. */
  size_t size = w * h * 3;
  if (cuda_zero_copy) {
    cudaMallocManaged(&cuda_out_buffer, size, cudaMemAttachGlobal);
  } else {
    cuda_out_buffer = (unsigned char*)malloc(size);
  }
  cudaDeviceSynchronize();
}

/**
 * Set ctx to default
 */
static void set_defaults(jpeg_context_t* ctx) {
  memset(ctx, 0, sizeof(jpeg_context_t));
  ctx->use_fd = true;
}

static void abort(jpeg_context_t* ctx) {
  ctx->got_error = true;
  ctx->conv->abort();
}

/**
 * Write yuv buffer to file.
 */
static int write_to_file(std::ofstream* stream, NvBuffer& buffer) {
  uint32_t i, j;
  char* data;

  for (i = 0; i < buffer.n_planes; i++) {
    NvBuffer::NvBufferPlane& plane = buffer.planes[i];
    size_t bytes_to_write = plane.fmt.bytesperpixel * plane.fmt.width;

    data = (char*)plane.data;
    for (j = 0; j < plane.fmt.height; j++) {
      stream->write(data, bytes_to_write);
      if (!stream->good()) return -1;
      data += plane.fmt.stride;
    }
  }
  return 0;
}

/**
 * Output plane callback
 *
 * params: all useless.
 */
static bool conv_output_dqbuf_thread_callback(struct v4l2_buffer* v4l2_buf,
                                              NvBuffer* buffer,
                                              NvBuffer* shared_buffer,
                                              void* arg) {
  return true;
}

/**
 * Capture plane callback
 *
 * params: NvBuffer* buffer, can get yuv from buffer.
 */
static bool conv_capture_dqbuf_thread_callback(struct v4l2_buffer* v4l2_buf,
                                               NvBuffer* buffer,
                                               NvBuffer* shared_buffer,
                                               void* arg) {
  static int yuvSaveCount = 0;
  jpeg_context_t* ctx = (jpeg_context_t*)arg;

  if (!v4l2_buf) {
    cerr << "Failed to dequeue buffer from conv capture plane" << endl;
    abort(ctx);
    return false;
  }
  // char yuvName[128];
  // sprintf(yuvName, "yuv_%04d.jpg", yuvSaveCount++);
  // FILE* yuvFile = fopen(yuvName, "w");
  // fwrite(rgbBuffer, 1, 1920*1080*3, yuvFile);
  // fclose(yuvFile);
  // std::ofstream yuvFile(yuvName, std::ofstream::out);
  // write_to_file(&yuvFile, *buffer);
  return true;
}

/**
 * Class ImageDecode
 *
 * Decode MJpeg to yuv(NV21) and dq out with capture plane.
 * Then convert yuv to rgb use cuda.
 */
class ImageDecode {
 public:
  /**
   * ImageDecode Constructor
   *
   * Set ctx_ and create JPEGDecoder.
   */
  ImageDecode();
  ~ImageDecode();

  /**
   * ctx_ settings and thread t_output_ start.
   */
  void Init(unsigned char* jpgBuffer, unsigned long jpgSize);

  /*
   * Decode with mult methods
   */
  void DecodeYUV2BGR(unsigned char* jpgBuffer, unsigned long jpgSize,
                     unsigned char* bgrBuffer);

  /**
   * Set pixfmt, image width and image height by decode MJpeg once.
   *
   * param[in]: jpgBuffer MJpeg data stored in.
   * param[in]: jpgSize MJpeg data size.
   */
  void SetImageInfo(unsigned char* jpgBuffer, unsigned long jpgSize) {
    uint32_t pixfmt, w, h;
    ret_ = ctx_.jpegdec->decodeToFd(fd_, jpgBuffer, jpgSize, pixfmt, w, h);
    pixfmt_ = pixfmt;
    width_ = w;
    height_ = h;
  }

 private:
  int fd_;
  int ret_;
  int index_;
  int loopCount_;
  uint32_t width_, height_, pixfmt_;
  unsigned char* rgbBuffer_;

  boost::mutex capture_dqbuf_done_mutex_;
  boost::mutex* capture_dqbuf_go_mutex_;
  boost::condition capture_dqbuf_ready_cond_, capture_dqbuf_done_cond_;

  jpeg_context_t ctx_;
};

#endif
