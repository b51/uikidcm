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

use_point_goal=Config.vision.use_point_goal;
headInverted=Config.vision.headInverted;

min_area = Config.vision.spot.min_area or 5;
max_area = Config.vision.spot.max_area or 200;
aspect_ratio = Config.vision.spot.aspect_ratio or 0.5;
ground_boundingbox = Config.vision.spot.ground_boundingbox;
ground_th = Config.vision.spot.ground_th;
field_color = Config.color.field;
max_black_rate_B = Config.vision.spot.max_black_rate_B;
max_black_rate_A = Config.vision.spot.max_black_rate_A;

function compare_spot_area(spot1, spot2)
  return spot1.area > spot2.area
end

function detect()
  --TODO: test spot detection

  spot = {};
  spot.detect = 0;


  local spotPropsB = ImageProc.field_spots(Vision.labelB.data, Vision.labelB.m, Vision.labelB.n, min_area);
  if (not spotPropsB) then
    return spot;
  end

  table.sort(spotPropsB, compare_spot_area)
  for i = 1, #spotPropsB do
    local valid = true;
    local bboxB = spotPropsB[i].boundingBox;
    local bboxA = Vision.bboxB2A(bboxB, Vision.scaleB);
    spotStats = ImageProc.color_stats(Vision.labelA.data,
      Vision.labelA.m, Vision.labelA.n, colorWhite, bboxA);

    local spotArea = Vision.bboxArea(bboxB);
    local spotArea_A = Vision.bboxArea(bboxA);
    local aspect_th = aspect_ratio;
    if spotArea > max_area then
      aspect_th = aspect_ratio*1.25;
    end

    if valid then
      local ratio = spotStats.axisMinor/spotStats.axisMajor;
      if ratio < aspect_th then
        valid = false;
      end
    end

    if valid then
      local horizon = HeadTransform.get_horizonB();
      if bboxB[3] < horizon then
        valid = false;
      end
    end

    if valid then
      local groundbbox = {};
      groundbbox[1]=math.max(bboxA[1]+ground_boundingbox[1],0);
      groundbbox[2]=math.min(bboxA[2]+ground_boundingbox[2],Vision.labelA.m-1);
      groundbbox[3]=math.max(bboxA[3]+ground_boundingbox[3],0);
      groundbbox[4]=math.min(bboxA[4]+ground_boundingbox[4],Vision.labelA.n-1);

      local groundstats=ImageProc.color_stats(Vision.labelA.data,
        Vision.labelA.m, Vision.labelA.n, colorField, groundbbox);
      local ambientarea = Vision.bboxArea(groundbbox)-Vision.bboxArea(bboxA);
      green_ratio = groundstats.area/ambientarea;
      if green_ratio < ground_th then
        valid = false;
      end
    end

    if valid then
      if bboxA[3] < 15 then
        valid = false;
      end
    end

    if valid then
      if Vision.bboxArea(bboxA) > 1100 then
        valid = false;
      end
    end

    if valid then
      spot.propsB = spotPropsB[i];
      spot.propsA = spotStats;
      spot.bboxB = bboxB;
      spot.detect = 1;
      local	vcentroid = HeadTransform.coordinatesA(spotStats.centroid, 1);
      vcentroid = HeadTransform.projectGround(vcentroid,0);
      -- vcentroid[4] = 1;
      spot.v = vcentroid;
      return spot;
    end

  end -- for end

  return spot;
end
