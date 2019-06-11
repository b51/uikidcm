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

typedef struct {
  int x;
  int y;
  int w;
  int h;

  int frame_id;
  int label;
  float score;
} Object;

enum { BALL, GOAL_POST, PENALTY_SPOT, TEAMMATE, OPPONENT_ROBOT, OBJECT_END };

class Detector {
public:
  Detector() {}
  virtual ~Detector() {}

  virtual bool Detect(const cv::Mat& image, int ori_w, int ori_h, std::vector<Object>& objects) = 0;
};

#endif
