module(..., package.seeall);

function get_data_path()
  local cwd = unix.getcwd();
  cwd = cwd.."/Data/";
  return cwd;
end

net = {};
net.width = 128
net.height = 128
net.prototxt = get_data_path().."yolov3-tiny.cfg"
net.model = get_data_path().."yolov3-tiny.weights"
net.object_thresh = 0.24
net.nms_thresh = 0.2
net.hier_thresh = 0.5
