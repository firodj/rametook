#ifndef _SERIAL_WINDOWS_H
#define _SERIAL_WINDOWS_H

#include  <windows.h>

int openport(HANDLE *cfd, char *comport);
int configure(HANDLE *cfd, int baud_rate, int data_bits, int stop_bits, int parity_bits, int flow_ctrl);
int readconfiguration(HANDLE *cfd);
int linesignal(HANDLE *cfd, int signame);
int breaktime(HANDLE *cfd, int time);
int timeout(HANDLE *cfd, int read_timeout, int write_timeout );
int readport(HANDLE *cfd, int b2read, char *buffer, int totaltimeout);
int writeport(HANDLE *cfd, int b2write, char *buffer, int totaltimeout);
int cleanup(HANDLE *cfd);

void print_error(int line);

#endif /* serial.h */
