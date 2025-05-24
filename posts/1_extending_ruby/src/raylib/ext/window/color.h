#include <ruby.h>
#include "raylib.h"

VALUE color_initialize(VALUE self, VALUE red, VALUE green, VALUE blue, VALUE alpha);
Color get_color(VALUE colorObj);
VALUE init_color(VALUE super);
