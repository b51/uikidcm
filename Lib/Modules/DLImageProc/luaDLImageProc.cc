/*************************************************************************
 *
 *              Author: b51
 *                Mail: b51live@gmail.com
 *            FileName: luaDLImageProc.cc
 *
 *          Created On: Sun 26 May 2019 12:34:02 PM CST
 *     Licensed under The MIT License [see LICENSE for details]
 *
 ************************************************************************/

#ifdef __cplusplus
extern "C" {
#endif

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

#ifdef __cplusplus
}
#endif

#include <algorithm>
#include <iostream>
#include <math.h>
#include <stdint.h>
#include <string>
#include <vector>

#include "yuv2rgb.cuh"

#include <fstream>
#include <opencv2/opencv.hpp>

// Downsample camera YUYV image for monitor
//
float clamp(float val, float mn, float mx) {
  return (val >= mn) ? ((val <= mx) ? val : mx) : mn;
}

static int lua_subsample_yuyv2yuyv(lua_State* L) {
  static std::vector<uint32_t> yuyv_array;

  // 1st Input: Original YUYV-format input image
  uint32_t* yuyv = (uint32_t*)lua_touserdata(L, 1);
  if ((yuyv == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }
  // 2nd Input: Width (in YUYV macropixels) of the original YUYV image
  int m = luaL_checkint(L, 2);
  // 3rd Input: Height (in YUVY macropixels) of the original YUYV image
  int n = luaL_checkint(L, 3);
  // 4th Input: How much to subsample
  int subsample_rate = luaL_checkint(L, 4);

  yuyv_array.resize(m * n / subsample_rate / subsample_rate);
  int yuyv_ind = 0;

  for (int j = 0; j < n; j++) {
    for (int i = 0; i < m; i++) {
      if (((i % subsample_rate == 0) && (j % subsample_rate == 0)) ||
          subsample_rate == 1) {
        yuyv_array[yuyv_ind++] = *yuyv;
      }
      yuyv++;
    }
  }

  // Pushing light data
  lua_pushlightuserdata(L, &yuyv_array[0]);
  return 1;
}

static int lua_subsample_yuyv2yuv(lua_State* L) {
  // Structure this is an array of 8bit channels
  // Y,U,V,Y,U,V
  // Row, Row, Row...
  static std::vector<uint8_t> yuv_array;

  // 1st Input: Original YUYV-format input image
  uint32_t* yuyv = (uint32_t*)lua_touserdata(L, 1);
  if ((yuyv == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }

  // 2nd Input: Width (in YUYV macropixels) of the original YUYV image
  int m = luaL_checkint(L, 2);

  // 3rd Input: Height (in YUVY macropixels) of the original YUYV image
  int n = luaL_checkint(L, 3);

  // 4th Input: How much to subsample
  // subsample_amount == 1: use only one of the Y channels
  // subsample_amount == 2: use only one of the Y channels, every other
  // macropixel
  // TODO: subsample_amount == 0: use only both Y channels
  int subsample_rate = luaL_checkint(L, 4);

  // Image is 3 bytes for 3 channels, times the total num of pixels
  yuv_array.resize(3 * (m * n / 2));
  int yuv_ind = 0;
  for (int j = 0; j < n; j++) {
    for (int i = 0; i < m; i++) {
      if (((i % subsample_rate == 0) && (j % subsample_rate == 0)) ||
          subsample_rate == 1) {
        // YUYV -> Y8U8V8
        uint8_t indexY = (*yuyv & 0xFF000000) >> 24;
        uint8_t indexU = (*yuyv & 0x0000FF00) >> 8;
        uint8_t indexV = (*yuyv & 0x000000FF) >> 0;
        yuv_array[yuv_ind++] = indexY;
        yuv_array[yuv_ind++] = indexU;
        yuv_array[yuv_ind++] = indexV;
      }
      yuyv++;
    }
    // Skip every other line (to maintain image ratio)
    yuyv += m;
    j++;
  }

  // Pushing light data
  lua_pushlightuserdata(L, &yuv_array[0]);
  return 1;
}

static int lua_rgb_to_yuyv(lua_State* L) {
  static std::vector<uint32_t> yuyv;

  uint8_t* rgb = (uint8_t*)lua_touserdata(L, 1);
  if ((rgb == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input RGB not light user data");
  }
  int m = luaL_checkint(L, 2);
  int n = luaL_checkint(L, 3);

  yuyv.resize(m * n / 2);

  int count = 0;
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < m; j++) {
      uint8_t r = *rgb++;
      uint8_t g = *rgb++;
      uint8_t b = *rgb++;

      uint8_t y = g;
      uint8_t u = 128 + (b - g) / 2;
      uint8_t v = 128 + (r - g) / 2;

      // Construct Y6U6V6 index
      // SJ: only convert every other pixels (to make m/2 by n yuyv matrix)
      if (j % 2 == 0)
        yuyv[count++] = (v << 24) | (y << 16) | (u << 8) | y;
    }
  }
  lua_pushlightuserdata(L, &yuyv[0]);
  return 1;
}

// Only labels every other pixel
static int lua_yuyv_to_rgb(lua_State* L) {
  // static std::vector<uint8_t> rgb;

  // 1st Input: Original YUYV-format input image
  uint8_t* yuyv = (uint8_t*)lua_touserdata(L, 1);
  if ((yuyv == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }

  // 2rd Input: Width of the image
  int w = luaL_checkint(L, 2);

  // 3th Input: Height of the image
  int h = luaL_checkint(L, 3);

  // rgb will be tripple size of the original image
  unsigned char rgb[w * h * 3];
  gpuConvertYUYVtoRGB((unsigned char*)yuyv, rgb, w, h);
  // cv::Mat img = cv::Mat(h, w, CV_8UC3, rgb);
  // cv::imshow("rgb", img);
  // cv::waitKey(1);

  // Pushing rgb data
  lua_pushlightuserdata(L, &rgb[0]);
  return 1;
}

static const struct luaL_reg dl_imageProc_lib[] = {
    {"yuyv_to_rgb", lua_yuyv_to_rgb},
    {"subsample_yuyv2yuv", lua_subsample_yuyv2yuv},
    {"subsample_yuyv2yuyv", lua_subsample_yuyv2yuyv},
    {NULL, NULL}};

extern "C" int luaopen_DLImageProc(lua_State* L) {
  luaL_register(L, "DLImageProc", dl_imageProc_lib);

  return 1;
}
