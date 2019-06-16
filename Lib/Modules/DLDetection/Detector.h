/*************************************************************************
 *
 *              Author: b51
 *                Mail: b51live@gmail.com
 *            FileName: Detector.h
 *
 *          Created On: Sat 23 Dec 2017 12:07:10 AM CST
 *     Licensed under The MIT License [see LICENSE for details]
 *
 ************************************************************************/

#ifndef DETECTOR_h_DEFINED
#define DETECTOR_h_DEFINED

#include <iostream>

#include <opencv2/opencv.hpp>

struct Object {
  int label;
  int frame_id;
  float score;
  int x;
  int y;
  int w;
  int h;

 public:
  Object() : label(0), frame_id(0), score(0), x(0), y(0), w(0), h(0) {}
  Object(int l) : label(l), frame_id(0), score(0), x(0), y(0), w(0), h(0) {}
};

class Detector {
 public:
  Detector() {}
  virtual ~Detector() {}

  virtual bool Detect(const cv::Mat& image, int ori_w, int ori_h,
                      std::vector<Object>& objects) = 0;
};

#endif
