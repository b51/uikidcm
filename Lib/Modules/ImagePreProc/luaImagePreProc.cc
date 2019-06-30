/*************************************************************************
 *
 *              Author: b51
 *                Mail: b51live@gmail.com
 *            FileName: luaImagePreProc.cc
 *
 *          Created On: Sun 26 May 2019 12:34:02 PM CST
 *     Licensed under The MIT License [see LICENSE for details]
 *
 ************************************************************************/

#include "lua.hpp"

#include <math.h>
#include <stdint.h>
#include <algorithm>
#include <iostream>
#include <string>
#include <vector>
#include <sys/stat.h>

#include <fstream>
#include <chrono>
#include <opencv2/opencv.hpp>

#include "TurboDecode.h"

TurboDecode turbo_decode;

std::string CurrentSystemDate(const std::string& format = "%Y-%m-%d_%H-%M-%S") {
  auto time = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
  char str[255];
  std::strftime(str, 255, format.c_str(), localtime(&time));
  return std::string(str);
}

bool Exists(std::string dir_path) {
  struct stat st;
  int result = stat(dir_path.c_str(), &st);
  if(result == 0) {
    return true;
  } else {
    return false;
    //if (errno != ENOENT) {
    //  LOG(ERROR) << "File Error: " << errno;
    //}
  }
}

const std::string path = std::string("/home/nvidia/Pictures/") + CurrentSystemDate() + "/";

float clamp(float val, float mn, float mx) {
  return (val >= mn) ? ((val <= mx) ? val : mx) : mn;
}

// Downsample camera YUYV image for monitor
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
      if (j % 2 == 0) yuyv[count++] = (v << 24) | (y << 16) | (u << 8) | y;
    }
  }
  lua_pushlightuserdata(L, &yuyv[0]);
  return 1;
}

static int lua_yuyv_to_rgb(lua_State* L) {
  // 1st Input: Original YUYV-format input image
  uint8_t* yuyv = (uint8_t*)lua_touserdata(L, 1);
  if ((yuyv == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }
  // 2nd Input: Width of the image
  int w = luaL_checkint(L, 2);
  // 3rd Input: Height of the image
  int h = luaL_checkint(L, 3);
  // rgb will be tripple size of the original image
  unsigned char rgb[w * h * 3];
  // yuyv get directory from camera has PACKED yuv422 format
  // e_yuyv_type type = YUYV_422_PACKED;
  // gpuConvertYUYVtoRGB(type, (unsigned char*)yuyv, rgb, w, h);
  // Pushing rgb data
  lua_pushlightuserdata(L, &rgb[0]);
  return 1;
}

static int lua_mjpg_to_rgb(lua_State* L) {
  // 1st Input: Original MJPEG-format input image
  uint8_t* mjpg = (uint8_t*)lua_touserdata(L, 1);
  if ((mjpg == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }
  // 2nd Input: mjpeg buffer size
  int size = luaL_checkint(L, 2);
  // 3rd Input: Width of the image
  int w = luaL_checkint(L, 3);
  // 4th Input: Height of the image
  int h = luaL_checkint(L, 4);
  // rgb will be tripple size of the original image
  unsigned char rgb[w * h * 3];
  turbo_decode.DecodeMJPG2BGR(mjpg, size, rgb);
  // Pushing rgb data
  lua_pushlightuserdata(L, &rgb[0]);
  return 1;
}

static int lua_rgb_resize(lua_State* L) {
  // 1st Input: Original YUYV-format input image
  uint8_t* rgb = (uint8_t*)lua_touserdata(L, 1);
  if ((rgb == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input RGB not light user data");
  }
  // 2nd Input: Width of the image
  int w = luaL_checkint(L, 2);
  // 3rd Input: Height of the image
  int h = luaL_checkint(L, 3);
  // 4th Input: Width of resized image
  int rz_w = luaL_checkint(L, 4);
  // 5th Input: Height of resized image
  int rz_h = luaL_checkint(L, 5);
  // 6th Input: will keep original ratio?
  int ratio_fixed = luaL_checkint(L, 6);
  // 7th Input: Height of resized image
  int show_img = luaL_checkint(L, 7);
  cv::Mat img(h, w, CV_8UC3, rgb);
  cv::Mat rzd_img(rz_h, rz_w, CV_8UC3, 128);  // padded image with 128
  if (!ratio_fixed) {
    cv::resize(img, rzd_img, cv::Size(rz_w, rz_h));
  } else {
    int new_w = w;
    int new_h = h;
    if (((float)rz_w / w) < ((float)rz_h / h)) {
      new_w = rz_w;
      new_h = (h * rz_w) / w;
    } else {
      new_h = rz_h;
      new_w = (w * rz_h) / h;
    }
    cv::Mat image_roi = rzd_img(
        cv::Rect(((rz_w - new_w) / 2), (rz_h - new_h) / 2, new_w, new_h));
    cv::resize(img, image_roi, cv::Size(new_w, new_h));
  }
  // TODO(b51): Remove this after beta
  static int count = 0;
  std::string img_name = path + std::to_string(count) + ".jpg";
  if (show_img) {
    if (!Exists(path)) {
      mkdir(path.c_str(), S_IRWXU | S_IRWXG | S_IRWXO);
    }
    if (count % 10 == 0)
      cv::imwrite(img_name, img);
    cv::imshow("rzd_img", rzd_img);
    cv::waitKey(1);
    count++;
  }
  // Pushing rgb data
  lua_pushlightuserdata(L, rzd_img.data);
  return 1;
}

static int lua_init(lua_State* L) {
  uint8_t* mjpg = (uint8_t*)lua_touserdata(L, 1);
  if ((mjpg == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }
  int size = luaL_checkint(L, 2);
  turbo_decode.Init();
}

static const struct luaL_reg imagePreProc_lib[] = {
    {"init", lua_init},
    {"yuyv_to_rgb", lua_yuyv_to_rgb},
    {"mjpg_to_rgb", lua_mjpg_to_rgb},
    {"rgb_resize", lua_rgb_resize},
    {"subsample_yuyv2yuv", lua_subsample_yuyv2yuv},
    {"subsample_yuyv2yuyv", lua_subsample_yuyv2yuyv},
    {NULL, NULL}};

extern "C" int luaopen_ImagePreProc(lua_State* L) {
  luaL_register(L, "ImagePreProc", imagePreProc_lib);

  return 1;
}
