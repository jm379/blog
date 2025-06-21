#include <ruby.h>
#include <stdio.h>

VALUE calc(VALUE self, VALUE times) {
  size_t n = RB_NUM2SIZE(times);
  double pi = 0.0;
  double signal = -1.0;

  for(size_t i = 0; i < n; ++i) {
    signal = -signal;
    pi += signal / (2 * i + 1);
  }

  return rb_float_new(pi * 4.0);
}

void Init_leibniz(void) {
  VALUE leibnizModule = rb_define_module("Leibniz");
  rb_define_singleton_method(leibnizModule, "calc", calc, 1);
}
