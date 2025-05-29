require 'mkmf'

append_cflags %w[-O3 -march=native]
have_macro '__AVX2__'
have_header 'immintrin.h'

create_makefile 'leibniz/leibniz'
