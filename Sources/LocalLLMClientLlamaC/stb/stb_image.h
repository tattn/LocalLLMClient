#ifdef __linux__
#include "../exclude/llama.cpp/vendor/stb/stb_image.h"
#else
// Implemented by stb_image.swift

#ifdef __cplusplus
extern "C" {
#endif

extern const unsigned char *stbi_load(char const *filename, int *x, int *y,
                                      int *comp, int req_comp);
extern void stbi_image_free(const unsigned char *retval_from_stbi_load);
extern const unsigned char *stbi_load_from_memory(void const *buffer,
                                                  size_t len, int *x, int *y,
                                                  int *comp, int req_comp);

#ifdef __cplusplus
}
#endif

#endif // __linux__
