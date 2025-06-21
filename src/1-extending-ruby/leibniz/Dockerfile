FROM ruby:3.4.3-alpine
WORKDIR /app
RUN apk --no-cache add build-base
COPY . .
RUN ruby ./ext/leibniz/extconf.rb && \
  make

CMD ["ruby", "leibniz.rb"]
