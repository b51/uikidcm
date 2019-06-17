module(..., package.seeall);

require('Config');	-- For Ball and Goal Size
require('ImageProc');
require('HeadTransform');	-- For Projection
require('Vision');

-- Dependency
require('Detection');

-- Define Color
colorOrange = 1;
colorYellow = 2;
colorCyan = 4;
colorField = 8;
colorWhite = 16;

min_white_pixel = Config.vision.line.min_white_pixel or 200;
min_green_pixel = Config.vision.line.min_green_pixel or 5000;

--min_width=Config.vision.line.min_width or 4;
max_width=Config.vision.line.max_width or 8;
connect_th=Config.vision.line.connect_th or 1.4;
max_gap=Config.vision.line.max_gap or 1;
min_length=Config.vision.line.min_length or 3;
lwratio = Config.vision.line.lwratio or 2

function in_bbox(pointx, pointy, bbox)
  if (pointx>=bbox[1] and pointx<=bbox[2]
	and pointy>=bbox[3] and pointy<=bbox[4]) then
	return true
  else
    return false
  end
end

function lineEndpointsAreClose(line1, line2)
  if math.sqrt((line1[1][1] - line2[1][1])^2 + (line1[1][2] - line2[1][2]^2)) < 1 or
    math.sqrt((line1[1][1] - line2[2][1])^2 + (line1[1][2] - line2[2][2]^2)) < 1 or
    math.sqrt((line1[2][1] - line2[1][1])^2 + (line1[2][2] - line2[1][2]^2)) < 1 or
    math.sqrt((line1[2][1] - line2[2][1])^2 + (line1[2][2] - line2[2][2]^2)) < 1 then
    return true
  else
    return false
  end
end

function detect()
  --TODO: test line detection
  line = {};
  line.detect = 0;

  linePropsB = ImageProc.field_lines(Vision.labelB.data, Vision.labelB.m,
		 Vision.labelB.n, max_width, connect_th, max_gap, min_length);

  if #linePropsB==0 then
    --print('linePropsB nil')
    return line;
  end

  line.propsB=linePropsB;
	nLines=math.min(#line.propsB,12);

  vcm.add_debug_message(string.format(
    "Total %d lines detected\n" ,nLines));

  line.detect = 1;
  line.v={};
  line.endpoint={};
  line.angle={};
  line.meanpoint={};
  line.length={}

  bestindex=1;
  bestlength=0;
  linecount=0;

  for i = 1, nLines do
    line.endpoint[i] = vector.zeros(4);
    line.v[i]={};
    line.v[i][1]=vector.zeros(4);
    line.v[i][2]=vector.zeros(4);
    line.angle[i] = 0;
  end

  for i=1, nLines do
    local valid = true;

    if line.propsB[i].endpoint[3] < HeadTransform.get_horizonB() or line.propsB[i].endpoint[4] < HeadTransform.get_horizonB() then
      valid = false;
    end

    if vcm.get_spot_detect() == 1 then
	local spotbboxB = vcm.get_spot_bboxB()
	if in_bbox(line.propsB[i].endpoint[1], line.propsB[i].endpoint[3], spotbboxB) or
        in_bbox(line.propsB[i].endpoint[2], line.propsB[i].endpoint[4], spotbboxB) then
        valid = false
      end
    end

    if valid then
      local ratio = line.propsB[i].length/line.propsB[i].max_width;
      if ratio<=lwratio then
	valid = false
      end
    end

    if valid then
      local vendpoint = {};
	vendpoint[1] = HeadTransform.coordinatesB(vector.new(
	    {line.propsB[i].endpoint[1], line.propsB[i].endpoint[3]}),1);
	vendpoint[2] = HeadTransform.coordinatesB(vector.new(
		  {line.propsB[i].endpoint[2],line.propsB[i].endpoint[4]}),1);
      linecount=linecount+1;
	line.length[linecount]=length;
	line.endpoint[linecount]= line.propsB[i].endpoint;
	vendpoint[1] = HeadTransform.projectGround(vendpoint[1],0);
	vendpoint[2] = HeadTransform.projectGround(vendpoint[2],0);
	line.v[linecount]={};
	line.v[linecount][1]=vendpoint[1];
	line.v[linecount][2]=vendpoint[2];
	local angle = math.atan2(vendpoint[1][2]-vendpoint[2][2],
      vendpoint[1][1]-vendpoint[2][1]);
      if angle<=0 then angle=angle+math.pi end
      line.angle[linecount] = angle;
      line.meanpoint[linecount]={};
      line.meanpoint[linecount][1]=line.propsB[i].meanpoint[1];
      line.meanpoint[linecount][2]=line.propsB[i].meanpoint[2];
    end

  end

  nLines = linecount;

  line.equalTable = {};
  for i = 1, nLines do line.equalTable[i] = i; end

  for i = 1, nLines do
    for j = i + 1, nLines do
      if math.abs(line.angle[i]-line.angle[j]) < 15/180*math.pi then
        local v_meanpoint_i = HeadTransform.coordinatesB(vector.new({line.meanpoint[i][1], line.meanpoint[i][2]}), 1);
        v_meanpoint_i = HeadTransform.projectGround(v_meanpoint_i, 0);

        local v_meanpoint_j = HeadTransform.coordinatesB(vector.new({line.meanpoint[j][1], line.meanpoint[j][2]}), 1);
        v_meanpoint_j = HeadTransform.projectGround(v_meanpoint_j, 0);

        local meanpoint_angle = math.atan2(v_meanpoint_i[2] - v_meanpoint_j[2], v_meanpoint_i[1] - v_meanpoint_j[1]);

        if math.abs(meanpoint_angle - (line.angle[i] + line.angle[j]) / 2) < 10/180*math.pi then
          if lineEndpointsAreClose(line.v[i], line.v[j]) then
            local ind = math.min(i, line.equalTable[i], line.equalTable[j])
            line.equalTable[j] = ind;
            line.equalTable[i] = ind;
          end
        end
      end
    end
  end

  for i = 1, nLines do
    if line.equalTable[i] ~= i then
      rootind = line.equalTable[i];

      xseries = {line.endpoint[i][1], line.endpoint[rootind][1],
        line.endpoint[i][2], line.endpoint[rootind][2]}
      yseries = {line.endpoint[i][3], line.endpoint[rootind][3],
        line.endpoint[i][4], line.endpoint[rootind][4]}
      xprojseries = {line.v[i][1][1], line.v[rootind][1][1],
        line.v[i][2][1], line.v[rootind][2][1]}
      yprojseries = {line.v[i][1][2], line.v[rootind][1][2],
        line.v[i][2][2],line.v[rootind][2][2]}

      xmin = math.min(xseries[1], xseries[2], xseries[3], xseries[4]);
      xmax = math.max(xseries[1], xseries[2], xseries[3], xseries[4]);

      for j = 1, 4 do
        if xmin == xseries[j] then
          ymin = yseries[j];
          xprojmin = xprojseries[j];
          yprojmin = yprojseries[j];
        end
        if xmax == xseries[j] then
          ymax = yseries[j];
          xprojmax = xprojseries[j];
          yprojmax = yprojseries[j];
        end
      end
      -- connect things in labelB and do the transform again
		  line.endpoint[rootind][1] = xmin;
      line.endpoint[rootind][2] = xmax;
		  line.endpoint[rootind][3] = ymin;
      line.endpoint[rootind][4] = ymax;

      x1 = line.meanpoint[i][1]
      y1 = line.meanpoint[i][2]
      x2 = line.meanpoint[rootind][1]
      y2 = line.meanpoint[rootind][2]
		  -- Dickens: this is an easy fix: use the midpoint of endpoint
      -- should use color_count
      line.meanpoint[rootind][1] = (xmin + xmax) / 2
      line.meanpoint[rootind][2] = (ymin + ymax) / 2

      local vendpoint = {};
		  vendpoint[1] = HeadTransform.coordinatesB(vector.new({line.endpoint[rootind][1], line.endpoint[rootind][3]}), 1);
		  vendpoint[2] = HeadTransform.coordinatesB(vector.new({line.endpoint[rootind][2], line.propsB[i].endpoint[4]}), 1);

      vendpoint[1] = HeadTransform.projectGround(vendpoint[1], 0);
      vendpoint[2] = HeadTransform.projectGround(vendpoint[2], 0);
      line.v[rootind][1] = vendpoint[1];
      line.v[rootind][2] = vendpoint[2];

      local angle = math.atan2(vendpoint[1][2] - vendpoint[2][2], vendpoint[1][1] - vendpoint[2][1]);
      if angle <= 0 then angle = angle + math.pi; end
      line.angle[rootind] = angle;
    end
  end

  local validcount = 0;
  for i = 1, nLines do
    if line.equalTable[i] == i then
      validcount = validcount + 1;
	    line.endpoint[validcount] = line.endpoint[i];
      line.meanpoint[validcount] = line.meanpoint[i];
	    line.v[validcount] = line.v[i];
	    line.angle[validcount] = line.angle[i];
    end
  end
  line.nLines = validcount;

  return line;
end
