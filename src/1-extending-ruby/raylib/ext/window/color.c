#include "color.h"

// Same as:
// class Color
//   def initialize(red, green, blue, alpha)
//     @red = red
//     @green = green
//     @blue = blue
//     @alpha = alpha
//   end
// end
VALUE color_initialize(VALUE self, VALUE red, VALUE green, VALUE blue, VALUE alpha) {
  rb_iv_set(self, "@red", red);
  rb_iv_set(self, "@green", green);
  rb_iv_set(self, "@blue", blue);
  rb_iv_set(self, "@alpha", alpha);

  return self;
}

// Helper function to build a Raylib Color struct from ruby Color class
Color get_color(VALUE colorObj) {
  Color color;
  color.r = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@red"));
  color.g = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@green"));
  color.b = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@blue"));
  color.a = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@alpha"));

  return color;
}

VALUE init_color(VALUE super) {
    VALUE colorClass = rb_define_class_under(super, "Color", rb_cObject);
    rb_define_method(colorClass, "initialize", color_initialize, 4);

    // Creating attr_acessor :red, :green, :blue, :alpha for our Color class
    rb_define_attr(colorClass, "red", 1, 1);
    rb_define_attr(colorClass, "green", 1, 1);
    rb_define_attr(colorClass, "blue", 1, 1);
    rb_define_attr(colorClass, "alpha", 1, 1);

    return colorClass;
}
