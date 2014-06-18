#include "ruby.h"

#if defined(mswin) || defined(bccwin)
#include "serial_windows.h"
#elif defined(linux)
#include "serial_linux.h"
#else
// ERROR
#endif

static VALUE rb_cSerialComm; //, rb_eSerialCommError;
static VALUE sercom_close(VALUE self);

struct serialcommdata {
#if defined(mswin) || defined(bccwin)
  HANDLE cfd;
#elif defined(linux)
  int cfd;
#endif
  int read_timeout;
  int write_timeout;
};
 
static void
free_sercom(struct serialcommdata *sercomp)
{
#if defined(mswin) || defined(bccwin)
  if (sercomp->cfd != NULL)
#elif defined(linux)
  if (sercomp->cfd != -1)
#endif
    cleanup( &sercomp->cfd );

  free(sercomp);
}

static VALUE
sercom_self_allocate(VALUE self)
{
  struct serialcommdata *sercomp;
  VALUE obj;

  return Data_Make_Struct(self, struct serialcommdata, 0, free_sercom, sercomp);
}

static VALUE
sercom_is_ready(VALUE self)
{
  struct serialcommdata *sercomp;

  Data_Get_Struct(self, struct serialcommdata, sercomp);
  
#if defined(mswin) || defined(bccwin)
  return (sercomp->cfd == NULL) ? Qfalse : Qtrue;
#elif defined(linux)
  return (sercomp->cfd == -1) ? Qfalse : Qtrue;
#endif
}

static VALUE
sercom_initialize(VALUE self)
{
  struct serialcommdata *sercomp;

  Data_Get_Struct(self, struct serialcommdata, sercomp);
  
#if defined(mswin) || defined(bccwin)
  sercomp->cfd = NULL;
#elif defined(linux)
  sercomp->cfd = -1;
#endif
  sercomp->read_timeout = 0;
  sercomp->write_timeout = 0;

  return self;
}

static VALUE 
sercom_open(VALUE self, VALUE comport)
{
  struct serialcommdata *sercomp;
  int retval;
  VALUE comport_valid;
  
  Data_Get_Struct(self, struct serialcommdata, sercomp);

#if defined(mswin) || defined(bccwin)
  comport_valid = rb_str_concat(rb_str_new2("\\\\.\\"), comport);
#elif defined(linux)
  comport_valid = comport;
#endif

  if (sercom_is_ready(self) == Qtrue)
    if (sercom_close(self) != Qtrue)
      rb_raise(rb_eRuntimeError, "failed to close serial-comm when reopening");
  
  retval = openport(&sercomp->cfd, StringValuePtr(comport_valid) );
  
  return (retval == 0) ? Qtrue : Qnil;
}

static VALUE
sercom_close(VALUE self)
{
  struct serialcommdata *sercomp;
  int retval;

  Data_Get_Struct(self, struct serialcommdata, sercomp);

  retval = cleanup( &sercomp->cfd );

  return (retval == 0) ? Qtrue : Qnil;
}

static VALUE
sercom_config(VALUE self, VALUE baudrate, VALUE databits, VALUE stopbits, VALUE paritybits, VALUE flowctrl)
{
  struct serialcommdata *sercomp;
  int retval;
  int baud_rate, data_bits, stop_bits, parity_bits, flow_ctrl;
  
  Data_Get_Struct(self, struct serialcommdata, sercomp);

  if (sercom_is_ready(self) != Qtrue)
    rb_raise(rb_eRuntimeError, "serial-comm is not ready when configuring");
  
  baud_rate = NIL_P(baudrate) ? -1 : FIX2INT(baudrate);
  data_bits = NIL_P(databits) ? -1 : FIX2INT(databits);
  stop_bits = NIL_P(stopbits) ? -1 : FIX2INT(stopbits);
  parity_bits = NIL_P(paritybits) ? -1 : FIX2INT(paritybits);
  flow_ctrl = NIL_P(flowctrl) ? -1 : FIX2INT(flowctrl);

  retval = configure(&sercomp->cfd, baud_rate, data_bits, stop_bits, parity_bits, flow_ctrl);

  return (retval == 0) ? Qtrue : Qnil;
}

static VALUE
sercom_timeout(VALUE self, VALUE readtimeout, VALUE writetimeout)
{
  struct serialcommdata *sercomp;
  int retval;
  
  Data_Get_Struct(self, struct serialcommdata, sercomp);
  
  if (sercom_is_ready(self) != Qtrue)
    rb_raise(rb_eRuntimeError, "serial-comm is not ready when set timeout");
    
  sercomp->read_timeout = FIX2INT(readtimeout);
  sercomp->write_timeout = FIX2INT(writetimeout);
  
#if defined(mswin) || defined(bccwin)
  retval = timeout(&sercomp->cfd, sercomp->read_timeout, sercomp->write_timeout);
#elif defined(linux)
  sercomp->read_timeout *= 1000;
  sercomp->write_timeout *= 1000;
  retval = 0;
#endif

  return (retval == 0) ? Qtrue : Qnil;
}

static VALUE
sercom_read(VALUE self)
{
  struct serialcommdata *sercomp;
  int retval;
  char buffer[256];
  VALUE data;
  
  Data_Get_Struct(self, struct serialcommdata, sercomp);
  
  if (sercom_is_ready(self) != Qtrue)
    rb_raise(rb_eRuntimeError, "serial-comm is not ready when reading");
    
  data = rb_str_new(NULL, 0);
  
  while ((retval = readport(&sercomp->cfd, 256, buffer, sercomp->read_timeout)) > 0)
    rb_str_cat(data, buffer, retval);
  
  if (retval == -1) {
    // ERROR
  }
  
  return data;
}

static VALUE
sercom_write(VALUE self, VALUE data)
{
  struct serialcommdata *sercomp;
  int retval;
  
  Data_Get_Struct(self, struct serialcommdata, sercomp);
  
  if (sercom_is_ready(self) != Qtrue)
    rb_raise(rb_eRuntimeError, "serial-comm is not ready when writing");
    
  StringValue(data);

  retval = writeport(&sercomp->cfd, RSTRING(data)->len, RSTRING(data)->ptr, sercomp->write_timeout);
  
  if (retval == -1) {
    // ERROR
    retval = 0;
  }
  
  return INT2FIX(retval);
}

void Init_SerialComm() {
  rb_cSerialComm = rb_define_class("SerialComm", rb_cObject);
  rb_define_alloc_func(rb_cSerialComm, sercom_self_allocate);
  rb_define_method(rb_cSerialComm, "initialize", sercom_initialize, 0);
  rb_define_method(rb_cSerialComm, "open", sercom_open, 1);
  rb_define_method(rb_cSerialComm, "ready?", sercom_is_ready, 0);
  rb_define_method(rb_cSerialComm, "config", sercom_config, 5);
  rb_define_method(rb_cSerialComm, "timeout", sercom_timeout, 2);
  rb_define_method(rb_cSerialComm, "read", sercom_read, 0);
  rb_define_method(rb_cSerialComm, "write", sercom_write, 1);
  rb_define_method(rb_cSerialComm, "close", sercom_close, 0);
}

