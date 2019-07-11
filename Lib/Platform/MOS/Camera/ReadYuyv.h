#include <stdio.h>
#include <iostream>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <memory.h>

typedef unsigned int uint32;

int ReadFileCleanup(int ret, unsigned char **buffer, int *fileSize, int fd);

int ReadImgFile(char *fileName, uint32 **buffer, int *fileSize);
