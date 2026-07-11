#include <string>
#include <unordered_map>

namespace {

static const std::unordered_map<int32_t, std::string> g_errorMessages = {
  {  0, "OK" },
  { -1, "Initialization failed" },
  { -2, "Camera operation failed" },
  { -3, "Tile operation failed" },
  { -4, "Memory allocation failed" },
  { -5, "Pick/raycast failed" },
  { -6, "Engine not ready" },
  { -100, "Fatal internal error" },
};

} // namespace
