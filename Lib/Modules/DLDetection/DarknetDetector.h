/*************************************************************************
 *
 *              Author: b51
 *                Mail: b51live@gmail.com
 *            FileName: DarknetDetector.h
 *
 *          Created On: Tue 19 Dec 2017 01:02:29 AM CST
 *     Licensed under The MIT License [see LICENSE for details]
 *
 ************************************************************************/

#ifndef DarknetDetector_h_DEFINED
#define DarknetDetector_h_DEFINED

#include <algorithm>
#include <iostream>

#include <glog/logging.h>
#include <opencv2/opencv.hpp>

#include "Detector.h"
#include "darknet.h"

class DarknetDetector : public Detector {
public:
  DarknetDetector();
  ~DarknetDetector();

  void LoadModel(std::string cfg, std::string model, bool clear = 0);

  void SetNetParams(double object_thresh = 0.24, double nms_thresh = 0.3,
                    double hier_thresh = 0.5) {
    object_thresh_ = object_thresh;
    nms_thresh_ = nms_thresh;
    hier_thresh_ = hier_thresh;
  }

  bool Detect(const cv::Mat& image, std::vector<Object>& objects);

private:
  float* Mat2Float(const cv::Mat& image);
  void RescaleBoxes(const cv::Mat& image, int num, box* boxes);

private:
  network* net_;

  float object_thresh_;
  float nms_thresh_;
  float hier_thresh_;
};

#endif
