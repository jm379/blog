require 'mkmf'

with_ldflags("-lraylib -lGL -lm -lpthread -ldl -lrt -lX11") { true }

create_makefile 'window/window'
