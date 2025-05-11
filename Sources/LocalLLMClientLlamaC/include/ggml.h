#if __has_include(<llama/ggml.h>)
#include <llama/ggml.h>
#else
// For DocC
#include "../exclude/llama.cpp/ggml/include/ggml.h"
#endif
