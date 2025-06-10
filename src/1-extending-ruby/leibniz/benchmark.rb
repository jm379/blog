#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark/ips'
require_relative 'ext/leibniz/leibniz'

ROUNDS = 100_000_000

RubyVM::YJIT.enable

Benchmark.ips do
  it.report(:c) { Leibniz::C.calc ROUNDS }
  it.report(:simd) { Leibniz::SIMD.calc ROUNDS }
  it.report(:ruby) { Leibniz::Ruby.calc ROUNDS }

  it.compare!
end
