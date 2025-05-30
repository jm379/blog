#include <immintrin.h>

double normal(size_t n) {
  double pi = 0.0;
  double signal = -1.0;

  for(unsigned int i = 0; i < n; ++i) {
    signal = -signal;
    pi += signal / (2 * i + 1);
  }

  return pi * 4.0;
}

double simd(size_t n) {
  double pi = 0.0;

  __m256d signal_vector = _mm256_set_pd(1.0, -1.0, 1.0, -1.0);
  __m256d one_vector = _mm256_set1_pd(1.0);
  __m256d two_vector = _mm256_set1_pd(2.0);
  __m256d four_vector = _mm256_set1_pd(4.0);
  __m256d result_vector = _mm256_setzero_pd();
  __m256d sum_vector = _mm256_setzero_pd();
  __m256d idx_vector = _mm256_set_pd(0.0, 1.0, 2.0, 3.0);

  for(unsigned int i = 0; i < n; i += 4) {
    sum_vector = _mm256_fmadd_pd(two_vector, idx_vector, one_vector);
    sum_vector = _mm256_div_pd(signal_vector, sum_vector);

    result_vector = _mm256_add_pd(result_vector, sum_vector);
    idx_vector = _mm256_add_pd(idx_vector, four_vector);
  }

  pi += result_vector[0] +
        result_vector[1] +
        result_vector[2] +
        result_vector[3];
  return pi * 4.0;
}
