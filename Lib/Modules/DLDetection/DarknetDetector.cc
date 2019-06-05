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

void DarknetDetector::RescaleBoxes(const cv::Mat& image, int num, box* boxes) {
  int w = image.cols;
  int h = image.rows;
  for (int i = 0; i < num; i++) {
    box b = boxes[i];
    int x1 = (b.x - b.w / 2.) * w;
    int x2 = (b.x + b.w / 2.) * w;
    int y1 = (b.y - b.h / 2.) * h;
    int y2 = (b.y + b.h / 2.) * h;

    x1 = std::max(x1, 0);
    y1 = std::max(y1, 0);
    x2 = std::min(x2, w - 1);
    y2 = std::min(y2, h - 1);

    boxes[i].x = x1;
    boxes[i].y = y1;
    boxes[i].w = x2 - x1;
    boxes[i].h = y2 - y1;
  }
}

bool DarknetDetector::Detect(const cv::Mat& image,
                             std::vector<Object>& objects) {
  cv::Mat resized_image;
  cv::resize(image, resized_image, cv::Size(net_->w, net_->h));

  layer output_l = net_->layers[net_->n - 1];
  int saveint = output_l.w * output_l.h * output_l.n;

  box* boxes = (box*)std::malloc(saveint * sizeof(box));
  float** probs = (float**)std::malloc(saveint * sizeof(float*));

  for (int i = 0; i < saveint; i++)
    probs[i] = (float*)std::malloc((output_l.classes + 1) * sizeof(float*));

  float** masks = 0;
  if (output_l.coords > 4) {
    masks = (float**)std::malloc(saveint * sizeof(float*));
    for (int i = 0; i < saveint; i++)
      masks[i] = (float*)std::malloc((output_l.coords - 4) * sizeof(float*));
  }

  float* net_input = Mat2Float(resized_image);

  network_predict(net_, net_input);

  get_region_boxes(output_l, image.cols, image.rows, net_->w, net_->h,
                   object_thresh_, probs, boxes, masks, 0, 0, hier_thresh_, 1);

  do_nms_sort(boxes, probs, saveint, output_l.classes, nms_thresh_);

  RescaleBoxes(image, saveint, boxes);

  objects.clear();
  for (int i = 0; i < saveint; i++) {
    for (int j = 0; j < output_l.classes; j++) {
      if (probs[i][j] > object_thresh_) {
        Object obj;

        obj.x = boxes[i].x;
        obj.y = boxes[i].y;
        obj.w = boxes[i].w;
        obj.h = boxes[i].h;
        obj.label = j;
        obj.score = probs[i][j];

        objects.push_back(obj);
      }
    }
  }
}

void DarknetDetector::LoadModel(std::string prototxt, std::string model) {
  LOG(INFO) << prototxt;
  net_ = parse_network_cfg(const_cast<char*>(prototxt.c_str()));
  load_weights(net_, const_cast<char*>(model.c_str()));
}

float* DarknetDetector::Mat2Float(const cv::Mat& image) {
  int w = image.cols;
  int h = image.rows;

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
