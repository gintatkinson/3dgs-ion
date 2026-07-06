# Code Review: C++ Bridge Native Library

This document provides a comprehensive code review of the C++ bridge native library files located in `cesium_native_bridge/`.

---

## 1. Memory Safety

### 🔴 Critical: Use-After-Free / Dangling Pointer in `bridge_get_last_error`
- **Tracking Issue**: [GitHub Issue #74](https://github.com/gintatkinson/3dgs-002/issues/74)
- **Severity**: 🔴 Critical
- **Location**: [`cesium_native_bridge/src/bridge.cpp:56-61`](file:///Users/perkunas/jail/3dgs-002/cesium_native_bridge/src/bridge.cpp#L56-L61)
- **Issue**: The function returns a `const char*` pointing to the internal character buffer of the `std::string` inside the `BridgeState` object (`it->second->lastError.c_str()`). As soon as the function returns, `g_statesMutex` is unlocked and the lock is released. If another thread modifies `lastError` or destroys the `BridgeState` object by calling `bridge_shutdown`, the returned pointer immediately becomes a dangling pointer. Reading from this memory on the Dart FFI side will cause a Use-After-Free (UAF) bug, data corruption, or application crash.
- **Suggestion**: Do not return pointers to transient internal state. Instead, use one of the following approaches:
  1. **Caller-allocated buffer (Highly Recommended)**: Have the Dart caller allocate a buffer and pass it along with its capacity. The native side copies the string safely into that buffer.
  2. **Library-allocated string**: Return a copied string allocated via `strdup` or a custom allocator, and make the Dart wrapper responsible for freeing it via `bridge_free_string`.
- **Example (Approach 1 - Caller-allocated buffer)**:
```diff
-const char* bridge_get_last_error(bridge_handle_t handle) {
-  std::lock_guard<std::mutex> lock(g_statesMutex);
-  auto it = g_states.find(handle);
-  if (it == g_states.end()) return "Invalid handle";
-  return it->second->lastError.c_str();
-}
+int32_t bridge_get_last_error(bridge_handle_t handle, char* out_buffer, int32_t buffer_size) {
+  if (!out_buffer || buffer_size <= 0) return BRIDGE_ERR_MEMORY;
+  std::lock_guard<std::mutex> lock(g_statesMutex);
+  auto it = g_states.find(handle);
+  if (it == g_states.end()) {
+    std::strncpy(out_buffer, "Invalid handle", buffer_size - 1);
+    out_buffer[buffer_size - 1] = '\0';
+    return BRIDGE_ERR_INIT;
+  }
+  std::strncpy(out_buffer, it->second->lastError.c_str(), buffer_size - 1);
+  out_buffer[buffer_size - 1] = '\0';
+  return BRIDGE_OK;
+}
```

### 🔴 Critical: Silently Discarded Config & Potential Use-After-Free
- **Tracking Issue**: [GitHub Issue #75](https://github.com/gintatkinson/3dgs-002/issues/75)
- **Severity**: 🔴 Critical
- **Location**: `cesium_native_bridge/src/bridge.cpp:28-44`
- **Issue**: `bridge_initialize` takes config pointer but never stores config values or copies config layout to internal state map entries. If the caller assumes config variables are persisted in native bridge context, freeing configurations immediately after initialization (as done in `cesium_engine.dart`) will leave the FFI references invalid and cause crash.
- **Suggestion**: Copy the tileset configuration data layout structures into state on native side initialization.

### 🟠 Important: Signed Size Integer Wrap-around in `bridge_alloc`
- **Tracking Issue**: [GitHub Issue #77](https://github.com/gintatkinson/3dgs-002/issues/77)
- **Severity**: 🟠 Important
- **Location**: [`cesium_native_bridge/src/resource_manager.cpp:7-9`](file:///Users/perkunas/jail/3dgs-002/cesium_native_bridge/src/resource_manager.cpp#L7-L9)
- **Issue**: `bridge_alloc(int32_t size_bytes)` accepts a signed 32-bit integer. It casts it directly to `size_t` (which is unsigned 64-bit on mac/64-bit targets) for `malloc`. If Dart calls `bridge_alloc` with a negative number, the static cast wraps it around to a massive positive number (e.g., `-1` becomes `18446744073709551615`), leading to failed allocations or undefined memory manager behavior.
- **Suggestion**: Check for non-positive values before casting, or modify the signature to accept an unsigned size type (e.g., `uint32_t`).
- **Example**:
```diff
 void* bridge_alloc(int32_t size_bytes) {
-  return std::malloc(static_cast<size_t>(size_bytes));
+  if (size_bytes <= 0) return nullptr;
+  return std::malloc(static_cast<size_t>(size_bytes));
 }
```

---

## 2. Thread Safety and Concurrency

### 🟠 Important: Lifetime Race on Deallocating Active `BridgeState`
- **Tracking Issue**: [GitHub Issue #93](docs/reviews/review_cpp_bridge.md)
- **Location**: [`cesium_native_bridge/src/bridge.cpp:46-49`](file:///Users/perkunas/jail/3dgs-002/cesium_native_bridge/src/bridge.cpp#L46-L49)
- **Issue**: `bridge_shutdown` deletes the `BridgeState` map entry under lock. However, if background worker threads (like those spawned by cesium-native's `CesiumAsync` operations) or callback dispatches are still active, they might attempt to reference `BridgeState` members (like callbacks or user data pointers) after they have been deleted.
- **Suggestion**: Manage `BridgeState` using `std::shared_ptr` rather than `std::unique_ptr`, and ensure that active tasks hold a reference to keep the state alive. Furthermore, implement an explicit cancellation/join step during shutdown to block until all pending worker threads have stopped.
- **Example**:
```diff
-std::unordered_map<bridge_handle_t, std::unique_ptr<BridgeState>> g_states;
+std::unordered_map<bridge_handle_t, std::shared_ptr<BridgeState>> g_states;
```

---

## 3. Error Handling and Exception Boundaries

### 🔴 Critical: C++ Exception Propagation causing Dart VM Aborts
- **Tracking Issue**: [GitHub Issue #76](https://github.com/gintatkinson/3dgs-002/issues/76)
- **Severity**: 🔴 Critical
- **Location**: [`cesium_native_bridge/src/bridge.cpp:28-44`](file:///Users/perkunas/jail/3dgs-002/cesium_native_bridge/src/bridge.cpp#L28-L44)
- **Issue**: Functions like `bridge_initialize` allocate heap memory using `std::make_unique` and insert items into `std::unordered_map`. If these operations run out of memory, they throw `std::bad_alloc`. If a C++ exception crosses the `extern "C"` FFI boundary, the Dart VM cannot catch it and will abort the entire process instantly.
- **Suggestion**: Wrap all C++ FFI entry points in a generic `try-catch` block catching `std::exception` and `...` to intercept exceptions and map them to error codes.
- **Example**:
```diff
 bridge_handle_t bridge_initialize(
     const bridge_tileset_config_t* config,
     bridge_error_callback_t on_error,
     void* user_data) {
-
   if (!config) return BRIDGE_ERR_INIT;
 
-  std::lock_guard<std::mutex> lock(g_statesMutex);
-  bridge_handle_t handle = g_nextHandle++;
-
-  auto state = std::make_unique<BridgeState>();
-  state->errorCallback = on_error;
-  state->errorUserData = user_data;
-
-  g_states[handle] = std::move(state);
-  return handle;
+  try {
+    std::lock_guard<std::mutex> lock(g_statesMutex);
+    bridge_handle_t handle = g_nextHandle++;
+
+    auto state = std::make_unique<BridgeState>();
+    state->errorCallback = on_error;
+    state->errorUserData = user_data;
+
+    g_states[handle] = std::move(state);
+    return handle;
+  } catch (const std::exception&) {
+    return BRIDGE_ERR_MEMORY;
+  } catch (...) {
+    return BRIDGE_ERR_FATAL;
+  }
 }
```

### 🟠 Important: Assertion Failures inside `cesium-native` on Invalid Coordinates
- **Tracking Issue**: [GitHub Issue #94](docs/reviews/review_cpp_bridge.md)
- **Location**: [`cesium_native_bridge/src/bridge.cpp:99-124`](file:///Users/perkunas/jail/3dgs-002/cesium_native_bridge/src/bridge.cpp#L99-L124)
- **Issue**: `bridge_cartographic_to_ecef` delegates directly to `CesiumGeospatial::Cartographic::fromDegrees` and `ellipsoid.cartographicToCartesian`. If the input latitude is out of bounds (not in `[-90, 90]`) or is NaN/Infinity, `cesium-native` or `glm` may trigger `assert()` statements. In C/C++, failed assertions do not throw catchable C++ exceptions; they write to stderr and call `abort()`, crashing the Dart VM.
- **Suggestion**: Pre-validate coordinates on the C++ side before calling `cesium-native` classes.
- **Example**:
```diff
 int32_t bridge_cartographic_to_ecef(
     double lat_deg,
     double lng_deg,
     double alt_m,
     double* out_x,
     double* out_y,
     double* out_z) {
   if (!out_x || !out_y || !out_z) return BRIDGE_ERR_CAMERA;
 
+  // Pre-validate numeric boundaries
+  if (std::isnan(lat_deg) || std::isinf(lat_deg) ||
+      std::isnan(lng_deg) || std::isinf(lng_deg) ||
+      std::isnan(alt_m) || std::isinf(alt_m)) {
+    return BRIDGE_ERR_CAMERA;
+  }
+  if (lat_deg < -90.0 || lat_deg > 90.0) {
+    return BRIDGE_ERR_CAMERA;
+  }
+
   try {
     const CesiumGeospatial::Ellipsoid& ellipsoid = CesiumGeospatial::Ellipsoid::WGS84;
```
