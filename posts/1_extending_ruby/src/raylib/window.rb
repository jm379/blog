require_relative 'window.so'

RAYWHITE = Raylib::Color.new 245, 245, 245, 255
DARKGRAY = Raylib::Color.new 80, 80, 80, 255

Raylib.init_window 800, 450, 'Hello Raylib from Ruby'
Raylib.set_target_fps 60
while !Raylib.window_should_close do
  Raylib.begin_drawing

  Raylib.clear_background RAYWHITE
  Raylib.draw_text 'Hello Raylib, from Ruby!', 350, 225, 32, DARKGRAY
  Raylib.end_drawing
end

Raylib.close_window

exit 0
