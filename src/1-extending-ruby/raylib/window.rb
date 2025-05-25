#!/usr/bin/env ruby

require_relative 'window.so'

RAYWHITE = Raylib::Color.new 245, 245, 245, 255
LIGHTGRAY = Raylib::Color.new 200, 200, 200, 255

Raylib.init_window 800, 450, 'raylib [core] example - basic window'
Raylib.set_target_fps 60

while !Raylib.window_should_close? do
  Raylib.begin_drawing
  Raylib.clear_background RAYWHITE
  Raylib.draw_text 'Congrats! You created your first window!', 190, 200, 20, LIGHTGRAY
  Raylib.end_drawing
end

Raylib.close_window

exit 0
