/*
 **************************************************************************************
 *       Filename:  camera.h
 *    Description:   header file
 *
 *        Version:  1.0
 *        Created:  2017-07-06 11:43:22
 *
 *       Revision:  initial draft;
 **************************************************************************************
 */

#ifndef camera_h_DEFINED
#define camera_h_DEFINED

#include <glog/logging.h>
#include <linux/videodev2.h>

#define BUF_CNT 3

typedef struct _camera_frame_t {
  int idx;
  void* data;
  struct v4l2_buffer buf;
} camera_frame_t;

typedef struct _camera_t {
  int fd;
  char name[64];
  camera_frame_t bufs[BUF_CNT];
} camera_t;

camera_t* camera_open(const char* dev);
int camera_devmap(camera_t* dev);
void camera_close(camera_t* dev);

int camera_get_width();
int camera_get_height();
int camera_get_ctrl(const camera_t* dev, const char* name, int* value);

int camera_set_ctrl(const camera_t* dev, const char* name, int value);
int camera_set_ctrl_by_id(const camera_t* dev, int id, int value);
int camera_set_format(camera_t* dev, unsigned int w, unsigned int h,
                      unsigned int fmt);
int camera_set_framerate(camera_t* dev, unsigned int fps);

int camera_streamon(camera_t* dev);
int camera_streamoff(camera_t* dev);
int camera_dqueue_frame(camera_t* dev, camera_frame_t* frame, float timeout);
int camera_queue_frame(camera_t* dev, camera_frame_t* frame);
void camera_clear_buf(camera_t* dev);

#endif /*CAMERA_H_INCLUDED*/

/********************************** END
 * **********************************************/
