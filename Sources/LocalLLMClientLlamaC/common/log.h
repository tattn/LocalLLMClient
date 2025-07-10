#include "ggml.h"

#define LOG_WRN(...)
#define LOG_ERR(...)
#define LOG_DBG(...)
#define LOG_INF(...)

#define LOG_DEFAULT_LLAMA 0

void common_log_set_verbosity_thold(int verbosity);
extern int common_log_verbosity_thold;

struct common_log;

struct common_log * common_log_init();
struct common_log * common_log_main();
void common_log_add(struct common_log * log, enum ggml_log_level level, const char * fmt, ...);
