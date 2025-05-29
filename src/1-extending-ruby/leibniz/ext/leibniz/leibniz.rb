require 'ffi'

module Leibniz
  module C
    extend FFI::Library
    ffi_lib './leibniz.so'

    attach_function :calc, :normal, [:size_t], :double
  end

  module SIMD
    extend FFI::Library
    ffi_lib './leibniz.so'

    attach_function :calc, :simd, [:size_t], :double
  end

  module Ruby
    def self.calc(n)
      sig = -1.0
      pi = 0.0

      n.times do
        sig = -sig
        pi += sig / (2 * it + 1)
      end

      pi * 4
    end
  end
end
