# Leibniz

This the source code for the leibniz example.

## Running

There are two ways to run the code, via Docker or with Ruby.

#### With Ruby

```shell
$ ./leibniz.rb
```

#### With Docker

First, build the image:

```shell
$ docker build -t ruby_leibniz .
```

To run it:

```shell
$ docker run --rm ruby_leibniz
```
