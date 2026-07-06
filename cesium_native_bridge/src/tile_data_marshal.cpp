/* Tile data marshal utilities used by bridge.cpp
 *
 * FFI MEMORY CONTRACT for tile data:
 * - The native bridge owns the tile data buffer.
 * - The buffer is valid only during the bridge_tile_ready_callback_t invocation.
 * - The Dart/Flutter caller MUST copy the data if persistence beyond the
 *   callback is needed. The buffer MUST NOT be freed or modified by the caller.
 * - After the callback returns, the buffer may be deallocated by the bridge.
 * - bridge_free_string() is for bridge_get_visible_tile_id() string results ONLY,
 *   not for tile data buffers passed through the tile_ready callback.
 */
