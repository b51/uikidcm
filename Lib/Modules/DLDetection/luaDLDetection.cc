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

#include "lua.hpp"

#include <math.h>
#include <stdint.h>
#include <algorithm>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "DarknetDetector.h"

typedef std::map<int, std::string> LabelNameMap;
typedef std::map<std::string, Object> NameObjMap;
std::shared_ptr<Detector> detector;
const LabelNameMap kLabelNameMap{
    {0, "ball"},        {1, "left_post"},    {2, "right_post"},
    {3, "unkonw_post"}, {4, "penalty_spot"}, {5, "teammate"},
};

static void MakePair(const std::vector<Object>& objects,
                     NameObjMap& name_obj_map) {
  for (auto ln : kLabelNameMap) {
    Object object(ln.first);
    for (auto obj : objects) {
      if (obj.label == ln.first) {
        object = obj;
      }
    }
    name_obj_map.insert(std::make_pair(ln.second, object));
  }
}

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
  int ori_w = luaL_checkint(L, 2);
  int ori_h = luaL_checkint(L, 3);
  int net_w = luaL_checkint(L, 4);
  int net_h = luaL_checkint(L, 5);
  std::vector<Object> objs;
  NameObjMap name_obj_map;
  cv::Mat img(net_h, net_w, CV_8UC3, rgb);
  detector->Detect(img, ori_w, ori_h, objs);
  MakePair(objs, name_obj_map);
  /* Fot Test
  name_obj_map["ball"].frame_id = 100;
  name_obj_map["left_post"].frame_id = 1;
  name_obj_map["right_post"].frame_id = 2;
  name_obj_map["unkonw_post"].frame_id = 3;
  name_obj_map["penalty_spot"].frame_id = 4;
  name_obj_map["teammate"].frame_id = 5;

  name_obj_map["ball"].score = 100;
  name_obj_map["left_post"].score = 1;
  name_obj_map["right_post"].score = 2;
  name_obj_map["unkonw_post"].score = 3;
  name_obj_map["penalty_spot"].score = 4;
  name_obj_map["teammate"].score = 5;

  name_obj_map["ball"].x = 100;
  name_obj_map["left_post"].x = 1;
  name_obj_map["right_post"].x = 2;
  name_obj_map["unkonw_post"].x = 3;
  name_obj_map["penalty_spot"].x = 4;
  name_obj_map["teammate"].x = 5;

  name_obj_map["ball"].y = 100;
  name_obj_map["left_post"].y = 1;
  name_obj_map["right_post"].y = 2;
  name_obj_map["unkonw_post"].y = 3;
  name_obj_map["penalty_spot"].y = 4;
  name_obj_map["teammate"].y = 5;

  name_obj_map["ball"].w = 100;
  name_obj_map["left_post"].w = 1;
  name_obj_map["right_post"].w = 2;
  name_obj_map["unkonw_post"].w = 3;
  name_obj_map["penalty_spot"].w = 4;
  name_obj_map["teammate"].w = 5;

  name_obj_map["ball"].h = 100;
  name_obj_map["left_post"].h = 1;
  name_obj_map["right_post"].h = 2;
  name_obj_map["unkonw_post"].h = 3;
  name_obj_map["penalty_spot"].h = 4;
  name_obj_map["teammate"].h = 5;
  */

  lua_createtable(L, name_obj_map.size(), 0);
  for (auto no : name_obj_map) {
    lua_pushstring(L, no.first.c_str());
    {
      lua_createtable(L, 0, 7);
      lua_pushstring(L, "detect");
      int detect = no.second.score > 0 ? 1 : 0;
      lua_pushnumber(L, detect);
      lua_settable(L, -3);
      lua_pushstring(L, "frame_id");
      lua_pushnumber(L, no.second.frame_id);
      lua_settable(L, -3);
      lua_pushstring(L, "score");
      lua_pushnumber(L, no.second.score);
      lua_settable(L, -3);
      lua_pushstring(L, "x");
      lua_pushnumber(L, no.second.x);
      lua_settable(L, -3);
      lua_pushstring(L, "y");
      lua_pushnumber(L, no.second.y);
      lua_settable(L, -3);
      lua_pushstring(L, "w");
      lua_pushnumber(L, no.second.w);
      lua_settable(L, -3);
      lua_pushstring(L, "h");
      lua_pushnumber(L, no.second.h);
      lua_settable(L, -3);
    }
    lua_settable(L, -3);
  }
  return 1;
}

static const struct luaL_reg dlDetection_lib[] = {
    {"detector_yolo_init", lua_detector_yolo_init},
    {"bboxes_detect", lua_bboxes_detect},
    {NULL, NULL}};

extern "C" int luaopen_DLDetection(lua_State* L) {
  luaL_register(L, "DLDetection", dlDetection_lib);

  return 1;
}
