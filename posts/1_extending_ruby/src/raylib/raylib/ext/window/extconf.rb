require 'mkmf'

with_ldflags "-lraylib -lGL -lm -lpthread -ldl -lrt -lX11" do true end

create_makefile 'window/window'
