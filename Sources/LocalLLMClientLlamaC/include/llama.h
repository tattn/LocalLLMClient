#define LLAVA_LOG_OFF
#if __has_include(<llama/llama.h>)
#include <llama/llama.h>
#else
// For DocC
#include "../exclude/llama.cpp/include/llama.h"
#endif
