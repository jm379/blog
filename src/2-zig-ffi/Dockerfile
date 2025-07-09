FROM ruby:3.4.4-alpine3.22
WORKDIR /app
COPY . .
RUN apk add --no-cache zig && \
  cd ext/inotify && \
  zig build -p ./ -Doptimize=ReleaseFast
