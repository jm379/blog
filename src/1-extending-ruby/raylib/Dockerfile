FROM ruby:3.4.3-alpine
WORKDIR /app
RUN apk --no-cache add \
  build-base \
  git \
  libx11-dev \
  libxcursor-dev \
  libxrandr-dev \
  libxinerama-dev \
  libxkbcommon-dev \
  libxi-dev \
  mesa-dev && \
  git clone --depth 1 https://github.com/raysan5/raylib.git raylib && \
  cd raylib/src && \
  make PLATFORM=PLATFORM_DESKTOP RAYLIB_LIBTYPE=SHARED && \
  make install RAYLIB_LIBTYPE=SHARED

COPY . .
RUN ruby ./ext/window/extconf.rb && \
  make
CMD ["ruby", "window.rb"]
