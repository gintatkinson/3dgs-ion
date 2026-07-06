#include <string>
#include <unordered_map>
#include <mutex>

namespace {

static std::unordered_map<int32_t, std::string> g_errorMessages = {
  {  0, "OK" },
  { -1, "Initialization failed" },
  { -2, "Camera operation failed" },
  { -3, "Tile operation failed" },
  { -4, "Memory allocation failed" },
  { -5, "Pick/raycast failed" },
  { -6, "Engine not ready" },
  { -100, "Fatal internal error" },
};

static std::mutex g_errorMutex;

} // namespace

extern "C" {

const char* bridge_error_message(int32_t error_code) {
  std::lock_guard<std::mutex> lock(g_errorMutex);
  auto it = g_errorMessages.find(error_code);
  if (it != g_errorMessages.end()) {
    return it->second.c_str();
  }
  return "Unknown error";
}

} // extern "C"
