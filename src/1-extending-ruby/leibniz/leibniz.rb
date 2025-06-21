#!/usr/bin/env ruby

require_relative 'leibniz.so'

puts Leibniz.calc(100_000_000).class
