#include "build-info.h"

#ifndef LLAMA_BUILD_NUMBER
#define LLAMA_BUILD_NUMBER 0
#endif

#define LLAMA_BUILD_INFO_STRINGIFY_(x) #x
#define LLAMA_BUILD_INFO_STRINGIFY(x) LLAMA_BUILD_INFO_STRINGIFY_(x)

int llama_build_number(void) { return LLAMA_BUILD_NUMBER; }
const char * llama_commit(void) { return ""; }
const char * llama_compiler(void) { return ""; }
const char * llama_build_target(void) { return ""; }
const char * llama_build_info(void) { return "b" LLAMA_BUILD_INFO_STRINGIFY(LLAMA_BUILD_NUMBER); }
