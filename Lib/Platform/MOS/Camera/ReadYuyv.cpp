#include "ReadYuyv.h"

int ReadFileCleanup(
    int ret, uint32 **buffer, int *fileSize, int fd)
{
  if (ret) {
    if (*buffer) {
      free(*buffer);
      *buffer = NULL;
    }
    *fileSize = 0;
  }

  if (fd > 0) {
    close(fd);
    fd = -1;
  }

  return ret;
}

int ReadImgFile(char *fileName, uint32 **buffer, int *fileSize)
{
  int ret = 0;
  struct stat statbuf;
  int fd = -1;

  if (stat(fileName, &statbuf) != 0) 
  {
    fprintf(stderr, "Can't stat %s\n", fileName);
    ret = 5;
    return ReadFileCleanup(ret, buffer, fileSize, fd);
  }
  printf("mode: 0x%x. uid: %d. gid: %d. size: %lld.\n",
         statbuf.st_mode, statbuf.st_uid, statbuf.st_gid,
         statbuf.st_size);

  *buffer = (uint32 *)malloc(statbuf.st_size);
  if (! *buffer) 
  {
    fprintf(stderr, "Error allocating memory\n");
    ret = 7;
    return ReadFileCleanup(ret, buffer, fileSize, fd);
  }

  printf("Reading File...");
  fflush(stdout);

  fd = open(fileName, O_RDONLY);
  if (fd < 0) {
    fprintf(stderr, "Can't open %s\n", fileName);
    ret = 8;
    return ReadFileCleanup(ret, buffer, fileSize, fd);
  }

  if (read(fd, *buffer, statbuf.st_size) != statbuf.st_size) {
    fprintf(stderr, "Error reading %s\n", fileName);
    ret = 9;
    return ReadFileCleanup(ret, buffer, fileSize, fd);
  }

  *fileSize = statbuf.st_size;

  printf("Done. File Size is %u bytes.\n", *fileSize);

  fflush(stdout);

  return ReadFileCleanup(ret, buffer, fileSize, fd);

}

/******************************************
int main(int argc, char* argv[])
{
  char *fileName = "/home/nvidia/yuyvImg.jpg";
  uint32 *buffer = NULL;
  int fileSize = 0;

  int ret = ReadImgFile(fileName, &buffer, &fileSize);
  printf("ret = %d\n", ret);

  return 0;
}
*********************************************/
