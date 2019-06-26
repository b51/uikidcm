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
#include <list>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "DarknetDetector.h"

typedef std::map<int, std::string> LabelNameMap;
typedef std::unordered_map<std::string, std::list<Object>> NamedObjsMap;
std::shared_ptr<Detector> detector;
const LabelNameMap kLabelNameMap{
    {32, "balls"},
    {39, "posts"},
    {2, "penalty_spot"},
    {3, "teammates"},
};

static void MakePair(const std::vector<Object>& objs,
                     NamedObjsMap& named_objs_map) {
  for (const auto& ln : kLabelNameMap) {
    std::list<Object> objects;
    for (const auto& obj : objs) {
      if (obj.label == ln.first) {
        objects.push_back(obj);
      }
    }
    named_objs_map.insert(std::make_pair(ln.second, objects));
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
  int show_img = luaL_checkint(L, 6);
  std::vector<Object> objs;
  NamedObjsMap named_objs_map;
  cv::Mat img(net_h, net_w, CV_8UC3, rgb);
  detector->Detect(img, ori_w, ori_h, objs);
  MakePair(objs, named_objs_map);
  if (show_img) {
    for (const auto& no : named_objs_map) {
      std::string name = no.first;
      for (const auto obj : no.second) {
        float w_scale = float(net_w) / ori_w;
        float h_scale = float(net_h) / ori_h;
        int x = obj.x * w_scale;
        int y = obj.y * h_scale;
        int w = obj.w * w_scale;
        int h = obj.h * h_scale;
        cv::rectangle(img, cv::Rect(x, y, w, h),
                      cv::Scalar(255. / obj.label, 255, 0), 5);
        cv::putText(img, name, cv::Point(x, y), cv::FONT_HERSHEY_COMPLEX, 1, 1);
      }
    }
    cv::imshow("disp", img);
    cv::waitKey(1);
  }

  lua_createtable(L, kLabelNameMap.size(), 0);
  for (const auto& no : named_objs_map) {
    lua_pushstring(L, no.first.c_str());
    {
      int count = 0;
      lua_createtable(L, no.second.size(), 0);
      for (const auto& obj : no.second) {
        lua_createtable(L, 0, 6);
        lua_pushstring(L, "frame_id");
        lua_pushnumber(L, obj.frame_id);
        lua_settable(L, -3);
        lua_pushstring(L, "score");
        lua_pushnumber(L, obj.score);
        lua_settable(L, -3);
        lua_pushstring(L, "x");
        lua_pushnumber(L, obj.x);
        lua_settable(L, -3);
        lua_pushstring(L, "y");
        lua_pushnumber(L, obj.y);
        lua_settable(L, -3);
        lua_pushstring(L, "w");
        lua_pushnumber(L, obj.w);
        lua_settable(L, -3);
        lua_pushstring(L, "h");
        lua_pushnumber(L, obj.h);
        lua_settable(L, -3);

        lua_rawseti(L, -2, count + 1);
        count++;
      }
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
