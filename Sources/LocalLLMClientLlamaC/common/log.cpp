#include "ggml.h"

int common_log_verbosity_thold = 0;

struct common_log * common_log_main() { return nullptr; }
void common_log_add(struct common_log * log, enum ggml_log_level level, const char * fmt, ...) {}
