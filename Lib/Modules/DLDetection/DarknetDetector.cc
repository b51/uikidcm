/*************************************************************************
 *
 *              Author: b51
 *                Mail: b51live@gmail.com
 *            FileName: DarknetDetector.cc
 *
 *          Created On: Tue 19 Dec 2017 01:15:26 AM CST
 *     Licensed under The MIT License [see LICENSE for details]
 *
 ************************************************************************/

#include "DarknetDetector.h"

DarknetDetector::DarknetDetector() {}

DarknetDetector::~DarknetDetector() {}

void DarknetDetector::RescaleBoxes(const cv::Mat& image, int num,
                                   detection* dets) {
  int w = image.cols;
  int h = image.rows;
  for (int i = 0; i < num; i++) {
    box b = dets[i].bbox;
    int x1 = (b.x - b.w / 2.) * w;
    int x2 = (b.x + b.w / 2.) * w;
    int y1 = (b.y - b.h / 2.) * h;
    int y2 = (b.y + b.h / 2.) * h;

    x1 = std::max(x1, 0);
    y1 = std::max(y1, 0);
    x2 = std::min(x2, w - 1);
    y2 = std::min(y2, h - 1);

    dets[i].bbox.x = x1;
    dets[i].bbox.y = y1;
    dets[i].bbox.w = x2 - x1;
    dets[i].bbox.h = y2 - y1;
  }
}

bool DarknetDetector::Detect(const cv::Mat& image, int ori_w, int ori_h,
                             std::vector<Object>& objects) {
  layer output_l = net_->layers[net_->n - 1];
  float* net_input = Mat2Float(image, ori_w, ori_h);
  network_predict(net_, net_input);
  int nboxes = 0;
  detection* dets = get_network_boxes(net_, ori_w, ori_h, object_thresh_,
                                      hier_thresh_, 0, 1, &nboxes);
  if (nms_thresh_) {
    do_nms_sort(dets, nboxes, output_l.classes, nms_thresh_);
  }

  RescaleBoxes(image, nboxes, dets);

  objects.clear();
  for (int i = 0; i < nboxes; i++) {
    for (int j = 0; j < output_l.classes; j++) {
      if (dets[i].prob[j] > object_thresh_) {
        Object obj;
        obj.x = dets[i].bbox.x;
        obj.y = dets[i].bbox.y;
        obj.w = dets[i].bbox.w;
        obj.h = dets[i].bbox.h;
        obj.label = j;
        obj.score = dets[i].prob[j];
        objects.push_back(obj);
      }
    }
  }
}

void DarknetDetector::LoadModel(std::string prototxt, std::string model,
                                bool clear) {
  LOG(INFO) << prototxt;
  net_ = parse_network_cfg(const_cast<char*>(prototxt.c_str()));
  load_weights(net_, const_cast<char*>(model.c_str()));
  if (clear) {
    (net_->seen) = 0;
  }
  set_batch_network(net_, 1);
}

float* DarknetDetector::Mat2Float(const cv::Mat& image, int ori_w, int ori_h) {
  int w = image.cols;
  int h = image.rows;
  int new_w = ori_w;
  int new_h = ori_h;

  cv::Mat tmp_image(h, w, CV_32FC3);
  float* tmp_data = (float*)(tmp_image.data);

  float* rgb = (float*)std::malloc(w * h * 3 * sizeof(float));
  image.convertTo(tmp_image, CV_32FC3, 1 / 255.);

  for (int i = 0; i < h; i++) {
    for (int j = 0; j < w; j++) {
      rgb[w * i + j] = tmp_data[w * i * 3 + j * 3 + 2];
      rgb[w * i + j + w * h] = tmp_data[w * i * 3 + j * 3 + 1];
      rgb[w * i + j + w * h * 2] = tmp_data[w * i * 3 + j * 3];
    }
  }
  return rgb;
}
