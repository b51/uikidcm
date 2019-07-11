#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>
#include <termios.h>
#include "RobotParameter.h"
#include "ctrl_rs232.h"

int sio_fd=-1;

int init_rs232(void)
{
	int status;
	struct termios opt;
	if(sio_fd!=-1)
		return sio_fd;
	sio_fd=open(RS232_DEVICE_NAME, O_RDWR|O_NOCTTY);
	if(sio_fd==-1)
	{
		perror("serial port open failed");
		return -1;
	}

	tcgetattr(sio_fd, &opt);
	tcflush(sio_fd, TCIOFLUSH);

	//baudrate:115200
	cfsetispeed(&opt, B115200);
	cfsetospeed(&opt, B115200);

	opt.c_cflag &=~CSIZE;
	opt.c_lflag &=~(ICANON | ECHO | ECHOE | ISIG);
	opt.c_oflag &=~OPOST;
	opt.c_iflag =0;

	//8 bits data
	opt.c_cflag |=CS8;

	//no parity
	opt.c_cflag &= ~PARENB;
	opt.c_iflag &=~INPCK;

	//1 stop bit
	opt.c_cflag &=~CSTOPB;

	/////opt.c_iflag |=INPCK;//??

	opt.c_cc[VTIME]=1;
	opt.c_cc[VMIN]=1;

	status=tcsetattr(sio_fd, TCSANOW, &opt);
	if (status !=0)
	{
		perror("tcsetattr failed");
		return -1;
	}
	tcflush(sio_fd, TCIOFLUSH);
	return sio_fd;
}

int destroy_rs232(void)
{
  if(sio_fd!=-1)
    close(sio_fd);
  sio_fd=-1;
  return 0;
}
