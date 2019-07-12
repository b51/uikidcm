/*
  x = OPCam(args);

  Author: Daniel D. Lee <ddlee@seas.upenn.edu>, 05/10
        : Stephen McGill 10/10
*/

#include <lua.hpp>

#include <fcntl.h>
#include <memory.h>
#include <string.h>
#include <unistd.h>
#include <iostream>
#include "camera.h"
#include "timeScalar.h"

#define JPEG_FLAG (0xFF)
#define JPEG_HEAD (0xD8)
#define JPEG_TAIL (0xD9)

typedef struct {
  int count;
  int select;
  double time;
  double joint[20];
} CAMERA_STATUS;

#define VIDEO_DEVICE "/dev/video0"

/* Exposed C functions to Lua */
typedef unsigned char uint8;
typedef unsigned int uint32;

camera_frame_t frame;
camera_t* cam;

CAMERA_STATUS* cameraStatus = NULL;
int init = 0;

static int lua_get_select(lua_State* L) {
  lua_pushinteger(L, 0);
  return 1;
}

static int lua_get_height(lua_State* L) {
  lua_pushinteger(L, camera_get_height());
  return 1;
}

static int lua_get_width(lua_State* L) {
  lua_pushinteger(L, camera_get_width());
  return 1;
}

static int lua_get_image(lua_State* L) {
  static int count = 0;
  ////////////////////////////////////////////////
  memset(&frame, 0x00, sizeof(frame));
  int ret = camera_dqueue_frame(cam, &frame, 0.1f);
  if (ret) {
    LOG(WARNING) << "camera dqueue buffer first error.";
    camera_queue_frame(cam, &frame);
    ret = camera_dqueue_frame(cam, &frame, 2.3f);
    if (ret) {
      printf("camera dqueue buffer second error.\n");
      return 0;
    }
  }
  unsigned long jpgSize = 0;
  unsigned char* jpgBuffer;
  jpgBuffer = (unsigned char*)frame.data;
  if (JPEG_FLAG != jpgBuffer[0] || JPEG_HEAD != jpgBuffer[1]) {
    LOG(WARNING) << "jpgBuffer error!";
    camera_queue_frame(cam, &frame);
    return 0;
  }

  jpgSize = frame.buf.bytesused;
  // work around of "Premature end of JPEG file" Warning
  for (size_t i = jpgSize; i > jpgSize / 2; i--) {
    if (jpgBuffer[i] == JPEG_TAIL && jpgBuffer[i - 1] == JPEG_FLAG) {
      jpgSize = i + 1;
      break;
    }
  }
  camera_queue_frame(cam, &frame);
  count++;

  // Once our get_image returns, set the camera status
  cameraStatus->count = count;
  cameraStatus->time = time_scalar();
  cameraStatus->select = 0;

  // Zeros for now
  for (int ji = 0; ji < 20; ji++) {
    cameraStatus->joint[ji] = 0;
  }

  lua_createtable(L, 0, 2);
  lua_pushstring(L, "size");
  lua_pushinteger(L, jpgSize);
  lua_settable(L, -3);
  lua_pushstring(L, "data");
  lua_pushlightuserdata(L, jpgBuffer);
  lua_settable(L, -3);
  return 1;
}

static int lua_camera_status(lua_State* L) {
  lua_createtable(L, 0, 4);

  lua_pushinteger(L, cameraStatus->count);
  lua_setfield(L, -2, "count");
  lua_pushinteger(L, cameraStatus->select);
  //  lua_pushinteger(L, 0);
  lua_setfield(L, -2, "select");
  lua_pushnumber(L, cameraStatus->time);
  lua_setfield(L, -2, "time");

  lua_createtable(L, 22, 0);
  for (int i = 0; i < 22; i++) {
    //    lua_pushnumber(L, cameraStatus->joint[i]);
    lua_pushnumber(L, cameraStatus->joint[i]);
    lua_rawseti(L, -2, i + 1);
  }
  lua_setfield(L, -2, "joint");

  return 1;
}

static int lua_init(lua_State* L) {
  // 1st Input: Width of the image
  int w = luaL_checkinteger(L, 1);
  // 2rd Input: Height of the image
  int h = luaL_checkinteger(L, 2);
  //  int res = 1;
  if (!init) {
    init = 1;
    cam = camera_open(VIDEO_DEVICE);
    camera_set_format(cam, w, h, V4L2_PIX_FMT_MJPEG);
    camera_set_framerate(cam, 30);
    camera_devmap(cam);
    camera_streamon(cam);
    cameraStatus = (CAMERA_STATUS*)malloc(
        sizeof(CAMERA_STATUS));  // Allocate our camera statu
    memset(&frame, 0x00, sizeof(frame));
    int ret = camera_dqueue_frame(cam, &frame, 8.0f);
    if (ret) {
      printf("camera dqueue buffer error.");
      return 0;
    }
    //unsigned long jpgSize = 0;
    //unsigned char* jpgBuffer;
    //jpgBuffer = (unsigned char*)frame.data;
    //jpgSize = frame.buf.bytesused;
    ret = camera_queue_frame(cam, &frame);
    if (ret) {
      printf("camera dqueue buffer error.");
      return 0;
    }
    return 1;
  }
  return 1;
}

static int lua_stop(lua_State* /*L*/) {
  free(cameraStatus);
  camera_close(cam);
  return 1;
}

static int lua_stream_on(lua_State* /*L*/) {
  camera_streamon(cam);
  return 1;
}

static int lua_stream_off(lua_State* /*L*/) {
  camera_streamoff(cam);
  return 1;
}

static int lua_set_param(lua_State* L) {
  const char* param = luaL_checkstring(L, 1);
  double value = luaL_checknumber(L, 2);

  // int ret = v4l2_set_ctrl(param, value);
  int ret = camera_set_ctrl(cam, param, value);
  lua_pushnumber(L, ret);

  return 1;
}

// Added
static int lua_set_param_id(lua_State* L) {
  double id = luaL_checknumber(L, 1);
  double value = luaL_checknumber(L, 2);

  // int ret = v4l2_set_ctrl_by_id(id, value);
  int ret = camera_set_ctrl_by_id(cam, id, value);
  lua_pushnumber(L, ret);

  return 1;
}

static int lua_get_param(lua_State* L) {
  const char* param = luaL_checkstring(L, 1);
  int value;
  camera_get_ctrl(cam, param, &value);
  lua_pushnumber(L, value);
  return 1;
}

// Camera selects should be nil
static int lua_select_camera(lua_State* /*L*/) {
  // int bottom = luaL_checkinteger(L, 1);
  return 1;
}

static int lua_select_camera_fast(lua_State* /*L*/) {
  // int bottom = luaL_checkinteger(L, 1);
  return 1;
}

static int lua_select_camera_slow(lua_State* /*L*/) {
  // int bottom = luaL_checkinteger(L, 1);
  return 1;
}

static int lua_selected_camera(lua_State* L) {
  lua_pushinteger(L, 0);
  return 1;
}

/* Lua Wrapper Requirements */
static const struct luaL_Reg camera_lib[] = {
    {"get_image", lua_get_image},
    {"init", lua_init},
    {"stop", lua_stop},
    {"stream_on", lua_stream_on},
    {"stream_off", lua_stream_off},
    {"get_height", lua_get_height},
    {"get_width", lua_get_width},
    {"get_select", lua_get_select},
    {"set_param", lua_set_param},
    {"get_param", lua_get_param},
    {"set_param_id", lua_set_param_id},
    {"get_camera_status", lua_camera_status},
    {"select_camera", lua_select_camera},
    {"select_camera_fast", lua_select_camera_fast},
    {"select_camera_slow", lua_select_camera_slow},
    {"get_select", lua_selected_camera},
    {NULL, NULL}
};

extern "C"
int luaopen_V4LCam(lua_State* L) {
  luaL_newlib(L, camera_lib);
  return 1;
}
