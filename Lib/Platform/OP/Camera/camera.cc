/*
 **************************************************************************************
 *       Filename:  camera.c
 *    Description:   source file
 *
 *        Version:  1.0
 *        Created:  2017-07-06 11:43:26
 *
 *       Revision:  initial draft;
 **************************************************************************************
 */
#include <errno.h>
#include <fcntl.h>
#include <gflags/gflags.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <algorithm>
#include <map>
#include <string>

#include "camera.h"

#ifndef NULL
#define NULL 0
#endif

#define check_dev(dev)    \
  if (!dev) {             \
    LOG(ERROR) << "NULL"; \
    return -1;            \
  }

int width = 0;
int height = 0;
struct v4l2_queryctrl queryctrl;
struct v4l2_querymenu querymenu;
std::map<std::string, struct v4l2_queryctrl> ctrlMap;
std::map<std::string, struct v4l2_querymenu> menuMap;

static void enumerate_menu(const camera_t* dev, __u32 id) {
  fprintf(stdout, "\n  Menu items:\n");

  memset(&querymenu, 0, sizeof(querymenu));
  querymenu.id = id;

  for (querymenu.index = queryctrl.minimum;
       querymenu.index <= queryctrl.maximum; querymenu.index++) {
    if (0 == ioctl(dev->fd, VIDIOC_QUERYMENU, &querymenu)) {
      fprintf(stdout, "    %s\n", querymenu.name);
    }
  }
}

static int camera_mmap(camera_t* dev) {
  check_dev(dev);

  int i;
  camera_frame_t* frm = dev->bufs;
  for (i = 0; i < BUF_CNT; i++) {
    frm[i].data = mmap(NULL, frm[i].buf.length, PROT_READ | PROT_WRITE,
                       MAP_SHARED, dev->fd, frm[i].buf.m.offset);
    if (frm[i].data == MAP_FAILED) {
      LOG(ERROR) << "fail to map buffer " << strerror(errno);
      return errno;
    }
  }

  return 0;
}
static int camera_munmap(camera_t* dev) {
  check_dev(dev);
  int i;
  camera_frame_t* frm = dev->bufs;
  for (i = 0; i < BUF_CNT; i++) {
    if (frm[i].data) {
      munmap(frm[i].data, frm[i].buf.length);
      frm[i].data = NULL;
    }
  }

  return 0;
}

static int camera_malloc(camera_t* dev) {
  struct v4l2_requestbuffers req;
  int ret = 0;

  memset(&req, 0x00, sizeof(req));
  req.count = BUF_CNT;
  req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  req.memory = V4L2_MEMORY_MMAP;
  ret = ioctl(dev->fd, VIDIOC_REQBUFS, &req);
  if (ret < 0) {
    LOG(ERROR) << "fail to request buffer" << strerror(errno);
    return errno;
  }

  int i;
  camera_frame_t* frm = dev->bufs;
  for (i = 0; i < BUF_CNT; i++) {
    memset(&frm[i].buf, 0x00, sizeof(frm[i].buf));
    frm[i].buf.index = i;
    frm[i].buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    frm[i].buf.memory = V4L2_MEMORY_MMAP;
    ret = ioctl(dev->fd, VIDIOC_QUERYBUF, &frm[i].buf);
    if (ret < 0) {
      LOG(ERROR) << "fail to query buffer" << strerror(errno);

      return errno;
    }
    LOG(INFO) << "mem[" << i << "]: length = " << frm[i].buf.length
              << ", start from " << frm[i].buf.m.offset;
  }
  return camera_mmap(dev);
}

static int camera_qbufs(camera_t* dev) {
  int i;
  for (i = 0; i < BUF_CNT; i++) {
    camera_queue_frame(dev, &dev->bufs[i]);
  }
}

void string_tolower(std::string& str) {
  std::transform(str.begin(), str.end(), str.begin(),
                 (int (*)(int))std::tolower);
}

static int xioctl(int fd, int request, void* arg) {
  int r;
  do
    r = ioctl(fd, request, arg);
  while (r == -1 && errno == EINTR);
  return r;
}

int camera_query_menu(camera_t* dev, struct v4l2_queryctrl& queryctrl) {
  struct v4l2_querymenu querymenu;

  querymenu.id = queryctrl.id;
  for (querymenu.index = queryctrl.minimum;
       querymenu.index <= queryctrl.maximum; querymenu.index++) {
    if (ioctl(dev->fd, VIDIOC_QUERYMENU, &querymenu) == 0) {
      // fprintf(stdout, "querymenu: %s\n", querymenu.name);
      menuMap[(char*)querymenu.name] = querymenu;
    } else {
      // error
    }
  }
  return 0;
}

int camera_query_ctrl(camera_t* dev, unsigned int addr_begin,
                      unsigned int addr_end) {
  struct v4l2_queryctrl queryctrl;
  std::string key;
  for (queryctrl.id = addr_begin; queryctrl.id < addr_end; queryctrl.id++) {
    if (ioctl(dev->fd, VIDIOC_QUERYCTRL, &queryctrl) == -1) {
      if (errno == EINVAL)
        continue;
      else {
        LOG(FATAL) << "Could not query control";
        return -1;
      }
    }
    switch (queryctrl.type) {
      case V4L2_CTRL_TYPE_MENU:
        camera_query_menu(dev, queryctrl);
        // fall throught
      case V4L2_CTRL_TYPE_INTEGER:
      case V4L2_CTRL_TYPE_BOOLEAN:
      case V4L2_CTRL_TYPE_BUTTON:
        key = (char*)queryctrl.name;
        string_tolower(key);
        ctrlMap[key] = queryctrl;
        break;
      default:
        break;
    }
  }
}

camera_t* camera_open(const char* dev) {
  LOG(INFO) << "open camera: " << dev;
  camera_t* c = (camera_t*)malloc(sizeof(*c));
  if (!c) {
    LOG(ERROR) << "fail to alloc memory";
    return NULL;
  }
  memset(c, 0x00, sizeof(*c));
  c->fd = open(dev, O_RDWR | O_NONBLOCK);
  if (-1 == c->fd) {
    LOG(ERROR) << "fail to open dev: " << dev << " error: " << strerror(errno);
    free(c);
    return NULL;
  }
  snprintf(c->name, sizeof(c->name), "%s", dev);
  return c;
}

int camera_devmap(camera_t* dev) {
  int ret = 0;
  if ((ret = camera_malloc(dev)) != 0) {
    // loge("fail to malloc dev");
    LOG(ERROR) << "fail to malloc dev";
    return 0;
  }
  if ((ret = camera_mmap(dev)) != 0) {
    camera_munmap(dev);
    // loge("fail to mmp dev");
    LOG(ERROR) << "fail to mmp dev";
    return 0;
  }
  camera_qbufs(dev);

  return 0;
}

void camera_close(camera_t* dev) {
  if (dev) {
    LOG(INFO) << "close dev : ", dev->name;
    camera_munmap(dev);
    if (dev->fd > 0) {
      close(dev->fd);
    }
    free(dev);
  }
}

int camera_set_format(camera_t* dev, unsigned int w, unsigned int h,
                      unsigned int pixel_fmt) {
  check_dev(dev);
  LOG(INFO) << "camera_set_format";
  width = w;
  height = h;

  struct v4l2_format fmt;
  fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  fmt.fmt.pix.width = w;
  fmt.fmt.pix.height = h;
  fmt.fmt.pix.field = V4L2_FIELD_ANY;
  fmt.fmt.pix.pixelformat = pixel_fmt;
  int ret = ioctl(dev->fd, VIDIOC_S_FMT, &fmt);
  if (ret < 0) {
    LOG(ERROR) << "fail to set format " << strerror(errno);
    return errno;
  }

  /* double check */
  ret = ioctl(dev->fd, VIDIOC_G_FMT, &fmt);
  if (ret < 0) {
    LOG(ERROR) << "fail to set format " << strerror(errno);

    return errno;
  }
  if (fmt.fmt.pix.pixelformat != pixel_fmt) {
    LOG(ERROR) << "pixel format is not supported";

    return -1;
  }

  // Query V4L2 controls:
  int addr_end = 500;
  camera_query_ctrl(dev, V4L2_CID_BASE, V4L2_CID_LASTP1);
  camera_query_ctrl(dev, V4L2_CID_PRIVATE_BASE, V4L2_CID_PRIVATE_BASE + 20);
  camera_query_ctrl(dev, V4L2_CID_CAMERA_CLASS_BASE + 1,
                    V4L2_CID_CAMERA_CLASS_BASE + addr_end);
  // hack
  camera_query_ctrl(dev, V4L2_CID_BASE, V4L2_CID_BASE + 500);

  fprintf(stdout, "Current Format\n");
  fprintf(stdout, "+------------+\n");
  fprintf(stdout, "width: %u\n", fmt.fmt.pix.width);
  fprintf(stdout, "height: %u\n", fmt.fmt.pix.height);

  fprintf(stdout, "\n");
  fprintf(stdout, "========== Camera avaliable settings ==========\n");
  memset(&queryctrl, 0, sizeof(queryctrl));
  queryctrl.id = V4L2_CTRL_FLAG_NEXT_CTRL;
  while (0 == ioctl(dev->fd, VIDIOC_QUERYCTRL, &queryctrl)) {
    if (!(queryctrl.flags & V4L2_CTRL_FLAG_DISABLED)) {
      fprintf(stdout, "Control %s: ", queryctrl.name);

      if (queryctrl.type == V4L2_CTRL_TYPE_MENU)
        enumerate_menu(dev, queryctrl.id);
      ioctl(dev->fd, VIDIOC_QUERYCTRL, &queryctrl);
      fprintf(stdout, "min %d, max %d, step %d, default value %d\n",
              queryctrl.minimum, queryctrl.maximum, queryctrl.step,
              queryctrl.default_value);
    }
    queryctrl.id |= V4L2_CTRL_FLAG_NEXT_CTRL;
  }
  if (errno != EINVAL) {
    perror("VIDIOC_QUERYCTRL");
    exit(EXIT_FAILURE);
  }
  fprintf(stdout, "===============================================\n");
  fprintf(stdout, "\n");

  return 0;
}

int camera_set_framerate(camera_t* dev, unsigned int fps) {
  check_dev(dev);
  LOG(INFO) << "camera_set_framerate";
  struct v4l2_streamparm para;
  int ret = 0;
  memset(&para, 0x00, sizeof(para));
  para.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  ret = ioctl(dev->fd, VIDIOC_G_PARM, &para);
  if (ret < 0) {
    LOG(ERROR) << "fail to get param : " << strerror(errno);
    return errno;
  }
  para.parm.capture.timeperframe.numerator = 1;
  para.parm.capture.timeperframe.denominator = fps;

  ret = ioctl(dev->fd, VIDIOC_S_PARM, &para);
  if (ret < 0) {
    LOG(ERROR) << "fail to set frame rate : " << strerror(errno);
    return errno;
  }
  return 0;
}

int camera_streamon(camera_t* dev) {
  check_dev(dev);

  int ret = 0;
  int type = V4L2_BUF_TYPE_VIDEO_CAPTURE;

  ret = ioctl(dev->fd, VIDIOC_STREAMON, &type);
  if (ret != 0) {
    LOG(ERROR) << "fail to stream on : " << strerror(errno);

    return errno;
  }

  return 0;
}

int camera_streamoff(camera_t* dev) {
  check_dev(dev);
  int type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  int ret = ioctl(dev->fd, VIDIOC_STREAMOFF, &type);
  if (ret != 0) {
    LOG(ERROR) << "fail to stream off : " << strerror(errno);
    return errno;
  }
  return 0;
}

int camera_writable(camera_t* dev, float timeout) /* timeout is in seconds */
{
  fd_set wr_set;
  struct timeval tv;
  int count = 0;
  long sec = (long)timeout;
  long usec = (long)((timeout - sec) * 1000000);
  tv.tv_sec = sec;
  tv.tv_usec = usec;
  FD_ZERO(&wr_set);
  FD_SET(dev->fd, &wr_set);
  select(dev->fd + 1, NULL, &wr_set, NULL, &tv);
  if (FD_ISSET(dev->fd, &wr_set))
    return 0;
  else {
    LOG(ERROR) << "camera is not writable!  ";

    return -1;
  }
}

int camera_readable(camera_t* dev, float timeout) /* timeout is in seconds */
{
  fd_set rd_set;
  struct timeval tv;
  int count = 0;
  long sec = (long)timeout;
  long usec = (long)((timeout - sec) * 1000000);
  tv.tv_sec = sec;
  tv.tv_usec = usec;
  FD_ZERO(&rd_set);
  FD_SET(dev->fd, &rd_set);
  select(dev->fd + 1, &rd_set, NULL, NULL, &tv);
  if (FD_ISSET(dev->fd, &rd_set))
    return 0;
  else {
    LOG(ERROR) << "camera is not readable!  ";
    return -1;
  }
}

int camera_dqueue_frame(camera_t* dev, camera_frame_t* frame, float timeout) {
  check_dev(dev);
  if (camera_readable(dev, timeout)) return -1;
  frame->buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  frame->buf.memory = V4L2_MEMORY_MMAP;
  int ret = ioctl(dev->fd, VIDIOC_DQBUF, &frame->buf);
  if (ret != 0) {
    LOG(ERROR) << "fail to dqueue buffer" << strerror(errno);
    return errno;
  }
  /*logv("DQ => %d", frame->buf.index);*/
  frame->data = dev->bufs[frame->buf.index].data;
  return 0;
}

int camera_queue_frame(camera_t* dev, camera_frame_t* frame) {
  check_dev(dev);
  int ret = ioctl(dev->fd, VIDIOC_QBUF, &frame->buf);
  if (ret != 0) {
    LOG(ERROR) << "fail to queue buffer" << strerror(errno);
    return errno;
  }
  return 0;
}

void camera_clear_buf(camera_t* dev) {
  camera_frame_t frame;
  for (int i = 0; i < BUF_CNT; i++) {
    camera_dqueue_frame(dev, &frame, 0.1f);
    camera_queue_frame(dev, &frame);
  }
}

int camera_set_ctrl(const camera_t* dev, const char* name, int value) {
  check_dev(dev);
  std::string key(name);
  string_tolower(key);
  std::map<std::string, struct v4l2_queryctrl>::iterator ictrl =
      ctrlMap.find(name);
  if (ictrl == ctrlMap.end()) {
    fprintf(stderr, "Unknown control '%s'\n", name);
    return -1;
  }
  struct v4l2_control ctrl;
  ctrl.id = (ictrl->second).id;
  ctrl.value = value;
  int ret = xioctl(dev->fd, VIDIOC_S_CTRL, &ctrl);
  return ret;
}

int camera_set_ctrl_by_id(const camera_t* dev, int id, int value) {
  check_dev(dev);
  struct v4l2_control ctrl;
  ctrl.id = id;
  ctrl.value = value;

  int ret = xioctl(dev->fd, VIDIOC_S_CTRL, &ctrl);
  return ret;
}

int camera_get_ctrl(const camera_t* dev, const char* name, int* value) {
  check_dev(dev);
  std::string key(name);
  string_tolower(key);
  std::map<std::string, struct v4l2_queryctrl>::iterator ictrl =
      ctrlMap.find(name);
  if (ictrl == ctrlMap.end()) {
    fprintf(stderr, "Unknown control '%s'\n", name);
    return -1;
  }

  struct v4l2_control ctrl;
  ctrl.id = (ictrl->second).id;
  int ret = xioctl(dev->fd, VIDIOC_G_CTRL, &ctrl);
  *value = ctrl.value;
  return ret;
}

int camera_get_width() { return width; }

int camera_get_height() { return height; }

/****************** END ******************/
