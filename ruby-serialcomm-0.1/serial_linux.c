#if defined(linux)
//----------------------------

#include <stdio.h>   /* Standard input/output definitions */
#include <unistd.h>  /* UNIX standard function definitions */
#include <fcntl.h>   /* File control definitions */
#include <errno.h>   /* Error number definitions */
#include <termios.h> /* POSIX terminal control definitions */
#include <sys/ioctl.h>

#include "serial_linux.h"

int const_baudrate(int baud_rate);
int const_databits(int data_bits);

// return:  0 OK
//         -1 ERROR: invalid handle
//         -2 ERROR: not serial port
//         -3 ERROR: failed get attributes
//         -4 ERROR: failed set attributes
int openport(int *cfd, 
  char *comport)
{ 
  struct termios options;
  
  *cfd = open(comport, O_RDWR | O_NOCTTY | O_NDELAY);
  if (*cfd == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
	  return -1;
  }
  
  if (!isatty(*cfd)) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    close(*cfd);
	  return -2;
  }

#ifdef TIOCEXCL
	/* exclusive */
	ioctl(*cfd, TIOCEXCL, (int *) 0);
#endif

  /* enable blocking read */
  // fcntl(*cfd, F_SETFL, fcntl(*cfd, F_GETFL, 0) & ~O_NONBLOCK);
  
  if (tcgetattr(*cfd, &options) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    close(*cfd);
    return -3;
  }
 
  options.c_oflag = 0;
  options.c_lflag = 0;
  options.c_iflag &= (IXON | IXOFF | IXANY); // | IGNPAR;
  options.c_cflag |= CLOCAL | CREAD;
  options.c_cflag &= ~HUPCL;
  options.c_cc[VTIME] = 0;
  options.c_cc[VMIN] = 1;
    
#ifdef TCIOFLUSH
  if (tcflush(*cfd, TCIOFLUSH) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
  }
#endif
  
  if (tcsetattr(*cfd, TCSANOW, &options) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    close(*cfd);
    return -4;
  }
   
  return 0;
}

int configure(int *cfd,
  int baud_rate, //B50 - B230400 
  int data_bits, //CS5 - CS8
  int stop_bits, // 1 - 2
  int parity_bits, // 0 NONE, 1 ODD, 2 EVEN
  int flow_ctrl)  // 0 NONE, 1 SOFT, 2 HARD
{
  struct termios options;
  
  if (tcgetattr(*cfd, &options) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -1;
  }
  
  // Baudrate
  if (baud_rate >= 0) {
    int baudrate;
    
    if ((baudrate = const_baudrate(baud_rate)) == -1) {
#ifdef DEBUG
	    print_error(__LINE__);
#endif
      return -3;
    }

    cfsetispeed(&options, baudrate);
    cfsetospeed(&options, baudrate);
  }
  
  // Data-bits
  if (data_bits >= 0) {
    int databits;
    
    if ((databits = const_databits(data_bits)) == -1) {
#ifdef DEBUG
	    print_error(__LINE__);
#endif
      return -4;
    }

    options.c_cflag &= ~CSIZE;
    options.c_cflag |= databits;
  }
  
  // Stop-bits
  if (stop_bits >= 0) {
    switch (stop_bits) {
      case 1:
        options.c_cflag &= ~CSTOPB;
        break;
      case 2:
        options.c_cflag |= CSTOPB;
        break;
    }
  }
  
  // Parity-bits
  if (parity_bits >= 0) {
    switch (parity_bits) {
      case 0: // NONE
        options.c_cflag &= ~PARENB;
        break;
      
      case 1: // ODD
        options.c_cflag |= PARENB;
        options.c_cflag |= PARODD;
        break;
        
      case 2: // EVEN
        options.c_cflag |= PARENB;
        options.c_cflag &= ~PARODD;
        break;
    }
  }

  // Flow-control
  if (flow_ctrl >= 0) {
    if (flow_ctrl & 1) // SOFT
      options.c_iflag |= (IXON | IXOFF | IXANY);
    else
      options.c_iflag &= ~(IXON | IXOFF | IXANY);

    if (flow_ctrl & 2) // HARD
#ifdef CRTSCTS
      options.c_cflag |= CRTSCTS;
    else
      options.c_cflag &= ~CRTSCTS;
#else
      return -1;    
#endif
  }
      
  if (tcsetattr(*cfd, TCSANOW, &options) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -2;
  }   
  
  return 0;
}

/* NON-CANONICAL 

int timeout(int *cfd, 
  int read_timeout, int write_timeout)
{
  struct termios options;
  
  if (tcgetattr(*cfd, &options) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -1;
  }
  
  if (read_timeout < 0) {  // no time out
    options.c_cc[VTIME] = 0;
    options.c_cc[VMIN] = 0;
  } else if (read_timeout == 0) {  // 1 caharacter out
    options.c_cc[VTIME] = 0;
    options.c_cc[VMIN] = 1;
  } else {
    options.c_cc[VTIME] = read_timeout < 50 ? 1 : (read_timeout + 50) / 100;
    options.c_cc[VMIN] = 0;
  }
  
  if (tcsetattr(*cfd, TCSANOW, &options) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -2;
  }
  
  return 0;
}
*/

int readconfiguration(int *cfd) 
{
  struct termios options;
  
  if (tcgetattr(*cfd, &options) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -1;
  }
  
  return 0;  
}

int breaktime(int *cfd, int time) 
{
  if (tcsendbreak(*cfd, time / 3) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -1;
  }

  return 0;
}

int linesignal(int *cfd, int signame, int setreset)
{
  int status;
  
  if (ioctl(*cfd, TIOCMGET, &status) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -1;
  }
  
  if (setreset)
    status |= signame;
  else
    status &= ~signame;

  if (ioctl(*cfd, TIOCMSET, &status) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -1;
  }
    
  return 0;
}

int readlinesignal(int *cfd, int *status)
{
  if (ioctl(*cfd, TIOCMGET, status) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
    return -1;
  }
    
  return 0;
}

int readport(int *cfd, int b2read, char *buffer, int totaltimeout)
{
  int bytesread, ret, total_usec;
  struct timeval readtimeout;
  fd_set readfds;
  
  FD_ZERO(&readfds);
  FD_SET(*cfd, &readfds);

  total_usec = 0;
  bytesread = 0;
  do {
    ret = read(*cfd, buffer+bytesread, b2read-bytesread);
    if (ret <= 0) { // ret == -1
      if ( (ret == -1 && errno == EAGAIN) || (ret == 0) ) {
        if (total_usec < totaltimeout) {
          // set time out
          readtimeout.tv_sec     = 0;
          readtimeout.tv_usec    = 10000;
          if (ret == -1)
            select(*cfd+1, &readfds, 0, 0, &readtimeout);
          else
				    select(FD_SETSIZE, 0, 0, 0, &readtimeout);
				
				  // count timeout
				  total_usec += 10000 - readtimeout.tv_usec;
				  //printf("rd_usec: %d\n", total_usec);
				  continue;
				}
			} else {
#ifdef DEBUG
        print_error(__LINE__);
#endif
      }
	    break;
		} else total_usec = 0;
		bytesread += ret;
  } while (bytesread < b2read);

  return bytesread;
}

int writeport(int *cfd, int b2write, char *buffer, int totaltimeout)
{
  int byteswritten, ret, total_usec;
  struct timeval writetimeout;
  fd_set writefds;
  
  FD_ZERO(&writefds);
  FD_SET(*cfd, &writefds);

  total_usec = 0;
  byteswritten = 0;
  do {
    ret = write(*cfd, buffer+byteswritten, b2write-byteswritten);
    if (ret <= 0) { // ret == -1
      if ( (ret == -1 && errno == EAGAIN) || (ret == 0) ) {
        if (total_usec < totaltimeout) {
          // set time out
          writetimeout.tv_sec     = 0;
          writetimeout.tv_usec    = 10000;
          if (ret == -1)
            select(*cfd+1, 0, &writefds, 0, &writetimeout);
          else
				    select(FD_SETSIZE, 0, 0, 0, &writetimeout);
				
				  // count timeout
				  total_usec += 10000 - writetimeout.tv_usec;
				  //printf("wr_usec: %d\n", total_usec);
				  continue;
				}
			} else {
#ifdef DEBUG
        print_error(__LINE__);
#endif
      }
	    break;
		} else total_usec = 0;
		byteswritten += ret;
  } while (byteswritten < b2write);
  
  return byteswritten;    
}

int cleanup(int *cfd)
{
  if (close(*cfd) == -1) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
	  return -1;
  }
  
  *cfd = -1;
  
  return 0;
}

int const_baudrate(int baud_rate) 
{
  int baudrate;
  
  switch(baud_rate) {
    case 50:    baudrate = B50; break;
    case 75:    baudrate = B75; break;
    case 110:   baudrate = B110; break;
    case 134:   baudrate = B134; break;
    case 150:   baudrate = B150; break;
    case 200:   baudrate = B200; break;
    case 300:   baudrate = B300; break;
    case 600:   baudrate = B600; break;
    case 1200:  baudrate = B1200; break;
    case 1800:  baudrate = B1800; break;
    case 2400:  baudrate = B2400; break;
    case 4800:  baudrate = B4800; break;
    case 9600:  baudrate = B9600; break;
    case 19200: baudrate = B19200; break;
    case 38400: baudrate = B38400; break;
#ifdef B57600
    case 57600: baudrate = B57600; break;
#endif
#ifdef B76800
    case 76800: baudrate = B76800; break;
#endif
#ifdef B115200
    case 115200: baudrate = B115200; break;
#endif
#ifdef B230400
    case 230400: baudrate = B230400; break;
#endif
    default:  baudrate = -1; break;
  }
  
  return baudrate;
}

int const_databits(int data_bits)
{
  int databits;
  
  switch(data_bits) {
    case 5: databits = CS5; break;
    case 6: databits = CS6; break;
    case 7: databits = CS7; break;
    case 8: databits = CS8; break;
    default: databits = -1; break;
  }
  
  return databits;
}

void print_error(int line)
{
  fprintf(stderr, "(%s) Err Line #%i\n", __FILE__, line);
}

// FOR TESTING PURPOSE ONLY
#ifdef TESTING
int main()
{
  int fd;
  char buf[256];
  int r,w,ri;
  char *comport = "/dev/ttyUSB0";
  if (openport(&fd, comport)) {
    printf("failed to open %s\n", comport);
    return 0;
  }
  if (configure(&fd, 115200, 8, 1, 0, 0)) {
    printf("failed to configure %s\n", comport);
    return 0;
  }
  // timeout(&fd, 2000, 0);
  
  w = writeport(&fd, 6, "ATI3\r\n", 100000);
  printf("Written: %d\n", w);
  ri = 0;
  while ((r = readport(&fd, 255, buf + ri, 50000)) > 0) {
    ri += r;
  }
  buf[ri] = '\0';
  printf("Response (%d) : %s\n", r, buf);
  
  cleanup(&fd);
  
  return 0;
}
#endif

//----------------------------
#endif
