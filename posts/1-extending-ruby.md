---
index: 1
title: Extending Ruby
date: 2025-05-24
---

Ruby is a great programming language, known for its developer-friendly sintax, flexibility with [metaprogramming](https://en.wikipedia.org/wiki/Metaprogramming),
and especially, [Rails](https://rubyonrails.org/). Over the last few years, it has gained some significant
features in terms of performance, such as the native Ruby parser [PRISM](https://github.com/ruby/prism)
and the use of Rust on its just-in-time compiler [YJIT](https://docs.ruby-lang.org/en/master/yjit/yjit_md.html),
just to name a few!

However, there are times when you need to push performance beyond what Ruby is capable of, such as 
using [SIMD](https://en.wikipedia.org/wiki/Single_instruction,_multiple_data), using a library like [raylib](https://github.com/raysan5/raylib),
or even using plain C for its performance benefits. In these cases, extending Ruby can be the perfect solution.

The Ruby MRI (Matz's Ruby Interpreter, also known as CRuby) implementation provides a C API to extend its capabilities.
There are two primary methods for extending Ruby: a simpler approach using a [FFI](https://en.wikipedia.org/wiki/Foreign_function_interface)
gem or compiling a [shared library](https://en.wikipedia.org/wiki/Shared_library).

This post will primarily focus on the compilation method to create extensions for Ruby on GNU/Linux.
All examples were created using Ruby `3.4.3`, other versions may not be compatible.

## Leibniz

The [Leibniz formula for *π*](https://en.wikipedia.org/wiki/Leibniz_formula_for_%CF%80) is a simple
mathematical series that expresses *π* as an infinite sum. It's derived from the [Taylor series](https://en.wikipedia.org/wiki/Taylor_series)
expansion of the arctangent function, and is given by the formula:

<math display="block">
  <mfrac>
    <mi>π</mi>
    <mn>4</mn>
  </mfrac>
  <mo>=</mo>
  <mn>1</mn>
  <mo>-</mo>
  <mfrac>
    <mn>1</mn>
    <mn>3</mn>
  </mfrac>
  <mo>+</mo>
  <mfrac>
    <mn>1</mn>
    <mn>5</mn>
  </mfrac>
  <mo>-</mo>
  <mfrac>
    <mn>1</mn>
    <mn>7</mn>
  </mfrac>
  <mo>+</mo>
  <mfrac>
    <mn>1</mn>
    <mn>9</mm>
  </mfrac>
  <mo lspace="0.2em" form="postfix">⋯</mo>
</math>

<math display="block">
  <mfrac>
    <mi>π</mi>
    <mn>4</mn>
  </mfrac>
  <mo>=</mo>
  <munderover>
    <mo>∑</mo>
    <mrow>
      <mi>n</mi>
      <mo>=</mo>
      <mn>0</mn>
    </mrow>
    <mrow>
      <mo form="prefix">+</mo>
      <mn>∞</mn>
    </mrow>
  </munderover>
  <mfrac>
    <msup>
      <mrow>
        <mo>(</mo>
        <mo form="prefix">-</mo>
        <mn>1</mi>
        <mo>)</mo>
      </mrow>
      <mi>n</mi>
    </msup>
    <mrow>
      <mn>2</mn>
      <mo></mo>
      <mi>n</mi>
      <mo>+</mo>
      <mn>1</mn>
    </mrow>
  </mfrac>
</math>

This series converges to *π*/4 by alternating between adding and subtracting fractions, where each term
represents a progressively smaller contribution to the total. The Leibniz formula is very straightforward
to understand and implement, but its convergence is extremely slow. It requires an enormous amount of
terms to calculate a decent amount of decimal places of *π* accurately.  
Here is an implementation of the formula in Ruby

```ruby
# leibniz.rb

require 'benchmark'

def leibniz(n)
  signal = -1.0
  pi = 0.0

  n.times do
    signal = -signal
    pi += signal / (2 * it + 1)
  end

  pi * 4.0
end

Benchmark.bm do
  it.report('Ruby') { leibniz(100_000_000) }
end

# $ ruby --yjit leibniz.rb
#           user     system      total        real
# Ruby  2.887397   0.000000   2.887397 (  2.895165)

# $ ruby leibniz.rb
#           user     system      total        real
# Ruby  5.563026   0.000000   5.563026 (  5.580288)
```

The benchmark result was obtained on an [AMD Ryzen 5900X](https://www.amd.com/en/products/processors/desktops/ryzen/5000-series/amd-ryzen-9-5900x.html),
a 12 core CPU, and it still took 2.89 seconds to calculate 100 million terms, and without YJIT enabled,
it took 5.58 seconds!

Let's compare the performance of the C version of the Leibniz formula for *π*, as C is known for its 
efficiency and speed. This comparison will illustrate how Ruby performs in contrast.

```c
// leibniz.c

#include <stddef.h>

double leibniz(size_t n) {
  double pi = 0.0;
  double signal = -1.0;

  for (unsigned int i = 0; i < n; ++i) {
    signal = -signal;
    pi += signal / (2 * i + 1);
  }

  return pi * 4.0;
}

int main(void) {
  leibniz(100000000);

  return 0;
}

// $ gcc -o leibniz leibniz.c && \
//     time ./leibniz
// 0,09s user 0,00s system 99% cpu 0,094 total
```

Based on the benchmark results, the C implementation executed in approximately in 0.094 seconds, while
the Ruby implementation took 2.89 seconds, making it 30 times slower, and 59 times slower without YJIT! Most
of this difference comes from the fact that Ruby is a [interpreted](https://en.wikipedia.org/wiki/Interpreter_(computing)),
[garbage-collected](https://en.wikipedia.org/wiki/Garbage_collection_%28computer_science%29)
and [dynamically typed](https://en.wikipedia.org/wiki/Dynamic_programming_language) language, which incurs
in additional overhead by having to keep track of every memory allocation, transforming between Ruby types
and C types and having to interpret and run line by line of code.

There still room for improvements in the C code. By applying SIMD techniques, we can theoretically
enhance performance by up to four times. Let's compare the implementation with the SIMD version and
examine the differences between them.

```c
// leibniz-simd.c

#include <immintrin.h>

double leibniz_simd(size_t n) {
  double pi = 0.0;

  __m256d signal_vector = _mm256_set_pd(1.0, -1.0, 1.0, -1.0);
  __m256d one_vector = _mm256_set1_pd(1.0);
  __m256d two_vector = _mm256_set1_pd(2.0);
  __m256d four_vector = _mm256_set1_pd(4.0);
  __m256d result_vector = _mm256_setzero_pd();
  __m256d sum_vector = _mm256_setzero_pd();
  __m256d idx_vector = _mm256_set_pd(0.0, 1.0, 2.0, 3.0);

  for(unsigned int i = 0; i < n; i += 4) {
    sum_vector = _mm256_fmadd_pd(two_vector, idx_vector, one_vector);
    sum_vector = _mm256_div_pd(signal_vector, sum_vector);

    result_vector = _mm256_add_pd(result_vector, sum_vector);
    idx_vector = _mm256_add_pd(idx_vector, four_vector);
  }

  double temp[4];
  _mm256_storeu_pd(temp, result_vector);
  pi = temp[0] + temp[1] + temp[2] + temp[3];

  return pi * 4.0;
}

int main(void) {
  leibniz_simd(100000000);

  return 0;
}

// $ gcc -mavx2 -mfma -o leibniz-simd leibniz-simd.c && \
//     time ./leibniz-simd
// 0,02s user 0,00s system 98% cpu 0,025 total
```

The performance achieved by using SIMD is approximately 3.75 times faster than the straightforward
implementation in C and an impressive 115 times faster (223 times without YJIT) than pure Ruby! 

Now that we've seen the potential gains from using C, let's explore how we can use it to elevate Ruby
to a new level.

## Leibniz extension

Before we start, we have to be confortable with reading and writing C, and then, get familiar with 
the [C API](https://docs.ruby-lang.org/en/master/extension_rdoc.html).

Every extension should be located in the `ext/<extension_name>/<extension_name>.c` directory and have
a sibling file `extconf.rb` that is used to create a `Makefile` needed to compile the extension.
Let's create the directory structure and the files needed.

```shell
$ mkdir -p leibniz/ext/leibniz && \
    cd leibniz && \
    touch ext/leibniz/leibniz.c ext/leibniz/extconf.rb && \
    tree
.
└── ext
   └── leibniz
       ├── extconf.rb
       └── leibniz.c

3 directories, 2 file
```

Now open your favorite editor and add these contents to the `leibniz.c` file.

```c
// leibniz.c

VALUE calc(VALUE self, VALUE times) {
  size_t n = RB_NUM2SIZE(times);
  double pi = 0.0;
  double signal = -1.0;

  for(unsigned int i = 0; i < n; ++i) {
    signal = -signal;
    pi += signal / (2 * i + 1);
  }

  return DBL2NUM(pi * 4.0);
}

void Init_leibniz(void) {
  VALUE leibnizModule = rb_define_module("Leibniz");
  rb_define_singleton_method(leibnizModule, "calc", calc, 1);
}
```

Let's break down the file in parts so we can understand what's happening.

The `#include <ruby.h>` allows the usage of the Ruby C API, so we can interact with Ruby within our
C code.

In the `calc` function we have:

- The [`VALUE`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/value.h#L40)
is an `uintptr_t`, an unsigned integer that can be used as a pointer, and it represents a Ruby Object,
so it could be an Integer, Array, File, etc...

- The `VALUE self` is the object that the method is bound to. In this case it should be the `Leibniz` module
that is defined below.

- The [`RB_NUM2SIZE`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/arithmetic/size_t.h#L47)
is a function that converts a Ruby [`Numeric`](https://docs.ruby-lang.org/en/master/Numeric.html)
to a C `size_t`. It's an "alias" for [`RB_NUM2ULONG`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/arithmetic/long.h#L293).

- The [`DBL2NUM`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/arithmetic/double.h#L29)
is a function that converts a C double into a Ruby `Numeric`.

So the `VALUE calc(VALUE self, VALUE times)` function receives two Ruby objects
(`VALUE self` and `VALUE times`), converts the `times` into `size_t`, calculates the Leibniz 
formula, and then wraps and return the result into a `Numeric` `VALUE`.

The function `void Init_leibniz(void)` is the entrypoint of our extension. By CRuby convention,
It should always be named like `Init_<extension_name>`.

In the `Init_leibniz` function we have:

- The [`rb_define_module`](https://github.com/ruby/ruby/blob/c52f4eea564058a8a9865ccc8b2aa6de0c04d156/class.c#L1600)
function is used to create a [Module](https://docs.ruby-lang.org/en/master/Module.html) object in Ruby, 
it expects the name of the module and it automatically sets the superclass as the [`Namespace`](https://docs.ruby-lang.org/en/master/namespace_md.html)
Object if its defined, otherwise to [`Object`](https://docs.ruby-lang.org/en/master/Object.html).


- The `VALUE leibnizModule = rb_define_module("Leibniz");` creates a module `Leibniz`, and then stores
the Ruby Module into `VALUE leibnizModule`.

- The [`rb_define_singleton_method`](https://github.com/ruby/ruby/blob/c52f4eea564058a8a9865ccc8b2aa6de0c04d156/class.c#L2820)
is used to create a `calc` singleton method for the module `VALUE leibnizModule`.

That C code would be equivalent in Ruby:

```ruby
module Leibniz
  def self.calc(n)
    signal = -1.0
    pi = 0.0

    n.times do
      signal = -signal
      pi += signal / (2 * it + 1)
    end

    pi * 4.0
  end
end
```

Ruby have a module ([MakeMakefile](https://docs.ruby-lang.org/en/3.4/MakeMakefile.html)) that provides a
DSL to create a Makefile and compile our extension into a dynamic shared library.  
Let's modify the `ext/leibniz/extconf.rb` file to be able to produce a `Makefile`:

```ruby
require 'mkmf'

create_makefile 'leibniz/leibniz'
```

Since this example is very simple, there is no need to add more options to compile this extension.
To generate the Makefile, we need to run the `extconf.rb` file.

```shell
$ ruby ext/leibniz/extconf.rb && \
    tree

creating Makefile
.
├── ext
│   └── leibniz
│       ├── extconf.rb
│       └── leibniz.c
└── Makefile

3 directories, 3 files
```

This will create a Makefile in the current directory. Now we just need to compile using `make`. The
Makefile will create two files in our current directory, `leibniz.o` and `leibniz.so`.
Only the `leibniz.so` is important for us.

```shell
$ make && \
    tree

compiling ext/leibniz/leibniz.c
linking shared-object leibniz/leibniz.so
.
├── ext
│   └── leibniz
│       ├── extconf.rb
│       └── leibniz.c
├── Makefile
├── leibniz.o
└── leibniz.so

3 directories, 5 files
```

We created our first C shared library that can be used directly in Ruby!
To use the `leibniz.so` it only needs to be required as `require_relative 'leibniz'`. Here's an example
using `irb`:

```ruby
require_relative 'leibniz'

puts Leibniz.calc 100_000_000 # => 3.141592643589326
```


## Windows Time

Time for a more complex task, building a [window](https://github.com/raysan5/raylib/blob/master/examples/core/core_basic_window.c) using raylib. First we need to 
[build it](https://github.com/raysan5/raylib/wiki/Working-on-GNU-Linux), and then, create the 
directories and files needed.

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

Lets write the code.

```c
// ext/window/color.h

#include <ruby.h>
#include "raylib.h"

VALUE color_initialize(VALUE self, VALUE red, VALUE green, VALUE blue, VALUE alpha);
Color get_color(VALUE colorObj);
VALUE init_color(VALUE super);
```

```c
// ext/window/color.c

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

We could've wrapped the [Raylib Color struct](https://github.com/raysan5/raylib/blob/8d9c1cecb7f53aef720e2ee0d1558ffc39fa7eef/src/raylib.h#L247)
into a [`TypedData_Wrap_Struct`](https://docs.ruby-lang.org/en/master/extension_rdoc.html#label-C+struct+to+Ruby+object),
but for simplicity, we'll use a helper function `Color get_color(VALUE colorObj)`
to build a Color struct from the `Raylib::Color` class.

Here's some new functions from the C API

- [`rb_iv_set`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/variable.c#L4799)
sets an instance variable, in that case `@red`, `@green`, `@blue`, and `@alpha`.

- [`rb_iv_get`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/variable.c#L4788)
gets the instance variable from a ruby class.

- [`RB_NUM2UINT`](https://github.com/ruby/ruby/blob/d0b7e5b6a04bde21ca483d20a1546b28b401c2d4/include/ruby/internal/arithmetic/int.h#L185)
converts a Ruby [Numeric](https://docs.ruby-lang.org/en/master/Numeric.html) into a C `unsigned int`.

- [`rb_define_class_under`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/class.c#L1513)
creates a new class under the given superclass. In this example, it's going to be `Raylib::Color`.

- [`rb_define_method`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/class.c#L2638)
creates a new instance method for an object. In this case it's defining the `initialize` method.

- [`rb_define_attr`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/include/ruby/internal/method.h#L199)
defines either an `attr_reader`, or `attr_writer`, depending on the given flags. It's defining both in this
case.


```c
// ext/window/window.c

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

Most of the C API calls were already explained, so it's just wrapping Raylib API.
Here's the only new call:

- [`StringValueCStr`](https://github.com/ruby/ruby/blob/87d340f0e129ecf807e3be35d67fda1ad6f40389/include/ruby/internal/core/rstring.h#L89)
Creates a new C `NULL` terminated string from a Ruby string.

```ruby
# ext/window/extconf.rb

require 'mkmf'

append_ldflags %w[-lraylib -lGL -lm -lpthread -ldl -lrt -lX11]
have_header 'raylib.h'

create_makefile 'window/window'
```

We need to add some flags to the linker to be able to compile our raylib wrapper, and it's a good idea to
add a validator to check if we have access to the raylib library in our system.

Time to use our wrapped library:

```ruby
# window.rb

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

This should open up a window exactly as the
[example from raylib](https://www.raylib.com/examples/core/loader.html?name=core_basic_window).

## Wrapping Up

In this post, we've learned how to create native C Ruby extensions, from creating a brand new one, to
wrapping an already existing library in C. However, this technique should be only used when the solutions
in pure Ruby doesn't exists or it lacks the performance to do so, since it adds more complexity to
our projects. Here're some considerations:

1. **Complexity**: While C extensions can significaly boost performance, they also introduce complexity 
to the codebase and build systems by introducing another language.

2. **Memory Safety**: C code can lead to memory management issues, such as leaks or
segmentation faults. Consider using tools like [Valgind](https://valgrind.org/docs/manual/quick-start.html)
to identify memory issues.

3. **Cross-Platform Compatibility**: Be mindful of the differences on the target platforms when
compiling a C extension, like [musl](https://musl.libc.org) and [glibc](https://www.gnu.org/software/libc);
aarch64 and x86_64; linux, windows and macOS.

Some of those issues can be mitigated by using a [FFI gem](https://github.com/ffi/ffi) where it can
help in the case when multiple platforms are needed or lower the complexity in the codebase,
because you can write your extension purely in Ruby.

---

All source code used in this post is available on [GitHub](https://github.com/jm379/blog/tree/master/src/1-extending-ruby).
