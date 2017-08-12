
#ifndef CTRL_RS232_H
#define CTRL_RS232_H

int init_rs232(void);
int read_rs232(char *curr,int* len);
int write_rs232(char *curr,int len);
int destroy_rs232(void);

#endif
