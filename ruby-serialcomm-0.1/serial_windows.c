#if defined(mswin) || defined(bccwin)
//----------------------------

#include <stdio.h>
#include <string.h>

#include "serial_windows.h"

int openport(HANDLE *cfd, 
  char *comport)
{
  DCB dcb;
  
  *cfd = CreateFile(comport, GENERIC_READ | GENERIC_WRITE, 0, NULL,
    OPEN_EXISTING, 0, NULL);
    
  if (*cfd == INVALID_HANDLE_VALUE || *cfd == NULL) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
  	return -1;
  }

  if (!SetupComm(*cfd, 1024, 1024) != 0) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
	  return -1;
  }
  
  if (GetCommState(*cfd, &dcb) == 0) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
	  return -1;
  }
  
/* Discards all characters from input/output buffer and terminates
 * pending read/write operations
 */
	PurgeComm(*cfd, PURGE_TXABORT | PURGE_RXABORT |
			     PURGE_TXCLEAR | PURGE_RXCLEAR);

  dcb.fBinary = TRUE;
  dcb.fParity = FALSE;
  dcb.fOutxDsrFlow = FALSE;
  dcb.fDtrControl = DTR_CONTROL_ENABLE;
  dcb.fDsrSensitivity = FALSE;
  dcb.fTXContinueOnXoff = FALSE;
  dcb.fErrorChar = FALSE;
  dcb.fNull = FALSE;
  dcb.fAbortOnError = FALSE;
  dcb.XonChar = 17;
  dcb.XoffChar = 19;
  
  if (SetCommState(*cfd, &dcb) == 0) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
	  return -1;
  }
  
  return 0;
}

int configure(HANDLE *cfd,
  int baud_rate,  // CBR110 - CBR256000
  int data_bits,  // 5 - 8
  int stop_bits,  // 1, 2, 15 (1.5) (ONESTOPBIT, TWOSTOPBITS, ONE5STOPBITS)
  int parity_bits,  // 0 - 4 (NOPARITY, ODDPARITY, EVENPARITY, MARKPARITY, SPACEPARITY)
  int flow_ctrl)
{
  DCB dcb;

  if (!GetCommState(*cfd, &dcb)) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
    return -1;
  }
  
  if (baud_rate >= 0) {
    int baudrate;
    
    if ((baudrate = const_baudrate(baud_rate)) == -1) {
#ifdef DEBUG
      print_error(__LINE__);
#endif
      return -3;
    }
    
    dcb.BaudRate = baudrate;
  }
    
  if (stop_bits >= 0) {
    int stopbits;
    
    if ((stopbits = const_stopbits(stop_bits)) == -1) {
#ifdef DEBUG
      print_error(__LINE__);
#endif
      return -4;
    }
    
    dcb.StopBits = stopbits;
  }
  
  if (parity_bits >= 0) {
    dcb.Parity  = parity_bits;
    dcb.fParity = parity_bits == NOPARITY ? FALSE : TRUE;
  }
  
  if (data_bits >= 0)
    dcb.ByteSize = data_bits;

  if (flow_ctrl >= 0) {    
    if (flow_ctrl & 1)
      /* No Xon/Xof flow control */
	    dcb.fInX = dcb.fOutX = FALSE;
	  else
	    dcb.fInX = dcb.fOutX = TRUE;
	  
	  if (flow_ctrl & 2) {
	    /* Hardware flow control */
	    dcb.fOutxDsrFlow = TRUE;
	    dcb.fOutxCtsFlow = TRUE;
	    dcb.fDtrControl  = DTR_CONTROL_HANDSHAKE;
	    dcb.fRtsControl  = RTS_CONTROL_HANDSHAKE;
	  } else {
	    dcb.fRtsControl = RTS_CONTROL_ENABLE;
      dcb.fOutxCtsFlow = FALSE; 
	  }
	}
	
  if (!SetCommState(*cfd, &dcb)) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
	  return -2;
  }
  
  return 0;
}

int readconfiguration(HANDLE *cfd) 
{
  DCB dcb;

  if (!GetCommState(*cfd, &dcb)) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
    return -1;
  }
  
  return 0;  
}

int delay(int time)
{
  HANDLE ev;
  
  ev = CreateEvent(NULL, FALSE, FALSE, NULL);
  if (ev) {
    if (WaitForSingleObject(ev, time) == WAIT_FAILED) ;
    CloseHandle(ev);
  } else return -1;
  
  return 0;
}

int breaktime(HANDLE *cfd, int time) 
{
  if (SetCommBreak(*cfd) == 0) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
    return -1;
  }
  
  delay(time);
  
  ClearCommBreak(*cfd);
  
  return 0;
}

int timeout(HANDLE *cfd, 
  int read_timeout, int write_timeout )
{
  COMMTIMEOUTS ctout;
  
  if (!GetCommTimeouts(*cfd, &ctout)) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
    return -1;
  }
  
  ctout.ReadIntervalTimeout = MAXDWORD;
  ctout.ReadTotalTimeoutMultiplier = MAXDWORD;
  ctout.ReadTotalTimeoutConstant = read_timeout;
  
  ctout.WriteTotalTimeoutMultiplier = 0;
  ctout.WriteTotalTimeoutConstant = write_timeout;
  
  if (!SetCommTimeouts(*cfd, &ctout)) {
#ifdef DEBUG
    print_error(__LINE__);
#endif
    return -1;
  }
  
  return 0;
}

int linesignal(HANDLE *cfd, int signame)
{
  if (EscapeCommFunction(*cfd, signame) == 0)
    return -1;
    
  return 0;
}

int readport(HANDLE *cfd, int b2read, char *buffer, int totaltimeout)
{
  int bytesread;

  bytesread = 0;
  if (!ReadFile(*cfd, buffer, b2read, &bytesread, NULL)) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
	  return -1;
  }
  
  return bytesread;
}

int writeport(HANDLE *cfd, int b2write, char *buffer, int totaltimeout)
{
  int byteswritten;

  byteswritten = 0;
  if (!WriteFile(*cfd, buffer, b2write, &byteswritten, NULL)) {
#ifdef DEBUG
	  print_error(__LINE__);
#endif
	  return -1;
  }
  
  return byteswritten;
}

int cleanup(HANDLE *cfd)
{
  if (!CloseHandle(*cfd)) {
#ifdef DEBUG
  	print_error(__LINE__);
#endif
	  return -1;
  }
  
  *cfd = NULL;
  
  return 0; 
}

int const_baudrate(int baud_rate) 
{
  int baudrate;
  
  switch (baud_rate) {
    case 110:
    case 300:
    case 600:
    case 1200:
    case 2400:
    case 4800:
    case 9600:
    case 14400:
    case 19200:
    case 38400:
    case 56000:
    case 57600:
    case 115200:
    case 128000:
    case 256000:
      baudrate = baud_rate;
      break;
      
    default:  baudrate = -1; break;
  }
  
  return baudrate;
}

int const_stopbits(int stop_bits)
{
  int stopbits;
  
  switch (stop_bits) {
    case 1: stopbits = ONESTOPBIT; break;
    case 2: stopbits = TWOSTOPBITS; break;
    case 15: stopbits = ONE5STOPBITS; break;
    default: stopbits = -1; break;
  }
  
  return stopbits;
}

void print_error(int line)
{
  LPVOID msgbuf;
  FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER |
	  FORMAT_MESSAGE_IGNORE_INSERTS |
	  FORMAT_MESSAGE_FROM_SYSTEM,
	  NULL,
	  GetLastError(),
	  MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
	  (LPTSTR) & msgbuf, 0, NULL);
	  
  fprintf(stderr, "(%s) Err Line #%i: %s\n", __FILE__, line, msgbuf);
}


// FOR TESTING PURPOSE ONLY
#ifdef TESTING
int main()
{
  HANDLE fd;
  
  char buf[256];
  int r,w,ri;
  char *cmd = "ATI3\r\n";
  
  openport(&fd, "\\\\.\\COM3");
  configure(&fd, 9600, 8, 1, 0, 0);
  timeout(&fd, 50, 10);
  printf("Handle: 0x%x\n", fd);
  
  w = writeport(&fd, strlen(cmd), cmd, 10);
  printf("Written: %d\n", w);
  ri = 0;
  while ((r = readport(&fd, 16, buf + ri, 50)) > 0) {
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
