#include <cstdlib>
#include <cstring>
#include <new>

extern "C" {

void* bridge_alloc(int32_t size_bytes) {
  return std::malloc(static_cast<size_t>(size_bytes));
}

void bridge_free(void* ptr) {
  std::free(ptr);
}

int32_t bridge_get_total_allocated() {
  return 0;
}

} // extern "C"
