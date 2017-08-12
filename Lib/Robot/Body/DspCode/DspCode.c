#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <math.h>
#include "linuxdef.h"
#include "DspControl.h"
#include "ctrl_rs232.h"
#include "DspCode.h"

//----------------------------------------------------------------------
// CompressPacket 打包 
//
static UINT uiNumReceived=0;	
void PrintName()
{
  printf("liuchao\n");
}
UINT CompressPacket(PBYTE output,DSP_INST_PACKET* packet)
{
	BYTE checkSum=0;
	PBYTE pPacketChar=(PBYTE)packet;
	UINT ret=0;
	int i=0;

	checkSum+=packet->id+packet->instruction+packet->length;
	for(i=0;i<packet->length-2;i++)
		checkSum+=packet->parameter[i];
	checkSum=~checkSum;

	ret=packet->length+4;
	output[0]=0xff;
	output[1]=0xff;

	for(i=0;i<packet->length+1;i++)
		output[i+2]=pPacketChar[i];
	output[packet->length+3]=checkSum;
	return ret;
}



BOOL PacketInterprete(DSP_STATUS_PACKET **container)
{
	DSP_STATUS_PACKET* pRawPacket=(DSP_STATUS_PACKET*)(packetToProc+2);
	BYTE checkSum=pRawPacket->parameter[pRawPacket->length-2];
	BYTE checkSumCal=0;
	int i=0;
	
	for(i=0;i<pRawPacket->length+1;i++)
		checkSumCal+=packetToProc[2+i];
	checkSumCal=~checkSumCal;
	
	if(checkSumCal==checkSum)
	{
		*container=pRawPacket;
		return TRUE;
	}
	return FALSE;
}

BOOL PacketReconstrct( BYTE bReceived)
{
        //need change
        //UINT uiNumReceived=0;
        if(uiNumReceived>=5)
	{
		DSP_STATUS_PACKET *info;
		info=(DSP_STATUS_PACKET *)(packetBuffer+2);
		if(uiNumReceived==(UINT)info->length+4-1)
		{
			packetBuffer[uiNumReceived++]=bReceived;
			memcpy(packetToProc,packetBuffer,uiNumReceived);
			uiNumReceived=0;
			return TRUE;
		}else if(uiNumReceived<(UINT)info->length+4-1)
		{
			packetBuffer[uiNumReceived++]=bReceived;
		}
	}else if(uiNumReceived>=3)
	{
		packetBuffer[uiNumReceived++]=bReceived;
	}else if(uiNumReceived>=2)
	{
		if(bReceived==ID_DSP)
		{
			packetBuffer[uiNumReceived++]=bReceived;
		}else
		{
			uiNumReceived=0;
			return FALSE;
		}
	}else
	{
		if(bReceived==0xff)
		{
			packetBuffer[uiNumReceived++]=bReceived;
		}else
		{
			uiNumReceived=0;
			return FALSE;
		}
	}
	return FALSE;
}

BOOL DiffRotMatrix(struct GaitEffect *pm1,struct GaitEffect *pm2,struct GaitEffect *pm3)
{
	float rad=0;
	float deltax=0;
	float deltay=0;
	struct GaitEffect temp;
	memset(&temp,0,sizeof(temp));
	//get pm1 relative to pm2 and restore it in pm3
	temp.thetaOffset=pm1->thetaOffset-pm2->thetaOffset;
	rad=(float)pm2->thetaOffset/512.0;
	deltax=(float)pm1->xOffset-(float)pm2->xOffset;
	deltay=(float)pm1->yOffset-(float)pm2->yOffset;
	temp.xOffset=(SHORT)(deltax*cos(rad)+deltay*sin(rad));
	temp.yOffset=(SHORT)(-deltax*sin(rad)+deltay*cos(rad));
	memcpy(pm3,&temp,sizeof(temp));
	return TRUE;
}


BOOL ResetOdometers(struct GaitEffect *plastEffect)
{
	int i=0;
	for(i=0;i<MAX_ODOMETER_RECORD;i++)
	{
		if(odometers[i].flag&ODOMETER_RECORD_VALID)
			DiffRotMatrix(&odometers[i].lastRecord,plastEffect,&odometers[i].lastRecord);
	}

	return TRUE;
}

BOOL ClearOdometers()
{
	int i=0;
	for(i=0;i<MAX_ODOMETER_RECORD;i++)
		if(odometers[i].flag&ODOMETER_RECORD_VALID)
			memset(&odometers[i].lastRecord,0,sizeof(struct GaitEffect));

	return TRUE;
}

BOOL PostProcessingTimeout(void)
{
	out.stsReg1=in.ctrReg1;
	out.stsReg2=in.ctrReg2;
	memcpy(&out.spcSts,&in.spcInst,sizeof(struct SpecialGaitCommand));
	memcpy(&out.headSts,&in.headInst,sizeof(struct SpecialGaitCommand));
	if(out.stsReg1&COPY_RESET_ODOMETER)
		ClearOdometers();
	return TRUE;
}

BOOL PostProcessingStateSwap(DSP_STATUS_PACKET *pkt)
{
	PUSHORT pdata=NULL;
        int i=0;
	if(pkt->infomation&PACKET_TYPE_MASK)
	{
		switch(pkt->infomation&~PACKET_TYPE_MASK)
		{
		case INST_STATE_SWAP:
		{
			//reply is received
			pdata=(PUSHORT)&out;
			for(i=0;i<sizeof(struct StateSwapOutput)/sizeof(USHORT);i++)
				pdata[i]=(pkt->parameter[2*i]+(pkt->parameter[2*i+1]<<8));
			//other processing of the receiveing packet
			if(out.stsReg1&COPY_RESET_ODOMETER)
				ResetOdometers(&out.odometer);


			//post handling of inst packet
			//if special gait command is sent or odometer is reset
			//no further command or reset is executed
			in.ctrReg1&=~(out.stsReg1&SPECIAL_GAIT_VALID);
			in.ctrReg1&=~(out.stsReg1&GAIT_DIRECTION_VALID);
			in.ctrReg1&=~(out.stsReg1&COPY_RESET_ODOMETER);	
		}
		break;
		default:
			break;
		}
	}
	return TRUE;
}

void EnterPreparingState(void)
{
	memset(&in,0,sizeof(in));
	memset(&out,0,sizeof(out));
	in.ctrReg1=(
			GAIT_RESET_VALID|
			COPY_RESET_ODOMETER|
			HEAD_MOVE_VALID|
			TORQUE_ENABLE_VALID|
			SENSOR_ENABLE_VALID
			);

	return;
}

void PreProcessingStateSwap(struct StateSwapInput *pin)
{
	if(pGetNextFrame!=NULL)
		(*pGetNextFrame)(&in.headInst.pitch,&in.headInst.yaw);
	//other processing of the sending packet
	if(
		out.odometer.xOffset>10000||
		out.odometer.xOffset<-10000||
		out.odometer.yOffset>10000||
		out.odometer.yOffset<-10000||
		out.odometer.thetaOffset>10000||
		out.odometer.thetaOffset<-10000
		)
		in.ctrReg1|=COPY_RESET_ODOMETER;
/*
	if(in.ctrReg1&GAIT_DIRECTION_VALID)
		printf("gait direction command is released\n");
	if(in.ctrReg1&SPECIAL_GAIT_VALID)
		printf("special gait command is released\n");
*/
	memcpy(pin,&in,sizeof(in));
	return;
}
//dcmEntry()
void BeginDspThread()
{
	int fd=-1;
	
	memset(packetBuffer,0,sizeof(packetBuffer));
	memset(packetToProc,0,sizeof(packetToProc));
	memset(odometers,0,sizeof(odometers));
	pGetNextFrame=NULL;
/*
        if(-1==(fd=init_rs232()))//dcm对应的设定波特率什么的 
	{
		printf("rs232 port init failed\n");
		return ;
	}
*/
	EnterPreparingState();//in.out分别是抓包和收包的   
}
//dcmupdate()
void DspThread()
{       
        DSP_INST_PACKET startPacket;
	BYTE info[sizeof(DSP_INST_PACKET)+2];
	struct StateSwapInput in_thread;
	PUSHORT pdata=NULL;
	BOOL processSuccessful=FALSE;
	int fd=-1;
	struct timeval tv;
	fd_set rdfs;
	int retval;	        
        unsigned int i=0;
	
        
        //previous processing of state swaping packet
		PreProcessingStateSwap(&in_thread);

		//clear all data received but not read
		tcflush(fd,TCIFLUSH);

		startPacket.id=ID_DSP;
		startPacket.instruction=INST_STATE_SWAP;
		startPacket.length=(sizeof(struct StateSwapInput)+2);
		for(i=0;i<sizeof(struct StateSwapInput)/sizeof(USHORT);i++)
		{
			startPacket.parameter[2*i]=(pdata[i]&0xff);
			startPacket.parameter[2*i+1]=((pdata[i]>>8)&0xff);
		}	
		retval=CompressPacket(info,&startPacket);
		retval=write(fd,info,retval);
		
		tv.tv_sec=0;
		tv.tv_usec=50000;
		processSuccessful=FALSE;
		do
		{
			FD_ZERO(&rdfs);
			FD_SET(fd,&rdfs);
			
			retval=select(fd+1,&rdfs,NULL,NULL,&tv);
			if(retval<0)
			{
				tv.tv_sec=0;
				tv.tv_usec=50000;
				continue;
			}else if(retval==0)
			{
				//waiting for reply timeout happened
				//printf("waiting reply timeout warning ********\n");
				break;
			}
			retval=read(fd,info,sizeof(info));
			if(retval<=0)
			{
				//continue to wait for valid character
				perror("receive string failed from serials");
				continue;
			}
			//printf("%d bytes received\n",retval);
			//recv message is read, processing is following
			for(i=0;i<retval;i++)
			{
				if(PacketReconstrct(info[i]))
				{
					DSP_STATUS_PACKET *recv=NULL;
					if(PacketInterprete(&recv))
					{
						processSuccessful=PostProcessingStateSwap(recv);
						//printf("state swap packet receivecd\n");
					}
				}
			}
		}while(!processSuccessful);
		//failure of receiving proper packet
		if(!processSuccessful)
			PostProcessingTimeout();

		usleep(50000);     
}

