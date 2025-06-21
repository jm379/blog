require 'mkmf'

append_ldflags %w[-lraylib -lGL -lm -lpthread -ldl -lrt -lX11]
have_header 'raylib.h'

create_makefile 'window/window'
