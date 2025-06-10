require 'mkmf'

append_cflags %w[-mavx2 -mfma]
have_macro '__AVX2__'
have_header 'immintrin.h'

create_makefile 'leibniz/leibniz'
