#if __has_include(<llama/gguf.h>)
#include <llama/gguf.h>
#else
// For DocC
#include "../exclude/llama.cpp/ggml/include/gguf.h"
#endif
