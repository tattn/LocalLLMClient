// This header is used in DocC builds.
#if __has_include(<llama/ggml-opt.h>)
#include <llama/ggml-opt.h>
#else
// For DocC
#include "../exclude/llama.cpp/ggml/include/ggml-opt.h"
#endif
