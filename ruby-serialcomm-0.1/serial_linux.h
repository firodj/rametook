#ifndef _SERIAL_LINUX_H
#define _SERIAL_LINUX_H

int openport(int *cfd, char *comport);
int configure(int *cfd, int baud_rate, int data_bits, int stop_bits, int parity_bits, int flow_ctrl);
// int timeout(int *cfd, int read_timeout, int write_timeout);
int readconfiguration(int *cfd);
int breaktime(int *cfd, int time);
int linesignal(int *cfd, int signame, int setreset);
int readlinesignal(int *cfd, int *status);
int readport(int *cfd, int b2read, char *buffer, int totaltimeout);
int writeport(int *cfd, int b2write, char *buffer, int totaltimeout);
int cleanup(int *cfd);

void print_error(int line);

#endif
