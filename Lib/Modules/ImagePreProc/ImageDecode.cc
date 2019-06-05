#include "ImageDecode.h"

ImageDecode::ImageDecode() : ret_(0), loopCount_(0) {
  set_defaults(&ctx_);
  ctx_.jpegdec = NvJPEGDecoder::createJPEGDecoder("jpegdec");
  ctx_.conv = NvVideoConverter::createVideoConverter("conv");
  capture_dqbuf_go_mutex_ = new boost::mutex();
}

ImageDecode::~ImageDecode() {
  delete capture_dqbuf_go_mutex_;
  capture_dqbuf_go_mutex_ = nullptr;
  delete rgbBuffer_;
}

void ImageDecode::Init(unsigned char* jpgBuffer, unsigned long jpgSize) {
  SetImageInfo(jpgBuffer, jpgSize);
  ret_ = ctx_.conv->setCropRect(0, 0, width_, height_);
  ret_ = ctx_.conv->setOutputPlaneFormat(pixfmt_, width_, height_,
                                         V4L2_NV_BUFFER_LAYOUT_PITCH);
  ret_ = ctx_.conv->setCapturePlaneFormat(pixfmt_, width_, height_,
                                          V4L2_NV_BUFFER_LAYOUT_PITCH);
  ret_ =
      ctx_.conv->output_plane.setupPlane(V4L2_MEMORY_DMABUF, 2, false, false);
  ret_ = ctx_.conv->capture_plane.setupPlane(V4L2_MEMORY_MMAP, 2, true, false);
  ret_ = ctx_.conv->output_plane.setStreamStatus(true);
  ret_ = ctx_.conv->capture_plane.setStreamStatus(true);

  ctx_.conv->capture_plane.setDQThreadCallback(
      conv_capture_dqbuf_thread_callback);
  ctx_.conv->output_plane.setDQThreadCallback(
      conv_output_dqbuf_thread_callback);
  init_cuda(width_, height_);
}

void ImageDecode::DecodeYUV2BGR(unsigned char* jpgBuffer, unsigned long jpgSize,
                                unsigned char* bgrBuffer) {
  rgbBuffer_ = bgrBuffer;
  /*-- Imege decode --*/
  ret_ = ctx_.jpegdec->decodeToFd(fd_, jpgBuffer, jpgSize, pixfmt_, width_,
                                  height_);
  index_ = loopCount_++ % 2;
  /*== Image decode ==*/

  /*-- capture plane qbuffer --*/
  struct v4l2_buffer v4l2_buf;
  struct v4l2_plane planes[MAX_PLANES];

  memset(&v4l2_buf, 0, sizeof(v4l2_buf));
  memset(planes, 0, MAX_PLANES * sizeof(struct v4l2_plane));

  v4l2_buf.index = index_;
  v4l2_buf.m.planes = planes;

  ret_ = ctx_.conv->capture_plane.qBuffer(v4l2_buf, NULL);
  if (ret_ < 0)
    LOG(FATAL) << "Error while queueing buffer at conv capture plane";
  /*-- output plane qbuffer --*/
  memset(&v4l2_buf, 0, sizeof(v4l2_buf));
  memset(planes, 0, MAX_PLANES * sizeof(struct v4l2_plane));

  v4l2_buf.index = index_;
  v4l2_buf.m.planes = planes;
  planes[0].m.fd = fd_;
  planes[0].bytesused = 1234;

  ret_ = ctx_.conv->output_plane.qBuffer(v4l2_buf, NULL);

  if (ret_ < 0)
    LOG(FATAL) << "Error while queueing buffer at conv output plane";

  NvBuffer* buffer;
  ctx_.conv->output_plane.dqFrame(index_, &buffer);

  NvBuffer* buffers;
  ctx_.conv->capture_plane.dqFrame(index_, &buffers);

  unsigned char* Y = (unsigned char*)buffers->planes[0].data;
  unsigned char* U = (unsigned char*)buffers->planes[1].data;
  unsigned char* V = (unsigned char*)buffers->planes[2].data;

  e_yuyv_type type = YUYV_420_PLANNAR;
  gpuConvertYUYVtoRGB(type, Y, U, V, rgbBuffer_, buffers->planes[0].fmt.stride,
                      buffers->planes[1].fmt.stride,
                      buffers->planes[2].fmt.stride, width_, height_);
}
