require 'mkmf'

append_cflags %w[-O3 -march=native]

create_makefile 'leibniz/leibniz'
