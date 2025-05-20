FROM ruby:3.4.3-alpine3.21
WORKDIR /app
COPY . .
RUN apk --no-cache add build-base && \
  ruby ./ext/sum/extconf.rb && \
  make
CMD ["ruby", "sum.rb"]
