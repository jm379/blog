#include "color.h"

VALUE color_initialize(VALUE self, VALUE red, VALUE green, VALUE blue, VALUE alpha) {
  ID iv_red = rb_intern("@red");
  rb_ivar_set(self, iv_red, red);

  ID iv_green = rb_intern("@green");
  rb_ivar_set(self, iv_green, green);

  ID iv_blue = rb_intern("@blue");
  rb_ivar_set(self, iv_blue, blue);

  ID iv_alpha = rb_intern("@alpha");
  rb_ivar_set(self, iv_alpha, alpha);

  return self;
}
