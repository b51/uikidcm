module(..., package.seeall);

net = {};
net.net_prototxt = "tiny-yolo.cfg"
net.model_file = "tiny-yolo.weights"
net.width = 128
net.height = 128
net.object_thresh = 0.24
net.nms_thresh = 0.2
net.hier_thresh = 0.5
