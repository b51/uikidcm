/*************************************************************************
 *
 *              Author: b51
 *                Mail: b51live@gmail.com
 *            FileName: luaDLDetection.cc
 *
 *          Created On: Wed 29 May 2019 10:22:14 PM CST
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

#include <math.h>
#include <stdint.h>
#include <algorithm>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "DarknetDetector.h"

std::shared_ptr<Detector> detector;

static int lua_detector_yolo_init(lua_State* L) {
  std::string prototxt(luaL_checkstring(L, 1));
  std::string model(luaL_checkstring(L, 2));
  double object_thresh = luaL_checknumber(L, 3);
  double nms_thresh = luaL_checknumber(L, 4);
  double hier_thresh = luaL_checknumber(L, 5);

  std::shared_ptr<DarknetDetector> darknet_detector =
      std::make_shared<DarknetDetector>();
  if (darknet_detector) {
    darknet_detector->SetNetParams(object_thresh, nms_thresh, hier_thresh);

    darknet_detector->LoadModel(prototxt, model);
    detector = std::move(darknet_detector);
  }
  return 1;
}

static int lua_bboxes_detect(lua_State* L) {
  uint8_t* rgb = (uint8_t*)lua_touserdata(L, 1);
  if ((rgb == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input RGB not light user data");
  }
  int w = luaL_checkint(L, 2);
  int h = luaL_checkint(L, 3);
  std::vector<Object> objs;
  cv::Mat img(h, w, CV_8UC3, rgb);
  detector->Detect(img, objs);
  for (auto obj : objs) {
    std::cout << " frame_id : " << obj.frame_id << " label: " << obj.label
              << " score: " << obj.score << " x: " << obj.x << " y: " << obj.y
              << " w: " << obj.w << " h: " << obj.h << std::endl;
  }
}

static const struct luaL_reg dlDetection_lib[] = {
    {"detector_yolo_init", lua_detector_yolo_init},
    {"bboxes_detect", lua_bboxes_detect},
    {NULL, NULL}};

extern "C" int luaopen_DLDetection(lua_State* L) {
  luaL_register(L, "DLDetection", dlDetection_lib);

  return 1;
}
