## Introduction

Ruby is a great programming laguage, known for its developer friendliness and fast development.
Unfortunately that comes with a performance cost, although with its recents improvements, like the native Ruby parser
[PRISM](https://github.com/ruby/prism), or using Rust on its just in time compiler [YJIT](https://github.com/ruby/ruby/blob/master/doc/yjit/yjit.md).

However, there are times when you have to push the performance further, like adding [SIMD](https://en.wikipedia.org/wiki/Single_instruction,_multiple_data),
or maybe there's a library with C binding, like [raylib](https://github.com/raysan5/raylib), 
or even integrating with Large Language Models, and extending Ruby can be the perfect solution.

The Ruby MRI (Matz's Ruby Interpreter or CRuby) implementation provides a C API to extend its capabilities.
There are two ways of extending Ruby, an easier approach using [FFI](https://en.wikipedia.org/wiki/Foreign_function_interface), 
or compiling and loading a [shared library](https://en.wikipedia.org/wiki/Shared_library)
for more control.

This post will focus on the compilation method to create C extensions for Ruby on [GNU/Linux](https://stallman-copypasta.github.io/),
by first creating a simple adder class, and then wrapping raylib to create a [simple window](https://github.com/raysan5/raylib/blob/master/examples/core/core_basic_window.c).
Every example was created using Ruby `3.4.3`, other versions may not work!.

## Let's Add

First and foremost, we have to be confortable with reading and writing C,
and then, get familiar with the [C API](https://docs.ruby-lang.org/en/master/extension_rdoc.html).

Every extension should be located in the `./ext/<extension_name>/<extension_name>.c` directory.
Knowing that, lets create the directory structure and the file needed.

```shell
$ mkdir -p ./sum/ext/sum && \
    cd sum && \
    touch ext/sum/sum.c && \
    tree
.
└── ext
   └── sum
       └── sum.c

3 directories, 1 file
```

Now open your favorite editor and add these contents to the `sum.c` file.

```c
#include <ruby.h>

static VALUE add(VALUE self, VALUE a, VALUE b) {
  return RB_INT2FIX(RB_FIX2INT(a) + RB_FIX2INT(b));
}

void Init_sum(void) {
  VALUE sumClass = rb_define_class("Sum", rb_cObject);
  rb_define_singleton_method(sumClass, "add", add, 2);
}
```

Wow! that's a lot of weird stuff!  
Lets break down the file in parts so we can understand what's happening.

The `#include <ruby.h>` allows the usage of the Ruby C API, so we can interact with Ruby within our
C code.


Let's analyze the `add` function:

- The [`VALUE`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/value.h#L40)
is an `uintptr_t`, an unsigned integer that can be used as a pointer, and it represents a Ruby Object,
so it could be an Integer, Array, File, etc...

- The [`RB_FIX2INT`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/arithmetic/int.h#L129)
is a function that converts a `VALUE` to a C Integer.

- The [`RB_INT2FIX`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/arithmetic/long.h#L111)
is a function that converts a C Integer into a `VALUE`.

So the `VALUE add(VALUE self, VALUE a, VALUE b)` function receives two Ruby objects (`VALUE a` and `VALUE b`),
converts them to C Integers, adds them, wraps the result into a `VALUE`, and then returns it.


Finally, let's analyze the `Init_sum` function:

- The function `void Init_sum(void)` is the entrypoint of our extension. It should always be named like
`Init_<extension_name>`.

- The [`rb_define_class`](https://github.com/ruby/ruby/blob/c52f4eea564058a8a9865ccc8b2aa6de0c04d156/class.c#L1481)
function is used to create a class Object in Ruby, it expects the name of the class, and its superclass.
Every object **must** have a superclass.

- The `VALUE sumClass = rb_define_class("Sum", rb_cObject);` creates a class `Sum`, with a superclass
[`rb_cObject`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/globals.h#L68)
that references to `Object` in Ruby, and then stores the Ruby class into `VALUE sumClass`.

- The [`rb_define_singleton_method`](https://github.com/ruby/ruby/blob/c52f4eea564058a8a9865ccc8b2aa6de0c04d156/class.c#L2820)
is used to create an `add` singleton method for the class `VALUE sumClass`.

All of that to would be the same in Ruby as:

```ruby
class Sum
  def self.add(a, b)
    return a + b
  end
end
```

Now, how do we run this C file? Easy, we need to compile it into a shared library!

Ruby have a module ([MakeMakefile](https://docs.ruby-lang.org/en/3.4/MakeMakefile.html)) that provides a
DSL to create a Makefile and compile our extension into a shared library. Let's create `ext/sum/extconf.rb`.

```ruby
require 'mkmf'

create_makefile 'sum/sum'
```

Since our this example is very simple, there is no need to add more options to compile this extension.
To generate the Makefile, we need to run the `extconf.rb`

```shell
$ ruby ext/sum/extconf.rb && \
    tree

creating Makefile
.
├── ext
│   └── sum
│       ├── extconf.rb
│       └── sum.c
└── Makefile

3 directories, 3 files
```

That will create the Makefile in the current directory. Now we just need to compile using `make`. The
Makefile will create two files in our current directory, `sum.o` and `sum.so`. Only the `sum.so` is
important for our needs.

```shell
$ make && \
    tree

compiling ext/sum/sum.c
linking shared-object sum/sum.so
.
├── ext
│   └── sum
│       ├── extconf.rb
│       └── sum.c
├── Makefile
├── sum.o
└── sum.so

3 directories, 5 files
```

Done. We created our first C shared library that can be used directly in Ruby!
To use the `sum.so` it only needs to be required as `require_relative 'sum'`. Here is an example

```ruby
require_relative 'sum'

Sum.add 2, 3 # => 5
```


## Windows Time

Time for a more complex task, building a window using raylib. First we need to 
[build it](https://github.com/raysan5/raylib/wiki/Working-on-GNU-Linux),
then, let's create the directories and files needed.

```shell
$ mkdir -p raylib/ext && \
     cd raylib && \
     touch ext/raylib.c ext/color.h ext.color.c ext/extconf.rb window.rb && \
     tree
.
├── ext
│   └── window
│       ├── color.c
│       ├── color.h
│       ├── extconf.rb
│       └── window.c
└── window.rb

3 directories, 5 files
```

`ext/window/color.h`

```c
#include <ruby.h>
#include "raylib.h"

VALUE color_initialize(VALUE self, VALUE red, VALUE green, VALUE blue, VALUE alpha);
Color get_color(VALUE colorObj);
VALUE init_color(VALUE super);
```

`ext/window/color.c`

```c
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
```

We could have wrapped the [Raylib Color struct](https://github.com/raysan5/raylib/blob/8d9c1cecb7f53aef720e2ee0d1558ffc39fa7eef/src/raylib.h#L247)
into a [`TypedData_Wrap_Struct`](https://docs.ruby-lang.org/en/master/extension_rdoc.html#label-C+struct+to+Ruby+object),
but for simplicity, we'll use the helper function `Color get_color(VALUE colorObj)`
to build a Color struct from the `Raylib::Color` class.

[`rb_iv_set`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/variable.c#L4799)
sets an instance variable, in that case, sets `@red`, `@green`, `@blue`, and `@alpha`.

[`rb_iv_get`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/variable.c#L4788)
gets the instance variable from a ruby class.

[`RB_NUM2UINT`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/arithmetic/int.h#L185)
converts a Ruby [Numeric](https://docs.ruby-lang.org/en/master/Numeric.html) into a C `unsigned int`.

[`rb_define_attr`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/include/ruby/internal/method.h#L199)
defines either an `attr_reader`, or `attr_writer`, depending on the flags passed to `rb_define_attr`.

`ext/window/window.c`

```c
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
  init_color(raylibModule);
}
```

`ext/window/extconf.rb`

```ruby
require 'mkmf'

with_ldflags("-lraylib -lGL -lm -lpthread -ldl -lrt -lX11") { true }

create_makefile 'window/window'
```

`window.rb`

```ruby
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
```

After compiling and running the `window.rb`, it should open up a window exactly as the
[example from raylib](https://www.raylib.com/examples/core/loader.html?name=core_basic_window).

## Wrapping Up

TODO
