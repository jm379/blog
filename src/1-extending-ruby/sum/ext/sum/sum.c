#include <ruby.h>

static VALUE add(VALUE self, VALUE a, VALUE b) {
  return RB_INT2FIX(RB_FIX2INT(a) + RB_FIX2INT(b));
}

void Init_sum(void) {
  VALUE sumClass = rb_define_class("Sum", rb_cObject);
  rb_define_singleton_method(sumClass, "add", add, 2);
}
