# Raylib

This the source code for the Raylib example.

## Running

There are two ways to run the code, via Docker or with Ruby.

#### With Ruby

```shell
$ ./window.rb
```

#### With Docker

First, build the image

```shell
$ docker build -t ruby_raylib .
```

To run it with Hardware Acceleration:

```shell
$ docker run --rm \
-e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix \
--device /dev/dri:/dev/dri \
ruby_raylib
```

To run with Software Rendering:

```shell
docker run --rm \
-e DISPLAY=$DISPLAY \
-e LIBGL_ALWAYS_SOFTWARE=1 \
-v /tmp/.X11-unix:/tmp/.X11-unix \
ruby_raylib
```
