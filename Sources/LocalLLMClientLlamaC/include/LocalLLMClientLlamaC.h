#pragma once

#ifndef __cplusplus
#error "LocalLLMClientC needs to be compiled in C++ interoperability mode."
#endif

#include "clip.h"
#include "ggml-alloc.h"
#include "ggml-backend.h"
#include "ggml-cpu.h"
#include "ggml-opt.h"
#include "ggml.h"
#include "gguf.h"
#include "llama.h"
#include "mtmd-helper.h"
#include "mtmd.h"

#include "utils.h"

#include "../common/chat.h"
