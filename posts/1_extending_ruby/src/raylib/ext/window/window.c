#include "color.h"
// color.h already includes ruby.h and raylib.h,
// so there is no need for include them here too

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
  return WindowShouldClose();
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
  ClearBackground(get_color(colorObj));

  return Qnil;
}

static VALUE draw_text(VALUE self, VALUE text, VALUE posX, VALUE posY, VALUE fontSize, VALUE colorObj) {
  DrawText(
    StringValueCStr(text),
    RB_FIX2INT(posX),
    RB_FIX2INT(posY),
    RB_FIX2INT(fontSize),
    get_color(colorObj)
  );

  return Qnil;
}

static VALUE close_window(VALUE self) {
  CloseWindow();

  return Qnil;
}

void Init_window(void) {
  // Creating a Raylib module
  VALUE raylibModule = rb_define_module("Raylib");
  rb_define_singleton_method(raylibModule, "init_window", init_window, 3);
  rb_define_singleton_method(raylibModule, "set_target_fps", set_target_fps, 1);
  rb_define_singleton_method(raylibModule, "window_should_close?", window_should_close, 0);
  rb_define_singleton_method(raylibModule, "begin_drawing", begin_drawing, 0);
  rb_define_singleton_method(raylibModule, "end_drawing", end_drawing, 0);
  rb_define_singleton_method(raylibModule, "clear_background", clear_background, 1);
  rb_define_singleton_method(raylibModule, "draw_text", draw_text, 5);
  rb_define_singleton_method(raylibModule, "close_window", close_window, 0);

  // Creating a Raylib::Color Class
  VALUE colorClass = init_color(raylibModule);
}
