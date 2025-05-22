#include <ruby.h>
#include "raylib.h"
#include "color.h"

static VALUE init_window(VALUE self, VALUE height, VALUE width, VALUE title) {
  InitWindow(
    RB_FIX2INT(height),
    RB_FIX2INT(width),
    StringValueCStr(title)
  );

  return Qnil;
}

static VALUE set_target_fps(VALUE self, VALUE fps) {
  SetTargetFPS(RB_FIX2INT(fps));

  return Qnil;
}

static VALUE window_should_close(VALUE self) {
  return WindowShouldClose() ? Qtrue : Qfalse;
}

static VALUE begin_drawing(VALUE self) {
  BeginDrawing();

  return Qnil;
}

static VALUE end_drawing(VALUE self) {
  EndDrawing();

  return Qnil;
}

static VALUE clear_background(VALUE self, VALUE colorObj) {
  Color color;
  color.r = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@red"));
  color.g = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@green"));
  color.b = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@blue"));
  color.a = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@alpha"));

  ClearBackground(color);

  return Qnil;
}

static VALUE draw_text(VALUE self, VALUE text, VALUE posX, VALUE posY, VALUE fontSize, VALUE colorObj) {
  Color color;
  color.r = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@red"));
  color.g = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@green"));
  color.b = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@blue"));
  color.a = (unsigned char) NUM2UINT(rb_iv_get(colorObj, "@alpha"));

  DrawText(
    StringValueCStr(text),
    RB_FIX2INT(posX),
    RB_FIX2INT(posY),
    RB_FIX2INT(fontSize),
    color
  );

  

  return Qnil;
}

static VALUE close_window(VALUE self) {
  CloseWindow();

  return Qnil;
}

void Init_window(void) {
  VALUE raylibModule = rb_define_module("Raylib");
  rb_define_singleton_method(raylibModule, "init_window", init_window, 3);
  rb_define_singleton_method(raylibModule, "set_target_fps", set_target_fps, 1);
  rb_define_singleton_method(raylibModule, "window_should_close", window_should_close, 0);
  rb_define_singleton_method(raylibModule, "begin_drawing", begin_drawing, 0);
  rb_define_singleton_method(raylibModule, "end_drawing", end_drawing, 0);
  rb_define_singleton_method(raylibModule, "clear_background", clear_background, 1);
  rb_define_singleton_method(raylibModule, "draw_text", draw_text, 5);
  rb_define_singleton_method(raylibModule, "close_window", close_window, 0);

  // Creating Color Class and methods
  VALUE colorClass = rb_define_class_under(raylibModule, "Color", rb_cObject);
  rb_define_method(colorClass, "initialize", color_initialize, 4);
  rb_define_attr(colorClass, "red", 1, 1);
  rb_define_attr(colorClass, "green", 1, 1);
  rb_define_attr(colorClass, "blue", 1, 1);
  rb_define_attr(colorClass, "alpha", 1, 1);
}
