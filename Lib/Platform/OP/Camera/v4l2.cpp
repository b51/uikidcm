// C++ routines to access V4L2 camera

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <assert.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/videodev2.h>
#include <cctype>
#include <string>
#include <algorithm>
#include <vector>
#include <map>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include "JPGApi.h"

// Logitech UVC controls
#ifndef V4L2_CID_FOCUS
#define V4L2_CID_FOCUS 0x0A046D04
#endif
#ifndef V4L2_CID_LED1_MODE
#define V4L2_CID_LED1_MODE 0x0A046D05
#endif
#ifndef V4L2_CID_LED1_FREQUENCY
#define V4L2_CID_LED1_FREQUENCY 0x0A046D06
#endif
#ifndef V4L2_CID_DISABLE_PROCESSING
#define V4L2_CID_DISABLE_PROCESSING 0x0A046D71
#endif
#ifndef V4L2_CID_RAW_BITS_PER_PIXEL
#define V4L2_CID_RAW_BITS_PER_PIXEL 0x0A046D72
#endif
#define DHT_SIZE 432
#define	MAX_YUYV_SIZE	1843200

//added

int video_fd = -1;
int nbuffer = 2;
char invert = 0;
int handle;
int width = 640;
int height = 480;


pthread_mutex_t camera_mutex = PTHREAD_MUTEX_INITIALIZER;

uint8_t* yuyv_rotate(uint8_t* frame, int width, int height);
int SaveJpgBuf(unsigned char *buf,int size);

struct buffer {
  void * start;
  size_t length;
};

std::map<std::string, struct v4l2_queryctrl> ctrlMap;
std::map<std::string, struct v4l2_querymenu> menuMap;

std::vector<struct buffer> buffers;

struct JpgBuffer {
  char buf[1280*720*2];
  int size;
};

struct JpgBuffer jpgBuffer;
struct v4l2_buffer *buf0;

unsigned char dht_data[DHT_SIZE] = {
    0xff, 0xc4, 0x00, 0x1f, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a,
    0x0b, 0xff, 0xc4, 0x00, 0xb5, 0x10, 0x00, 0x02,
    0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00,
    0x01, 0x7d, 0x01, 0x02, 0x03, 0x00, 0x04, 0x11,
    0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07, 0x22, 0x71,
    0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23, 0x42,
    0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09,
    0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25, 0x26,
    0x27, 0x28, 0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43,
    0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x53,
    0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67,
    0x68, 0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77,
    0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x92,
    0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a,
    0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4,
    0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
    0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6,
    0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2, 0xe3, 0xe4,
    0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6,
    0xf7, 0xf8, 0xf9, 0xfa, 0xff, 0xc4, 0x00, 0x1f,
    0x01, 0x00, 0x03, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02,
    0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0xff, 0xc4, 0x00,
    0xb5, 0x11, 0x00, 0x02, 0x01, 0x02, 0x04, 0x04,
    0x03, 0x04, 0x07, 0x05, 0x04, 0x04, 0x00, 0x01, 0x02, 0x77, 0x00, 0x01,
    0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06,
    0x12, 0x41, 0x51, 0x07, 0x61, 0x71, 0x13, 0x22, 0x32, 0x81, 0x08, 0x14,
    0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33,
    0x52, 0xf0, 0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25,
    0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26, 0x27, 0x28,
    0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46,
    0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56,
    0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a,
    0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a,
    0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x92, 0x93, 0x94,
    0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3,
    0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
    0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
    0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8,
    0xd9, 0xda, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7,
    0xe8, 0xe9, 0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa
};

char *Decompress(char *jpgImg,unsigned int fileSize)
{
	char 	*InBuf = NULL;
	char 	*OutBuf = NULL;
	FILE 	*fp;
	FILE 	*CTRfp;
	long 	streamSize;
	int 	width, height, samplemode;
	JPEG_ERRORTYPE ret;
	char 	outFilename[128];
	char 	inFilename[128];
	//BOOL	result = TRUE;
	//struct timeval start;
	//struct timeval stop;
	//unsigned int	time = 0;

		//printD("filesize : %d\n", fileSize);

		InBuf = (char *)SsbSipJPEGGetDecodeInBuf(handle, fileSize);
		if(InBuf == NULL){
			printf("Input buffer is NULL\n");
		//	result = FALSE;
		//	return;
		}
//		printf("inBuf : 0x%x\n", InBuf);

		//////////////////////////////////////////////////////////////
		// 4. put JPEG frame to Input buffer                        //
		//////////////////////////////////////////////////////////////
		memcpy(InBuf,jpgImg,fileSize);

		//////////////////////////////////////////////////////////////
		// 5. Decode JPEG frame                                     //
		//////////////////////////////////////////////////////////////
		//	gettimeofday(&start, NULL);
		
		ret = SsbSipJPEGDecodeExe(handle);
		
		//	gettimeofday(&stop, NULL);
		//	time += measureTime(&start, &stop);
		//	printf("[JPEG Decoding Performance] Elapsed time : %u\n", time);
		//	time = 0;

		if(ret != JPEG_OK){
			printf("Decoding failed\n");
		//	result = FALSE;
		//	return;
		}
		
		//////////////////////////////////////////////////////////////
		// 6. get Output buffer address                             //
		//////////////////////////////////////////////////////////////
		OutBuf = (char *)SsbSipJPEGGetDecodeOutBuf(handle, &streamSize);
		if(OutBuf == NULL){
			printf("Output buffer is NULL\n");
		//	result = FALSE;
		//	return;
		}
//		printf("OutBuf : 0x%x streamsize : %d\n", OutBuf, streamSize);

		//////////////////////////////////////////////////////////////
		// 7. get decode config.                                    //
		//////////////////////////////////////////////////////////////
		//SsbSipJPEGGetConfig(JPEG_GET_DECODE_WIDTH, &width);
		//SsbSipJPEGGetConfig(JPEG_GET_DECODE_HEIGHT, &height);
		//SsbSipJPEGGetConfig(JPEG_GET_SAMPING_MODE, &samplemode);
		
//		printf("width : %d height : %d samplemode : %d\n", width, height, samplemode);
		//char *filename = "1234.jpg";
		//fp = fopen(filename, "wb");
		//fwrite(OutBuf, 1, streamSize, fp);
		//fclose(fp);
		//printf("file saved\n");
		//char * temp = (char *)malloc(streamSize);
		//memcpy(temp, OutBuf, streamSize);
		//OutBuf = temp;
		//free(temp);
		return OutBuf;
}

static int xioctl(int fd, int request, void *arg) {
  int r;
  do
    r = ioctl(fd, request, arg);
  while (r == -1 && errno == EINTR);
  return r;
}

void string_tolower(std::string &str) {
  std::transform(str.begin(), 
      str.end(), 
      str.begin(),
      (int(*)(int)) std::tolower);
}

int v4l2_error(const char *error_msg) {
  if (video_fd >= 0)
    close(video_fd);
  video_fd = 0;
  int x = errno;
  fprintf(stderr, "Err: %d\n", x);
  fprintf(stderr, "V4L2 error: %s\n", error_msg);
  return -2;
}

int v4l2_query_menu(struct v4l2_queryctrl &queryctrl) {
  struct v4l2_querymenu querymenu;

  querymenu.id = queryctrl.id;
  for (querymenu.index = queryctrl.minimum;
      querymenu.index <= queryctrl.maximum;
      querymenu.index++) {
    if (ioctl(video_fd, VIDIOC_QUERYMENU, &querymenu) == 0) {
      fprintf(stdout, "querymenu: %s\n", querymenu.name);
      menuMap[(char *)querymenu.name] = querymenu;
    }
    else {
      // error
    }
  }
  return 0;
}

int v4l2_query_ctrl(unsigned int addr_begin, unsigned int addr_end) {
  struct v4l2_queryctrl queryctrl;
  std::string key;

  for (queryctrl.id = addr_begin;
      queryctrl.id < addr_end;
      queryctrl.id++) {
    if (ioctl(video_fd, VIDIOC_QUERYCTRL, &queryctrl) == -1) {
      if (errno == EINVAL)
        continue;
      else
        return v4l2_error("Could not query control");
    }
    fprintf(stdout, "queryctrl: \"%s\" 0x%x\n", 
        queryctrl.name, queryctrl.id);

    switch (queryctrl.type) {
      case V4L2_CTRL_TYPE_MENU:
        v4l2_query_menu(queryctrl);
        // fall throught
      case V4L2_CTRL_TYPE_INTEGER:
      case V4L2_CTRL_TYPE_BOOLEAN:
      case V4L2_CTRL_TYPE_BUTTON:
        key = (char *)queryctrl.name;
        string_tolower(key);
        ctrlMap[key] = queryctrl;
        break;
      default:
        break;
    }
  }
}

int v4l2_set_ctrl(const char *name, int value) {
  std::string key(name);
  string_tolower(key);
  std::map<std::string, struct v4l2_queryctrl>::iterator ictrl
    = ctrlMap.find(name);
  if (ictrl == ctrlMap.end()) {
    fprintf(stderr, "Unknown control '%s'\n", name);
    return -1;
  }

  int v4l2_cid_base=0x00980900;

  fprintf(stderr, "Setting ctrl %s, id %d\n", name,(ictrl->second).id-v4l2_cid_base);
  struct v4l2_control ctrl;
  ctrl.id = (ictrl->second).id;
  ctrl.value = value;
  int ret=xioctl(video_fd, VIDIOC_S_CTRL, &ctrl);
  return ret;
}

//added to manually set parameters not shown on query lists
int v4l2_set_ctrl_by_id(int id, int value){
  struct v4l2_control ctrl;
  ctrl.id = id;
  ctrl.value = value;
  int v4l2_cid_base=0x00980900;

  fprintf(stderr, "Setting id %d value %d\n", id-v4l2_cid_base,value);

  int ret=xioctl(video_fd, VIDIOC_S_CTRL, &ctrl);
  return ret;
}



int v4l2_get_ctrl(const char *name, int *value) {
  std::string key(name);
  string_tolower(key);
  std::map<std::string, struct v4l2_queryctrl>::iterator ictrl
    = ctrlMap.find(name);
  if (ictrl == ctrlMap.end()) {
    fprintf(stderr, "Unknown control '%s'\n", name);
    return -1;
  }

  struct v4l2_control ctrl;
  ctrl.id = (ictrl->second).id;
  int ret=xioctl(video_fd, VIDIOC_G_CTRL, &ctrl);
  *value = ctrl.value;
  return ret;
}

// Change on Dec 30, 2010 from Steve McGill
// Default is opening in blocking mode
int v4l2_open(const char *device) {
  if (device == NULL) {
    // Default video device name
    device = "/dev/video3";
  }

  // Open video device
  if ((video_fd = open(device, O_RDWR|O_NONBLOCK, 0)) == -1)
    //  if ((video_fd = open(device, O_RDWR, 0)) == -1)
    return v4l2_error("Could not open video device");
  fprintf(stdout, "open: %d\n", video_fd);

  return 0;
}

int v4l2_init_mmap() {
  struct v4l2_requestbuffers req;
  req.count = nbuffer;
  req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  req.memory = V4L2_MEMORY_MMAP;
  if (xioctl(video_fd, VIDIOC_REQBUFS, &req))
    return v4l2_error("VIDIOC_REQBUFS");
  if (req.count < 2)
    return v4l2_error("Insufficient buffer memory\n");

  buffers.resize(req.count);
  for (int i = 0; i < req.count; i++) {
    struct v4l2_buffer buf;
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    buf.index = i;
    if (xioctl(video_fd, VIDIOC_QUERYBUF, &buf) == -1)
      return v4l2_error("VIDIOC_QUERYBUF");
    buffers[i].length = buf.length;
    buffers[i].start = 
      mmap(NULL, // start anywhere
          buf.length,
          PROT_READ | PROT_WRITE, // required
          MAP_SHARED, // recommended
          video_fd,
          buf.m.offset);
    if (buffers[i].start == MAP_FAILED)
      return v4l2_error("mmap");
  }
  return 0;
}

int v4l2_uninit_mmap() {
  for (int i = 0; i < buffers.size(); i++) {
    if (munmap(buffers[i].start, buffers[i].length) == -1)
      return v4l2_error("munmap");
  }
  buffers.clear();
}

int v4l2_init(int resolution) {

  if( resolution == 1 ){
    width = 640;
    height = 480;
  } else {
    width = 1280;
    height = 720;
  }

  struct v4l2_capability video_cap;
  if (xioctl(video_fd, VIDIOC_QUERYCAP, &video_cap) == -1)
    return v4l2_error("VIDIOC_QUERYCAP");
  if (!(video_cap.capabilities & V4L2_CAP_VIDEO_CAPTURE))
    return v4l2_error("No video capture device");
  if (!(video_cap.capabilities & V4L2_CAP_STREAMING))
    return v4l2_error("No capture streaming");

  struct v4l2_format video_fmt;
  video_fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;

  // Get the current format
  if (xioctl(video_fd, VIDIOC_G_FMT, &video_fmt) == -1)
    return v4l2_error("VIDIOC_G_FMT");

  fprintf(stdout, "Current Format\n");
  fprintf(stdout, "+------------+\n");
  fprintf(stdout, "width: %u\n", video_fmt.fmt.pix.width);
  fprintf(stdout, "height: %u\n", video_fmt.fmt.pix.height);
  fprintf(stdout, "pixel format: %u\n", video_fmt.fmt.pix.pixelformat);
  fprintf(stdout, "pixel field: %u\n", video_fmt.fmt.pix.field);


  video_fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  video_fmt.fmt.pix.width       = width;
  video_fmt.fmt.pix.height      = height;
  video_fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_MJPEG;
//  video_fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
  //video_fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_UYVY; // iSight
  video_fmt.fmt.pix.field       = V4L2_FIELD_ANY;
  if (xioctl(video_fd, VIDIOC_S_FMT, &video_fmt) == -1)
    v4l2_error("VIDIOC_S_FMT");

  // Query V4L2 controls:
  int addr_end = 22;
  v4l2_query_ctrl(V4L2_CID_BASE,
      V4L2_CID_LASTP1);
  v4l2_query_ctrl(V4L2_CID_PRIVATE_BASE,
      V4L2_CID_PRIVATE_BASE+20);
  v4l2_query_ctrl(V4L2_CID_CAMERA_CLASS_BASE+1,
      V4L2_CID_CAMERA_CLASS_BASE+addr_end);

  // Logitech specific controls:
  v4l2_query_ctrl(V4L2_CID_FOCUS,
      V4L2_CID_FOCUS+1);
  v4l2_query_ctrl(V4L2_CID_LED1_MODE,
      V4L2_CID_LED1_MODE+1);
  v4l2_query_ctrl(V4L2_CID_LED1_FREQUENCY,
      V4L2_CID_LED1_FREQUENCY+1);
  v4l2_query_ctrl(V4L2_CID_DISABLE_PROCESSING,
      V4L2_CID_DISABLE_PROCESSING+1);
  v4l2_query_ctrl(V4L2_CID_RAW_BITS_PER_PIXEL,
      V4L2_CID_RAW_BITS_PER_PIXEL+1);

  //hack
  v4l2_query_ctrl(V4L2_CID_BASE,
      V4L2_CID_BASE+500);

  // Initialize memory map
  v4l2_init_mmap();
  handle = SsbSipJPEGDecodeInit();

  return 0;
}

int v4l2_stream_on() {
  for (int i = 0; i < buffers.size(); i++) {
    struct v4l2_buffer buf;
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    buf.index = i;
    if (xioctl(video_fd, VIDIOC_QBUF, &buf) == -1)
      return v4l2_error("VIDIOC_QBUF");
  }

  enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if (xioctl(video_fd, VIDIOC_STREAMON, &type) == -1)
    return v4l2_error("VIDIOC_STREAMON");

  return 0;
}

int v4l2_stream_off() {
  enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if (xioctl(video_fd, VIDIOC_STREAMOFF, &type) == -1)
    return v4l2_error("VIDIOC_STREAMOFF");

  return 0;
}

void * v4l2_get_buffer(int index, size_t *length) {
  if (length != NULL)
    *length = buffers[index].length;
//  if( invert==1 ) {
//    return (void *) 
//	yuyv_rotate( (uint8_t*)buffers[index].start, width, height );
//  }
//  printf("before decode buffers[index].start :%08x\n",buffers[index].start);
  jpgBuffer.size = 0;

	SaveJpgBuf((unsigned char *)buffers[index].start, buf0->bytesused);

  void *yuyvBuf[nbuffer-1];
  yuyvBuf[index] = (void *)Decompress(jpgBuffer.buf, jpgBuffer.size);

  if( invert==1 ) {
    return (void *) 
	yuyv_rotate( (uint8_t*)yuyvBuf[index], width, height );
  }
		  return yuyvBuf[index];
}

void * v4l2_get_buffer_from_file(int index, size_t *length) {
  if (length != NULL)
    *length = buffers[index].length;
  jpgBuffer.size = 0;

	SaveJpgBuf((unsigned char *)buffers[index].start, buf0->bytesused);

  void *yuyvBuf[nbuffer-1];
  yuyvBuf[index] = (void *)Decompress(jpgBuffer.buf, jpgBuffer.size);

  if( invert==1 ) {
    return (void *) 
	yuyv_rotate( (uint8_t*)yuyvBuf[index], width, height );
  }
		  return yuyvBuf[index];
}

int v4l2_read_frame() {
  struct v4l2_buffer buf;
  buf0 = &buf;
  buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  buf.memory = V4L2_MEMORY_MMAP;
  if (xioctl(video_fd, VIDIOC_DQBUF, &buf) == -1) {
    switch (errno) {
      case EAGAIN:
        // Debug line
        //fprintf(stdout, "no frame available\n");
        return -1;
      case EIO:
        // Could ignore EIO
        // fall through
      default:
        return v4l2_error("VIDIOC_DQBUF");
    }
  }
  assert(buf.index < buffers.size());

  // process image
  // Give out the pointer, and hope they give it back to us soon!
  void *ptr = buffers[buf.index].start;

  if (xioctl(video_fd, VIDIOC_QBUF, &buf) == -1){
    fprintf(stderr, "QBUF Problem %d\n", errno);
    fprintf(stderr, "Buf Index: %d\n",buf.index);
    fprintf(stderr, "Buf Type: 0x%X\n", buf.type);
    // Sleep a little and try again?
    return v4l2_error("VIDIOC_QBUF");
  }

  return buf.index;
}

int v4l2_close() {
  v4l2_uninit_mmap();
  if (close(video_fd) == -1)
    v4l2_error("Closing video device");
  video_fd = -1;
  SsbSipJPEGDecodeDeInit(handle);
}

int v4l2_get_width(){
  return width;
}

int v4l2_get_height(){
  return height;
}

void row_swap( uint32_t* row1addr, uint32_t* row2addr, int width ){

  // Swap into a temporary space
  int copy_amt = (width/2)*sizeof(uint32_t);
  uint32_t buffer_row[width/2];

  memcpy( buffer_row, row1addr, copy_amt ); // Copy 1 into tmp
  memcpy( row1addr, row2addr, copy_amt ); //Copy 2 into 1
  memcpy( row2addr, buffer_row, copy_amt ); // Copy tmp into 2
    
}


void yuyv_px_swap( uint8_t* ptr1, uint8_t* ptr2 ){
  uint8_t tmp_px[4]; // two pixels here

  // Put ptr1 into temporary space and swap Y values
  tmp_px[0] = ptr1[2];
  tmp_px[1] = ptr1[1];
  tmp_px[2] = ptr1[0];
  tmp_px[3] = ptr1[3];

  // Put ptr2 into ptr1
  ptr1[0] = ptr2[2];
  ptr1[1] = ptr2[1];
  ptr1[2] = ptr2[0];
  ptr1[3] = ptr2[3];

  // Copy tmp_px into ptr2
  memcpy( ptr2, tmp_px, 4*sizeof(uint8_t) );
}

uint8_t* yuyv_rotate(uint8_t* frame, int width, int height) {
  int i;
  //SJ: I maintain a second buffer here
  //So that we do not directly rewrite on camera buffer address

  static uint8_t frame2[1280*720*2];
  int *pr=NULL;
  int *pf=NULL;
  int *pr2=NULL;
  int *pf2=NULL;
  int x1,x2,x3,x4;

  //printf("WIDTH HEIGHT:%d %d\n",width,height);

  int siz = width*height/2;
  pr=(int *)(frame);
  pf=(int *)(frame+(siz-1)*4);
  pr2=(int *)(frame2);
  pf2=(int *)(frame2+(siz-1)*4);

  for (int i=0;i<siz/2;i++){
	x1 = *pr;
	x2 = *pf;
	x3 = x1 & 0xff00ff00;
	x3 |= (((x1>>16)&0x000000ff)|((x1<<16)&0x00ff0000));
	x4 = x2 & 0xff00ff00;
	x4 |= (((x2>>16)&0x000000ff)|((x2<<16)&0x00ff0000));
 	*pr2=x4;
	*pf2=x3;
	pr++;
	pf--;
	pr2++;
	pf2--;
	}
		//char *filename = "1234.jpg";
		//FILE *fp = fopen(filename, "wb");
		//fwrite(frame2, 1, 614400, fp);
		//fclose(fp);
		//printf("file saved\n");
		
	return frame2;
}

int IsHuffman(unsigned char *buf)
{
  unsigned char* ptbuf;
  int i = 0;
  ptbuf = buf;
  while (((ptbuf[0] << 8) | ptbuf[1]) != 0xffda) {	
    if(i++ > 2048) 
      return 0;
    if(((ptbuf[0] << 8) | ptbuf[1]) == 0xffc4)
      return 1;
    ptbuf++;
  }
  return 0;
}

int SaveJpgBuf(unsigned char *buf,int size)
{
  unsigned char *ptdeb,*ptcur = buf;
  int sizein;
//  printf("is Huffman?\n");
  if(!IsHuffman(buf)) {
//	printf("is not Huffman\n");
    ptdeb = ptcur = buf;
    while (((ptcur[0] << 8) | ptcur[1]) != 0xffc0) {
      ptcur++;
    }
    sizein = ptcur-ptdeb;
//	printf("size in is : %08x\n",sizein);
    memcpy(jpgBuffer.buf, buf, sizein);
    jpgBuffer.size += sizein;
//	printf("jpgBuffer.size 01 : %08x \n",jpgBuffer.size);
    memcpy(jpgBuffer.buf + jpgBuffer.size, dht_data, DHT_SIZE);
    jpgBuffer.size += DHT_SIZE;
//	printf("jpgBuffer.size 02 : %08x \n",jpgBuffer.size);
    memcpy(jpgBuffer.buf + jpgBuffer.size, ptcur, size - sizein);
    jpgBuffer.size += size - sizein;
//	printf("jpgBuffer.size 03 : %08x \n",jpgBuffer.size);
  }
  else {
//	printf("is Huffman\n");
    memcpy(jpgBuffer.buf, ptcur, size);
    jpgBuffer.size += size;
  }
  return 0;		
}
