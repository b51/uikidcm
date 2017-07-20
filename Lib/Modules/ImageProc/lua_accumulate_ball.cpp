#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#ifdef __cplusplus
}
#endif

#include <stdint.h>
#include <stdlib.h>
#include <iostream>
#include <math.h>
#include <vector>

#include "lua_accumulate_ball.h"
#include "RadonTransform.h"

#define POW(x)  (x)*(x)
#define VISION_ANGLE_WIDTH 60/180*M_PI
#define FOCUS_LENGTH 480/2/tan(VISION_ANGLE_WIDTH/2)
#define CAMERA_TILT 80/180*M_PI

#define ORIGINAL_BALL_RADIUS 140


int x[4] = {-1, 0, 1, 0};
int y[4] = {0, 1, 0, -1};

int Max(int a, int b) {return a<b?b:a;};
int Min(int a, int b) {return a<b?a:b;};

/*
仔细看了下代码,中间存在很多问题值得修正,请仔细参看语句后方的注释
*/

int lua_accumulate_ball(std::vector <Candidate> &ballCandidates, uint8_t *label, int width, int height, AccumulateParaIn & paraIn)
{
	double cameraTilt = paraIn.cameraTilt;
	double focusLength = height/2/tan(paraIn.cameraAngleSpead/2);
	double ballRadius = paraIn.physicalRadiusOfBall;
	double horizonLimit = paraIn.horizonLimit;
	double noiseRate = paraIn.noiseRate;
	double radiusRate = paraIn.radiusRate;

  std::vector<Array2D> fourConn;	//此处不需要static,也不需要resize, 临时变量直接push_back即可
  Array2D tmpArray;
  
	for (int i = 0; i < 4; i++)
  {
    tmpArray.x = x[i];
    tmpArray.y = y[i];
    fourConn.push_back(tmpArray);
    //std::cout << "foucor " << i << " .x: "  << fourConn[i].x << " .y: " << fourConn[i].y << std::endl;
  }
  ballCandidates.clear();				//参见C++标准库，这里应该使用类似clear的函数，具体的查询一下书

  int m = width;
  int n = height;
  //std::cout << "width = " << width << " height = " << height << std::endl;

	uint8_t zero = 0;
  std::vector<uint8_t> pointProcFlag(m*n,zero);
  std::vector<Array2D> growQueue;
  std::vector<Array2D> corners(2);

  Array2D currPt, newPt, clusterCenter;
	std::vector<Cluster>  infoOfCluster;
	std::vector<std::vector<uint8_t> > relationMap;
	int clusterNum = 0;

  float lineAngle, maxRadius, maxNoisy, currRadius;

	/*std::cout << pointProcFlag.size();
  for (int j = 0; j < n; j++)			//此处里层应该循环width	
	{
		//std::cout << j ;
		for (int i = 0; i < m; i++)			//此处的关键问题：m和n是否写反了，最外层应该循环height
		{
			std::cout << int(label[j*m +i]) << ",";
		}
		std::cout << std::endl;
	}
	std::cout << std::endl;
	*/

  for (int j = 0; j < n; j++)			//此处里层应该循环width	
  {
		for (int i = 0; i < m; i ++)			//此处的关键问题：m和n是否写反了，最外层应该循环height
    {
      if (label[j*m + i] != 0 && pointProcFlag[j*m + i] == 0)	//如果m和n正确，这里的寻址才正确
      {
        int nStart = 0;
        int nEnd = 1;
        int tag = label[j*m + i];
        pointProcFlag[j*m + i] = 1;
				growQueue.clear();
        growQueue.push_back(Array2D(i, j));							//还是需要生成Array2D临时对象的问题
        corners[0] = Array2D(i, j);
        corners[1] = Array2D(i, j);

				//std::cout << "(" << i << "," << j << ")," << tag << ","<< std::endl;

        while (nStart < nEnd)
        {
          currPt = growQueue[nStart];
          for (int k = 0; k < 4; k++)
          {
            newPt.x = currPt.x + fourConn[k].x;
            newPt.y = currPt.y + fourConn[k].y;
							
            if (newPt.x < m && newPt.x >= 0 					//这里的newPt.x < m newPt.x>=0
                && newPt.y < n && newPt.y >=0)					//这里的newPt.y < n newPt.x>=0
            {
							/*
							std::cout << "(" << newPt.y << "," << newPt.x << ")," << 
								int(pointProcFlag[newPt.y*m + newPt.x]) << ", " <<
								int(label[newPt.y*m+newPt.x]) << std::endl;
							*/

              if (pointProcFlag[newPt.y*m + newPt.x] == 0		//应该是newPt.y*m+newPt.x,后续类似
                  && label[newPt.y*m + newPt.x] == tag)
              {
                growQueue.push_back(newPt);
                nEnd++;
                pointProcFlag[newPt.y*m + newPt.x] = 1;			//应该是newPt.y*m+newPt.x,后续类似
              }
              else
              {
                switch (k)										//k的取值范围是0, 1, 2, 3与Matlab不同
                {
                  case 0:
                    if (currPt.x < corners[0].x)
                      corners[0].x = currPt.x;
                    break;
                  case 1:
                    if (currPt.y > corners[1].y)
                      corners[1].y = currPt.y;
                    break;
                  case 2:
                    if (currPt.x > corners[1].x)
                      corners[1].x = currPt.x;
                    break;
                  case 3:
                    if (currPt.y < corners[0].y)
                      corners[0].y = currPt.y;
                    break;
                  default:
                    break;
                }
              }
            }
            else
            {
              switch (k)
              {
                case 0:
                  if (currPt.x < corners[0].x)
                    corners[0].x = currPt.x;
                  break;
                case 1:
                  if (currPt.y > corners[1].y)
                    corners[1].y = currPt.y;
                  break;
                case 2:
                  if (currPt.x > corners[1].x)
                    corners[1].x = currPt.x;
                  break;
                case 3:
                  if (currPt.y < corners[0].y)
                    corners[0].y = currPt.y;
                  break;
                default:
                  break;
              }
            }
          } // for fourConner end
          nStart++;
        } // while end

        //std::cout << "(" << nEnd << ", " << tag << "),"; 

        clusterCenter.y = (corners[0].y + corners[1].y)/2;
        lineAngle = atan((clusterCenter.y - n/2)/focusLength) + cameraTilt; //need fix
        if (lineAngle < horizonLimit)
          continue;
        
        //std::cout << "lineAngle = " <<  lineAngle << "; hozizonLimit = " << horizonLimit << std::endl;

        maxRadius = ballRadius * sin(lineAngle);  // need fix
        maxNoisy = noiseRate * maxRadius; 
        currRadius = Max(abs(corners[0].x - corners[1].x), abs(corners[0].y - corners[1].y));

				/*
        std::cout << "nEnd = " << nEnd <<
					" currRadius = " <<  currRadius <<
					" maxRadius = " << maxRadius <<
					" maxNoisy = " << maxNoisy <<std::endl;
				*/

        if (nEnd > maxNoisy && currRadius < radiusRate * maxRadius)
        {
					Cluster singleCluster;
          singleCluster.colorTag = tag;
          singleCluster.colorCount = nEnd;
          for(int ii = 0; ii < 2; ii++)
            singleCluster.bBox[ii] = corners[ii];								//这里直接声明一个数组即可，不需要vector
          infoOfCluster.push_back(singleCluster);
					/*
          std::cout << "singleCluster.tag: " << int(singleCluster.colorTag)
            << " singleCluster.colorCount: " << singleCluster.colorCount
            << " corner[1].x: " << corners[0].x << " corners[1].y: " << corners[0].y
            << " corners[2].x: " << corners[1].x << " corners[2].y: " << corners[1].y << std::endl;
					*/
        }

      } // if label != 0 end
    } // for j = height end
  } // for i = width end
	/*
		上面这部分单独调试，通过以后再调下面的部分，不要一起运行
	*/

	clusterNum = infoOfCluster.size();
	if(clusterNum == 0)
		return 0;

	/*
  for (int i = 0; i < clusterNum; i++)
    std::cout << "infoOfCluster [" << i << "]: colorTag " << int(infoOfCluster[i].colorTag)
      << " colorCount " << infoOfCluster[i].colorCount << " upleft.x,y " <<  infoOfCluster[i].bBox[0].x
      << " " << infoOfCluster[i].bBox[0].y << "downright.x,y " << infoOfCluster[i].bBox[1].x << " " 
      << infoOfCluster[i].bBox[1].y << std::endl;
	*/

  relationMap.resize(clusterNum);
	for(int i = 0 ;i < clusterNum; i++)
    relationMap[i].resize(clusterNum);
  std::vector<Array2D> enlargedBBox(2);

  for (int i = 0; i < clusterNum; i++)
  {
    Cluster &currCluster = infoOfCluster[i];
		
		relationMap[i][i] = 1;

		//std::cout << "starting to calculate the relationship: " << i <<std::endl;

    for (int j = i+1; j < clusterNum; j++)
    {
      Cluster &tryingCluster = infoOfCluster[j];

      relationMap[i][j] = 0;
      relationMap[j][i] = 0;

			//std::cout << "1st step " << std::endl;

      enlargedBBox[0].x = Min(currCluster.bBox[0].x, tryingCluster.bBox[0].x);
      enlargedBBox[0].y = Min(currCluster.bBox[0].y, tryingCluster.bBox[0].y);
      enlargedBBox[1].x = Max(currCluster.bBox[1].x, tryingCluster.bBox[1].x);
      enlargedBBox[1].y = Max(currCluster.bBox[1].y, tryingCluster.bBox[1].y);

      clusterCenter.y = (enlargedBBox[0].y + enlargedBBox[1].y)/2;
			lineAngle = atan((clusterCenter.y - n/2)/focusLength) + cameraTilt; //need fix

			//std::cout << "2nd step " << std::endl;

			if (lineAngle < horizonLimit)
      {
        relationMap[i][j] = 2;
        relationMap[j][i] = 2;
        continue;
      }

			maxRadius = ballRadius * sin(lineAngle);  // need fix
      currRadius = Max(abs(enlargedBBox[0].x - enlargedBBox[1].x), abs(enlargedBBox[0].y - enlargedBBox[1].y));

      if (currRadius > radiusRate*maxRadius)
      {
        relationMap[i][j] = 2;
        relationMap[j][i] = 2;
        continue;
      }

			//std::cout << "3rd step " << std::endl;

      int totalLengthX = currCluster.bBox[1].x - currCluster.bBox[0].x + tryingCluster.bBox[1].x - tryingCluster.bBox[0].x;
      int totalLengthY = currCluster.bBox[1].y - currCluster.bBox[0].y + tryingCluster.bBox[1].y - tryingCluster.bBox[0].y;
      if ((totalLengthX + 2) > (enlargedBBox[1].x - enlargedBBox[0].x) && 
          (totalLengthY + 2) > (enlargedBBox[1].y - enlargedBBox[0].y))
      {
        relationMap[i][j] = 1;
        relationMap[j][i] = 1;
      }
    }
  }

	/*
	for(int i = 0; i<clusterNum; i++)
	{
		std::cout << i << ",";
		for(int j = 0; j<clusterNum; j++)
		{
			std::cout << int(relationMap[i][j]) << ",";
		}
		std::cout << std::endl;
	}
	*/

  std::vector<uint8_t> candidateRegionCenter(clusterNum, 0);
  std::vector<uint8_t> connectRegion, nextConnectRegion, targetRegion;

  for (int i = 0; i < clusterNum; i++)
  {
    if (candidateRegionCenter[i] == 3)
      continue;

    bool isRunning = true;

    //connectRegion.assign(relationMap[i].begin(), relationMap[i].end());
    connectRegion = relationMap[i];
    connectRegion[i] = 3;
    
    //nextConnectRegion.assign(connectRegion.begin(), connectRegion.end());
    nextConnectRegion = connectRegion;
    
    while (isRunning)
    {
      isRunning = false;
      for (int j = 0; j < clusterNum; j++)
      {
        if (connectRegion[j] == 1)
        {
          targetRegion = relationMap[j];

          for (int k = 0; k < clusterNum; k++)
          {
            if (targetRegion[k] != 0)
            {
              if (targetRegion[k] == 2)
              {
                connectRegion[k] = targetRegion[k];
                nextConnectRegion[k] = targetRegion[k];
              }
              else if (connectRegion[k] == 0)
              {
                nextConnectRegion[k] = targetRegion[k];
                isRunning = true;
              }
            }
          }
          connectRegion[j] = 3;
          nextConnectRegion[j] = 3;
        }
      }

			/*
			std::cout << "connectRegion: " ;
			for(int i = 0; i<clusterNum; i++)
					std::cout << int(connectRegion[i]) << ",";
			std::cout << std::endl;

			std::cout << "nextConnectRegion: " ;
			for(int i = 0; i<clusterNum; i++)
					std::cout << int(nextConnectRegion[i]) << ",";
			std::cout << std::endl;
			*/

      connectRegion = nextConnectRegion;
			
    }// while end
    
    std::vector<Cluster>  connectResult;
    Array2D ballBBox[2];

    for (int j = 0; j < clusterNum; j++)
    {
      if (connectRegion[j] != 0)
      {
        if (connectRegion[j] == 3)
        {
          connectResult.push_back(infoOfCluster[j]);
					ballBBox[0] = infoOfCluster[j].bBox[0];
					ballBBox[1] = infoOfCluster[j].bBox[1];
          candidateRegionCenter[j] = connectRegion[j];
        }
        else if (candidateRegionCenter[j] != 3)
        {
          candidateRegionCenter[j] = connectRegion[j];
        }
      }
    }
 
		/*
		std::cout << "candidateRegionCenter: " ;
		for(int i = 0; i<clusterNum; i++)
				std::cout << int(candidateRegionCenter[i]) << ",";
		std::cout << std::endl;
		*/

    int bkCntr = 0;
    int wtCntr = 0;
    int blCntr = 0;
    
    for (int i = 0; i < connectResult.size(); i++)
    {
      ballBBox[0].x = Min(connectResult[i].bBox[0].x, ballBBox[0].x);
      ballBBox[0].y = Min(connectResult[i].bBox[0].y, ballBBox[0].y);
      ballBBox[1].x = Max(connectResult[i].bBox[1].x, ballBBox[1].x);
      ballBBox[1].y = Max(connectResult[i].bBox[1].y, ballBBox[1].y);
      switch (connectResult[i].colorTag)
      {
        case 1:
          blCntr += connectResult[i].colorCount;
      	  break;
        case 2:
          bkCntr += connectResult[i].colorCount;
      	  break;
        case 4:
          wtCntr += connectResult[i].colorCount;
      	  break;
      }
    }
		/*
		std::cout << "(" << ballBBox[0].x << "," << ballBBox[0].y << "), (" <<
			ballBBox[1].x << "," << ballBBox[1].y << ")" << ":(" << blCntr <<
			"," << bkCntr << "," << wtCntr << ")"<<std::endl;
		*/

    int totalCntr = bkCntr + wtCntr + blCntr;
    float rate = (float)(blCntr+bkCntr)/totalCntr;
    if (rate < 0.8 && rate > 0.2)
    {
      rate = (float)wtCntr / totalCntr;
      if (rate > 0.8 || rate < 0.2)
     	  continue;
    }
    else
      continue;

    clusterCenter.y = (ballBBox[0].y + ballBBox[1].y)/2;
		lineAngle = atan((clusterCenter.y - n/2)/focusLength) + cameraTilt; //need fix
		maxRadius = ballRadius * sin(lineAngle);  // need fix
    currRadius = Max(abs(ballBBox[0].x - ballBBox[1].x), abs(ballBBox[0].y - ballBBox[1].y));

		/*
		std::cout << "currRadius = " << currRadius << ", maxRadius = " << maxRadius << std::endl;

    if (currRadius < noiseRate * maxRadius)
      continue;

    float Kcolor = 0.33;
    float Kground = 2.0;  // need fix
    float Kradius = 0.33;

    float evaluation = Kcolor * (POW(float(blCntr)/totalCntr - 0.4) + POW(float(wtCntr)/totalCntr - 0.4) + POW(float(bkCntr)/totalCntr - 0.2)) + Kradius * POW(float(currRadius)/maxRadius - 1);  //  need fix

		std::cout << "currRadius = " << currRadius << ", maxRadius = " << maxRadius << ", eval = " << evaluation << std::endl;

		continue;
		*/

    Candidate candidate_;
    for (int ii = 0; ii < 2; ii++)
    {
      candidate_.bBox[ii].x = ballBBox[ii].x;
      candidate_.bBox[ii].y = ballBBox[ii].y;
    }
    candidate_.blCntr     = blCntr;
    candidate_.wtCntr     = wtCntr;
    candidate_.bkCntr     = bkCntr;
    candidate_.evaluation = (float)currRadius/maxRadius;
    ballCandidates.push_back(candidate_);
  }
	//std::cout << "ballCandidates size = " << ballCandidates.size() << std::endl;
  return ballCandidates.size();

}
