module(..., package.seeall);

function get_data_path()
  local cwd = unix.getcwd();
  cwd = cwd.."/Data/";
  return cwd;
end

net = {};
net.width = 416
net.height = 416
net.prototxt = get_data_path().."yolov3-tiny.cfg"
net.model = get_data_path().."yolov3-tiny.weights"
net.object_thresh = 0.5
net.nms_thresh = 0.4
net.hier_thresh = 0.5
