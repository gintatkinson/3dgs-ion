# Cesium-Native 3D Geospatial Architecture & Implementation Plan

**Version:** 1.0
**Date:** 2026-07-04
**Author:** Engineering

---

## 1. Executive Summary

This document defines the architecture for a native, GPU-accelerated 3D geospatial visualization engine integrating the `cesium-native` C++ library into the Flutter desktop application via Dart FFI bindings and Impeller GPU rendering. The system renders photorealistic 3D globes with terrain, satellite imagery, geospatial profile entities, paths/vectors, labels, and interactive camera controls — matching and exceeding the capabilities of the reference Cognition-UI-tsx application while eliminating the JavaScript/WebView dependency entirely.

### Design Objectives

| Objective | Target |
|---|---|
| Rendering fidelity | Photorealistic globe with Cesium World Terrain + multi-source imagery |
| Latency | Camera-to-frame < 16ms (60fps) |
| Entity scale | 100,000+ entities, 500,000+ paths |
| Memory footprint | < 500MB for globe + tile cache |
| FFI overhead | < 1ms per frame for camera/tile exchange |
| Platform support | macOS (primary), Linux, Windows |
| Test coverage | ≥ 85% line coverage, 100% FFI error path coverage |

---

## 2. Architecture Overview

The system follows a five-layer architecture with strict separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 5: Flutter UI (Widgets, HUD, Config Panel)           │
│  - TopographicalView, Scene3DViewport, CameraHUD,           │
│    MapConfigPanel, VisibilityToggles                         │
├─────────────────────────────────────────────────────────────┤
│  Layer 4: Domain / Scene Graph (Dart)                       │
│  - GlobeSceneController, CameraController,                  │
│    GeospatialRenderer, MapStyleManager, EntityManager         │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: FFI Bridge (Dart + C)                             │
│  - CesiumNativeBridge (Dart FFI), TileDataMarshal (C),      │
│    CameraMarshal, ResourceManager, ErrorPropagator          │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: GPU Rendering (Impeller / flutter_gpu)            │
│  - GlobeMeshRenderer, TerrainTileRenderer,                  │
│    EntitySpriteRenderer, PathPolylineRenderer,              │
│    AtmosphereShader, LabelRenderer                          │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: C++ Native (cesium-native)                        │
│  - TilesetLoader, TerrainProvider, ImageryProvider,         │
│    SpatialIndex, CameraCuller, CoordinateTransform          │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Input (Drag/Scroll/Tap)
        │
        ▼
CameraController ──► Camera state update
        │
        ▼
CesiumNativeBridge.updateViewport(camera)
        │  [FFI boundary]
        ▼
cesium-native Culling Engine
  ├── SpatialIndex query
  ├── Terrain tile selection
  └── Imagery tile selection
        │
        ▼  [FFI boundary — tile metadata return]
        TileDataMarshal ──► TileLoadQueue
        │
        ├──► Isolate 1: Async tile fetch (HTTP/models)
        ├──► Isolate 2: GPU texture upload
        └──► Isolate 3: Mesh/LoD preparation
        │
        ▼
Impeller Render Pass
  ├── Globe sphere + terrain elevation
  ├── Imagery layer texturing
  ├── Geospatial entity sprites
  ├── Polyline paths/vectors (geodesic/straight)
  ├── Label billboards
  └── Atmosphere/starfield
        │
        ▼
Display (60fps)
```

---

## 3. Cesium-Native Integration Strategy

### 3.1 Library Selection & Compilation

The `cesium-native` repository (https://github.com/CesiumGS/cesium-native) provides the core C++ libraries:

| Library | Purpose |
|---|---|
| `Cesium3DTilesSelection` | 3D Tiles spatial indexing, view-based culling, LoD selection |
| `CesiumGeospatial` | Ellipsoid, Cartographic, Cartesian coordinate math |
| `CesiumAsync` | Thread pool, async task scheduling, futures |
| `CesiumUtility` | JSON parsing, logging, memory utilities |

**Build Configuration:**

```cmake
# cesium_native_bridge/CMakeLists.txt
cmake_minimum_required(VERSION 3.20)
project(cesium_native_bridge VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# cesium-native as submodule
add_subdirectory(third_party/cesium-native)

# Bridge library exposing C ABI
add_library(cesium_native_bridge SHARED
  src/bridge.cpp
  src/camera_marshal.cpp
  src/tile_data_marshal.cpp
  src/resource_manager.cpp
  src/error_propagator.cpp
)

target_link_libraries(cesium_native_bridge PRIVATE
  Cesium3DTilesSelection
  CesiumGeospatial
  CesiumAsync
)

# Platform-specific output
if(APPLE)
  set_target_properties(cesium_native_bridge PROPERTIES
    SUFFIX ".dylib"
    INSTALL_RPATH "@executable_path/../Frameworks"
  )
endif()
```

### 3.2 C ABI Functions Exposed

```c
// bridge.h — C-compatible ABI, callable from Dart FFI

typedef void (*TileReadyCallback)(const char* tileId, const uint8_t* data, int32_t size, void* userData);
typedef void (*CameraChangedCallback)(double lat, double lng, double alt, double pitch, double heading, void* userData);
typedef void (*ErrorCallback)(int32_t errorCode, const char* message, void* userData);

typedef struct {
  double latitude;
  double longitude;
  double altitude;
  double heading;
  double pitch;
  double roll;
} CameraState;

typedef struct {
  const char* tilesetUrl;
  const char* terrainProvider;   // "cesium-world" | "ellipsoid" | "arcgis"
  const char* imageryProvider;   // "openstreetmap" | "arcgis-satellite" | "carto-dark" | "carto-light"
  int32_t maxSimultaneousTileLoads;
  int32_t maxCachedBytes;
} TilesetConfig;

// Lifecycle
int32_t bridge_initialize(TilesetConfig* config, ErrorCallback onError, void* userData);
void    bridge_shutdown(int32_t handle);
int32_t bridge_is_ready(int32_t handle);

// Camera
int32_t bridge_update_camera(int32_t handle, CameraState* camera);
int32_t bridge_register_camera_callback(int32_t handle, CameraChangedCallback callback, void* userData);

// Tile retrieval
int32_t bridge_get_visible_tiles(int32_t handle, char*** outTileIds, int32_t* outCount);
int32_t bridge_request_tile_data(int32_t handle, const char* tileId, TileReadyCallback callback, void* userData);
void    bridge_free_tile_list(char** tileIds, int32_t count);

// Terrain / Imagery
int32_t bridge_set_terrain_provider(int32_t handle, const char* providerName);
int32_t bridge_set_imagery_provider(int32_t handle, const char* providerName);
int32_t bridge_set_imagery_blend(int32_t handle, float alpha);

// Coordinate transforms
int32_t bridge_cartographic_to_ecef(double lat, double lng, double alt, double* outX, double* outY, double* outZ);
int32_t bridge_ecef_to_screen(double x, double y, double z, CameraState* camera, int32_t viewportW, int32_t viewportH, double* outScreenX, double* outScreenY);

// Geospatial Entity & Path management
int32_t bridge_add_entity(int32_t handle, double lat, double lng, double alt, const char* entityId, const char* label, int32_t colorRgba);
int32_t bridge_remove_entity(int32_t handle, const char* entityId);
int32_t bridge_add_link(int32_t handle, const char* sourceId, const char* targetId, int32_t colorRgba, float width);
int32_t bridge_remove_link(int32_t handle, const char* linkId);
int32_t bridge_screen_pick(int32_t handle, double screenX, double screenY, char** outEntityId);
```

---

## 4. Dart FFI Bridge Design

### 4.1 Native Binding Layer

```dart
// lib/domain/cesium_3d/native/bridge_bindings.dart
// Auto-generated by ffigen from bridge.h

import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef BridgeInitializeNative = Int32 Function(
  Pointer<TilesetConfigNative> config,
  Pointer<NativeFunction<ErrorCallbackNative>> onError,
  Pointer<Void> userData,
);
typedef BridgeInitializeDart = int Function(
  Pointer<TilesetConfigNative> config,
  Pointer<NativeFunction<ErrorCallbackNative>> onError,
  Pointer<Void> userData,
);

// Camera struct (matches C ABI exactly)
final class CameraStateNative extends Struct {
  @Double()
  external double latitude;

  @Double()
  external double longitude;

  @Double()
  external double altitude;

  @Double()
  external double heading;

  @Double()
  external double pitch;

  @Double()
  external double roll;
}

// ... remaining structs and function typedefs
```

### 4.2 High-Level Dart Wrapper

```dart
// lib/domain/cesium_3d/cesium_engine.dart

class CesiumEngine {
  final DynamicLibrary _nativeLib;
  final int _handle;
  final Map<String, NativeResource> _resources = {};
  final StreamController<CameraUpdate> _cameraStream = StreamController.broadcast();

  CesiumEngine._(this._nativeLib, this._handle);

  static Future<CesiumEngine> initialize({
    required String tilesetUrl,
    String terrainProvider = 'cesium-world',
    String imageryProvider = 'carto-dark',
  }) async {
    final lib = _loadLibrary();
    final config = _buildConfig(tilesetUrl, terrainProvider, imageryProvider);
    final handle = lib.initialize(config);
    if (handle < 0) throw CesiumInitializationException(_lastError(lib));
    return CesiumEngine._(lib, handle);
  }

  /// Updates the virtual camera. Called every frame at 60fps.
  /// Must complete in < 1ms; off-loads tile computation to background threads.
  void updateCamera(VirtualCamera camera) {
    final native = camera.toNative();
    final result = _nativeLib.updateCamera(_handle, native);
    _checkError(result);
    // Camera callback fires asynchronously with actual view state
  }

  /// Returns list of currently visible tile IDs. Use to determine
  /// which tiles to load and render this frame.
  List<String> getVisibleTiles() {
    // FFI call: allocates char** array in C, copies to Dart, frees C memory
    final tiles = _nativeLib.getVisibleTiles(_handle);
    return tiles.toList(); // Resource guarded with NativeFinalizer
  }

  /// Requests tile data; callback fires when tile is ready.
  void requestTileData(String tileId, void Function(Uint8List data) onReady) {
    final callback = Pointer.fromFunction<TileReadyCallbackNative>(...);
    _nativeLib.requestTileData(_handle, tileId, callback);
  }

  /// Transforms geodetic coordinates to screen-space for entity placement.
  Offset? cartographicToScreen(double lat, double lng, double alt, Size viewportSize) {
    final camera = _currentCamera.toNative(); // stored from last updateCamera callback
    // ECEF intermediate → screen projection via cesium-native
    final result = _nativeLib.ecefToScreen(...);
    if (result < 0) return null; // behind camera
    return Offset(screenX, screenY);
  }

  /// Raycast: returns entity at screen position, or null.
  String? pickEntityAtScreen(double x, double y) {
    return _nativeLib.screenPick(_handle, x, y);
  }

  void dispose() {
    _cameraStream.close();
    _nativeLib.shutdown(_handle);
    for (final res in _resources.values) { res.release(); }
  }

  static DynamicLibrary _loadLibrary() {
    if (Platform.isMacOS) {
      return DynamicLibrary.open('cesium_native_bridge.dylib');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libcesium_native_bridge.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('cesium_native_bridge.dll');
    }
    throw UnsupportedError('Unsupported platform');
  }
}
```

### 4.3 Resource Management (RAII Pattern in Dart)

```dart
// lib/domain/cesium_3d/native/native_resource.dart

/// Wraps native heap allocations with deterministic cleanup.
/// Uses NativeFinalizer to guarantee C free() even if Dart GC misses.
final class NativeResource<T extends NativeType> {
  final Pointer<T> pointer;
  final int sizeBytes;

  NativeResource._(this.pointer, this.sizeBytes) {
    _finalizer.attach(this, pointer, detach: this, size: sizeBytes);
  }

  factory NativeResource.alloc(int count, int elementSize) {
    final ptr = calloc<Int8>(count * elementSize);
    return NativeResource._(ptr, count * elementSize);
  }

  void release() {
    _finalizer.detach(this);
    calloc.free(pointer);
  }
}

final _finalizer = NativeFinalizer(calloc.nativeFree);
```

### 4.4 Error Propagation Strategy

All C ABI functions return `int32_t` status codes. The bridge layer maps these to typed Dart exceptions:

| C Status | Dart Exception | Recovery |
|---|---|---|
| 0 | (success) | — |
| -1 | `CesiumInitializationException` | Fatal — cannot continue |
| -2 | `CesiumCameraException` | Clamp camera to valid range |
| -3 | `CesiumTileException` | Skip tile, retry next frame |
| -4 | `CesiumMemoryException` | Purge tile cache, retry |
| -5 | `CesiumPickException` | Return null (no hit) |
| -100 | `CesiumFatalException` | Engine restart required |

---

## 5. GPU Rendering Pipeline (Impeller)

### 5.1 Render Pass Architecture

```
Pass 0: Clear (background color)
Pass 1: Starfield (GPU instanced quads, 1000+ stars)
Pass 2: Atmosphere (full-screen quad, Rayleigh scattering shader)
Pass 3: Globe Sphere (tessellated icosphere, vertex-displaced by terrain)
  ├── Subpass 3a: Terrain elevation (vertex shader heightmap lookup)
  ├── Subpass 3b: Imagery texturing (fragment shader tile atlas sampling)
  └── Subpass 3c: Grid overlay (meridians/parallels, thin line geometry)
Pass 4: Geospatial Entities (GPU instanced sprite rendering)
  ├── Subpass 4a: Surface-anchored entities (style/color/depth-tested from profile)
  ├── Subpass 4b: Elevated/airborne entities (altitude/orbit offset geometry from profile)
  ├── Subpass 4c: Sub-surface entities (clamped/underwater visual styling from profile)
  └── Subpass 4d: Entity labels (billboard text, SDF font atlas)
Pass 5: Geospatial Paths & Vectors (polyline geometry, camera-facing)
  ├── Subpass 5a: Surface paths (CLAMP_TO_GROUND, geodesic arcs dynamic styling)
  ├── Subpass 5b: Spatial straight vectors (NONE arc, straight line dynamic styling)
  ├── Subpass 5c: Dynamic styled paths (animated dash/color pattern from profile metadata)
  └── Subpass 5d: Vertical projection drops (dynamic dashed lines, elevated → surface)
Pass 6: Post-Processing
  ├── Subpass 6a: FXAA anti-aliasing
  └── Subpass 6b: HUD overlay (Flutter composited, not GPU)
```

### 5.2 Globe Mesh Architecture

The globe is rendered as a tessellated icosahedron (level 6 = 40,962 vertices) with vertex displacement:

```glsl
// globe_vertex.glsl — Impeller vertex shader
#version 460

layout(location = 0) in vec3 aPosition;     // unit sphere position
layout(location = 1) in vec2 aTexCoord;      // lat/long UV for imagery

layout(set = 0, binding = 0) uniform GlobeUniforms {
    mat4 uModelViewProjection;
    vec4 uCameraPosition;     // ECEF
    float uTerrainEnabled;
    float uGlobeRadius;
} uniforms;

layout(set = 0, binding = 1) uniform sampler2D uTerrainHeightmap;

out vec2 vTexCoord;
out vec3 vWorldNormal;
out float vHeight;

void main() {
    vec3 spherePos = aPosition * uniforms.uGlobeRadius;

    float elevation = 0.0;
    if (uniforms.uTerrainEnabled > 0.5) {
        // Sample cesium-native terrain tile atlas
        elevation = texture(uTerrainHeightmap, aTexCoord).r * 10000.0;
    }

    vec3 displacedPos = spherePos + normalize(spherePos) * elevation;

    // Frustum and horizon culling performed by cesium-native;
    // we render only visible tiles.
    gl_Position = uniforms.uModelViewProjection * vec4(displacedPos, 1.0);

    vTexCoord = aTexCoord;
    vWorldNormal = normalize(displacedPos);
    vHeight = elevation;
}
```

### 5.3 Imagery Tile Atlas

Multiple tile providers are composited into a single GPU texture atlas:

```
Tile Atlas Layout (8192×8192 RGBA8 texture):
┌────────────────────────────────────────┐
│ T0  T1  T2  T3      ...    T31        │  Row 0: zoom level N visible tiles
│ T32 T33 ...                            │  Row 1
│ ...                                    │
│ T992 ...                       T1023   │  Row 31
└────────────────────────────────────────┘

Tile update: LRU cache, replace least-recently-visible tile slot.
Tile fetch: Off-thread via Dart Isolate + HTTP; upload via transfer queue.
```

### 5.4 Entity Sprite Renderer (Instanced Rendering)

Geospatial entities are rendered as GPU-instanced camera-facing sprites:

```dart
// lib/domain/cesium_3d/renderers/entity_renderer.dart

class EntityRenderer {
  // Single draw call renders ALL entities via instancing
  void renderEntityBatch(
    RenderPass pass,
    List<EntityInstance> instances, // 10k+ per frame
  ) {
    // Instance buffer: [x, y, z, colorR, colorG, colorB, colorA, size, entityId]
    final instanceBuffer = _gpuContext.createBuffer(
      size: instances.length * _bytesPerInstance,
      usage: BufferUsage.storage | BufferUsage.vertex,
    );
    _uploadInstances(instanceBuffer, instances);

    pass.drawIndexed(
      vertexCount: 4,                    // quad vertices
      instanceCount: instances.length,   // one per entity
      firstIndex: 0,
    );

    // Vertex shader expands each instance into a camera-facing quad
  }
}

// Entity vertex shader (instanced)
// Input: instanceId, vertexId (0-3 for quad corners)
// Output: world-space camera-facing quad
// Uses: entityBuffer[instanceId] for position + color + size
```

### 5.5 Link Polyline Renderer

Links are rendered as polylines with configurable arc types:

```dart
class LinkRenderer {
  void renderLinks(RenderPass pass, List<LinkInstance> links) {
    // Each link → tessellated polyline (32 segments for geodesic arcs)
    // Upload to GPU as line-strip geometry

    for (final link in links) {
      final arcType = link.isElevated ? ArcType.none : ArcType.geodesic;
      final segments = _tessellateArc(link.sourcePos, link.targetPos, arcType);
      // ... upload to vertex buffer
    }

    pass.draw(PrimitiveType.lineStrip, segmentCount);
  }
}
```

---

## 6. Scene Graph & Spatial Data Model

### 6.1 GlobeSceneController

The central orchestrator coordinating all rendering subsystems:

```dart
// lib/domain/cesium_3d/globe_scene_controller.dart

class GlobeSceneController {
  final CesiumEngine _engine;
  final CameraController _camera;
  final EntityManager _entities;
  final LinkManager _links;
  final TileCache _tileCache;
  final MapStyleManager _mapStyle;

  // Updated every frame BEFORE rendering
  void update(double dt) {
    // 1. Camera state → cesium-native
    _engine.updateCamera(_camera.current);

    // 2. Retrieve visible tile set
    final visibleTiles = _engine.getVisibleTiles();
    _tileCache.prune(visibleTiles);
    _tileCache.requestMissing(visibleTiles);

    // 3. Update entity screen positions (from cesium-native projection)
    for (final entity in _entities.active) {
      entity.screenPosition = _engine.cartographicToScreen(
        entity.lat, entity.lng, entity.alt, _viewportSize,
      );
    }

    // 4. Prepare render commands for this frame
    _buildRenderCommands();
  }

  void render(double dt) {
    _globeRenderer.render(_renderCommands);
    _entityRenderer.render(_renderCommands.entities);
    _linkRenderer.render(_renderCommands.links);
    _labelRenderer.render(_renderCommands.labels);
  }
}
```

### 6.2 Entity Data Model

```dart
// lib/domain/cesium_3d/entity.dart

class EntityTypeProfile {
  final String typeName;
  final String category; // 'surface-anchored' | 'elevated' | 'sub-surface'
  final Color defaultColor;
  final double defaultSize;
  final Map<String, dynamic> properties;

  const EntityTypeProfile({
    required this.typeName,
    required this.category,
    required this.defaultColor,
    required this.defaultSize,
    this.properties = const {},
  });

  factory EntityTypeProfile.fromMetadata(Map<String, dynamic> meta) {
    return EntityTypeProfile(
      typeName: meta['typeName'] ?? 'default',
      category: meta['category'] ?? 'surface-anchored',
      defaultColor: Color(int.parse(meta['color'] ?? '0xFFFFFFFF')),
      defaultSize: (meta['size'] ?? 1.0).toDouble(),
      properties: meta['properties'] ?? {},
    );
  }
}

class GlobeEntity {
  final String id;
  final String label;
  final EntityTypeProfile typeProfile;
  double lat;
  double lng;
  double alt;
  Offset? screenPosition;  // set by engine each frame
  Color color;
  bool visible;
  Map<String, dynamic> metadata;

  // Screen-space priority for label rendering (closer → higher)
  double screenDepth;
}

class GlobeLink {
  final String id;
  final String sourceEntityId;
  final String targetEntityId;
  LinkArcType arcType;
  Color color;
  double width;
  bool visible;
}
```

### 6.3 Map Style Configuration

```dart
enum ImageryProvider {
  openStreetMap,
  arcGisSatellite,
  cartoDark,
  cartoLight,
}

enum TerrainProvider {
  cesiumWorld,     // Cesium World Terrain (requires token)
  ellipsoid,       // Flat ellipsoid (no terrain)
}

class MapStyle {
  final ImageryProvider imagery;
  final TerrainProvider terrain;
  final double imageryAlpha;

  const MapStyle({
    required this.imagery,
    required this.terrain,
    this.imageryAlpha = 1.0,
  });
}
```

---

## 7. Camera System

### 7.1 Camera Controller

```dart
// lib/domain/cesium_3d/camera_controller.dart

class CameraController {
  VirtualCamera _camera;

  // Smooth camera animation state
  VirtualCamera? _targetCamera;
  double _transitionProgress = 0.0;
  final Duration _transitionDuration;

  // Input state
  Offset _lastDragPosition = Offset.zero;
  bool _isDragging = false;

  CameraController({
    required VirtualCamera initial,
    this._transitionDuration = const Duration(milliseconds: 1500),
  }) : _camera = initial;

  VirtualCamera get current => _camera;

  // Called from GestureDetector.onPanUpdate
  void handleDrag(Offset delta) {
    _camera = VirtualCamera(
      latitude: (_camera.latitude - delta.dy * 0.15).clamp(-90.0, 90.0),
      longitude: (_camera.longitude - delta.dx * 0.15),
      altitude: _camera.altitude,
      heading: _camera.heading,
      pitch: _camera.pitch,
      roll: _camera.roll,
    );
  }

  // Called from Listener.onPointerSignal (scroll)
  void handleZoom(double scrollDelta) {
    _camera = VirtualCamera(
      latitude: _camera.latitude,
      longitude: _camera.longitude,
      altitude: (_camera.altitude + scrollDelta * 0.5).clamp(100.0, 40000000.0),
      heading: _camera.heading,
      pitch: _camera.pitch,
      roll: _camera.roll,
    );
  }

  // Smooth flyTo animation (used by cesium-native camera.flyTo)
  void flyTo(VirtualCamera target) {
    _targetCamera = target;
    _transitionProgress = 0.0;
  }

  void update(double dt) {
    if (_targetCamera != null) {
      _transitionProgress += dt / _transitionDuration.inMilliseconds * 1000;
      if (_transitionProgress >= 1.0) {
        _camera = _targetCamera!;
        _targetCamera = null;
      } else {
        // Smooth step interpolation (ease-in-out)
        final t = _smoothStep(_transitionProgress);
        _camera = VirtualCamera(
          latitude: _lerp(_camera.latitude, _targetCamera!.latitude, t),
          longitude: _lerpAngle(_camera.longitude, _targetCamera!.longitude, t),
          altitude: _lerp(_camera.altitude, _targetCamera!.altitude, t),
          heading: _lerpAngle(_camera.heading, _targetCamera!.heading, t),
          pitch: _lerp(_camera.pitch, _targetCamera!.pitch, t),
          roll: _lerp(_camera.roll, _targetCamera!.roll, t),
        );
      }
    }
  }
}
```

### 7.2 Camera Input Pipeline

User input handling with platform-native gesture detection:

```
PointerDown  → Record drag origin
PointerMove  → CameraController.handleDrag(delta)
             → CameraController.update(dt)
             → CesiumEngine.updateCamera(camera)
             → [cesium-native culling on background threads]
PointerUp    → Stop drag, no inertia (deterministic)
ScrollEvent  → CameraController.handleZoom(scrollDelta)
```

---

## 8. Geospatial Entity & Path Rendering

### 8.1 Entity Pipeline

```
GeospatialData (DB / JSON)
        │
        ▼
EntityManager.syncFromGeospatialData(GeospatialData data)
  ├── Diff against current entities (add/remove/update)
  ├── Classify by category: surface-anchored (alt ≤ 10k), elevated (alt > 10k), sub-surface (alt ≤ 0)
  ├── Assign styling properties (color, scale) dynamically from EntityTypeProfile and dataset metadata
  └── Build EntityInstance array for GPU
        │
        ▼
EntityRenderer.renderEntityBatch(...)
  └── Single instanced draw call
```

### 8.2 Path & Vector Pipeline

```
GeospatialData.paths
        │
        ▼
PathManager.syncFromPaths(List<GeospatialPath> paths)
  ├── Resolve endpoint entities
  ├── Determine arc type dynamically based on entity profiles:
  │     source.alt > elevatedThreshold || target.alt > elevatedThreshold → ArcType.none (straight spatial vectors)
  │     else → ArcType.geodesic (surface-conforming paths)
  ├── Check depth clamping / sub-surface depth attributes
  └── Build PathInstance array with dynamic color, width, and styles resolved from metadata properties
        │
        ▼
PathRenderer.renderPaths(...)
  ├── Geodesic paths → tessellate 32 segments
  ├── Spatial vectors → single segment
  └── Draw as line strips (applying dash/dynamic animation patterns from metadata)
```

### 8.3 Vertical Projection Drop Rendering

For entities classified as elevated (altitude > threshold resolved from profile/metadata), render vertical projection drops to the surface:

```
For each elevated entity where alt > 0:
  ├── Get entity world position (lat, lng, alt)
  ├── Compute surface-anchored position (lat, lng, 0)
  ├── Render as dashed projection line (color and opacity resolved dynamically from profile properties)
  └── Cesium clamps the surface position to terrain height
```

---

## 9. Performance & Optimization Strategy

### 9.1 Frame Budget (16ms @ 60fps)

| Phase | Budget | Notes |
|---|---|---|
| User input processing | < 0.2ms | Gesture detection |
| Camera update + FFI call | < 0.5ms | C function, no tile work |
| Tile cache management | < 1.0ms | Dart GC-friendly |
| Entity/link position update | < 0.5ms | Screen projection from engine |
| GPU command recording | < 2.0ms | Build render pass commands |
| GPU execution (async) | < 10ms | Impeller on GPU thread |
| Flutter widget rebuild | < 2.0ms | HUD/config panel only |

### 9.2 Memory Budget

| Component | Budget |
|---|---|
| cesium-native runtime | ~100MB |
| Tile cache (GPU textures) | ~200MB |
| Entity/link data | ~50MB |
| Dart heap | ~100MB |
| **Total** | **~450MB** |

### 9.3 Tile Caching Strategy

```
LRU Tile Cache (2048 slots × 256×256 RGBA8 = 512MB theoretical max)
├── Tier 1 (GPU):   512 tiles in VRAM    — 64MB
├── Tier 2 (RAM):   1024 tiles in heap   — 128MB
└── Tier 3 (Disk):  4096 tiles on disk   — 512MB (SQLite BLOB)

Cache eviction:
  - Least-recently-used tile dropped when limit exceeded
  - Tiles invisible for > 30 seconds aggressively evicted
  - Visible tiles pinned (never evicted while in frustum)
```

### 9.4 Level-of-Detail Strategy

cesium-native provides built-in LoD based on:
- Screen-space error metric
- Camera altitude
- Tile distance from camera

We configure the LoD parameters:

```dart
// Runtime LoD tuning based on performance monitoring
void adaptLodQuality(double frameTimeMs) {
  if (frameTimeMs > 16.0) {
    // Aggressively reduce detail
    _engine.setMaximumScreenSpaceError(8.0);
    _engine.setMaxSimultaneousTileLoads(10);
  } else if (frameTimeMs < 8.0) {
    // Increase detail
    _engine.setMaximumScreenSpaceError(2.0);
    _engine.setMaxSimultaneousTileLoads(40);
  }
}
```

---

## 10. Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
**Goal:** cesium-native compiles; FFI bridge works end-to-end with camera + tile query.

| Task | Deliverable |
|---|---|
| Clone cesium-native as git submodule | `third_party/cesium-native/` |
| Write CMakeLists.txt for bridge library | `cesium_native_bridge/CMakeLists.txt` |
| Implement C ABI functions (bridge.h) | `cesium_native_bridge/src/bridge.cpp` |
| Generate Dart FFI bindings (ffigen) | `lib/domain/cesium_3d/native/bridge_bindings.dart` |
| Implement CesiumEngine Dart wrapper | `lib/domain/cesium_3d/cesium_engine.dart` |
| Unit test: FFI calls succeed, errors propagate | `test/cesium_3d/ffi_bridge_test.dart` |
| Integration test: camera → getVisibleTiles roundtrip | `test/cesium_3d/camera_tile_test.dart` |

### Phase 2: GPU Rendering (Week 3-4)
**Goal:** Globe renders in Flutter via Impeller GPU pipeline with terrain and imagery.

| Task | Deliverable |
|---|---|
| Implement Impeller icosphere mesh generator | `lib/domain/cesium_3d/renderers/globe_mesh.dart` |
| Write globe vertex/fragment shaders (terrain + imagery) | `shaders/globe.vert`, `shaders/globe.frag` |
| Implement GlobeMeshRenderer | `lib/domain/cesium_3d/renderers/globe_renderer.dart` |
| Implement tile atlas texture manager | `lib/domain/cesium_3d/renderers/tile_atlas.dart` |
| Implement starfield + atmosphere renderers | `lib/domain/cesium_3d/renderers/starfield_renderer.dart` |
| Widget test: globe renders with default camera | `test/cesium_3d/globe_render_test.dart` |
| Integration test: terrain + 4 imagery styles render | `test/cesium_3d/imagery_test.dart` |

### Phase 3: Entities & Paths (Week 5-6)
**Goal:** Geospatial entities and paths rendered on the globe; camera interaction works.

| Task | Deliverable |
|---|---|
| Implement EntityManager with diff-based updates | `lib/domain/cesium_3d/entity_manager.dart` |
| Implement GPU entity sprite renderer (instanced) | `lib/domain/cesium_3d/renderers/entity_renderer.dart` |
| Implement PathManager with arc type resolution | `lib/domain/cesium_3d/link_manager.dart` |
| Implement GPU path polyline renderer | `lib/domain/cesium_3d/renderers/link_renderer.dart` |
| Implement label billboard renderer (SDF fonts) | `lib/domain/cesium_3d/renderers/label_renderer.dart` |
| Implement vertical projection drop renderer | `lib/domain/cesium_3d/renderers/drop_line_renderer.dart` |
| Integrate camera controller with gesture handlers | `lib/domain/cesium_3d/camera_controller.dart` |
| Widget test: entities + paths render correctly | `test/cesium_3d/entity_link_test.dart` |
| Integration test: geospatial profiles rendered on globe | `test/cesium_3d/topology_integration_test.dart` |

### Phase 4: UI Integration & Feature Parity (Week 7-8)
**Goal:** Replace custom-painted globe; match reference app's 3D geospatial visualization capabilities.

| Task | Deliverable |
|---|---|
| Replace Scene3DViewport CustomPaint with CesiumGlobeViewport | `lib/features/topology/scene_3d_viewport.dart` |
| Wire map style switching (4 imagery types) | `lib/features/topology/scene_3d_viewport.dart` |
| Wire visibility toggles (entities, paths, labels, projection drops) | `lib/features/topology/scene_3d_viewport.dart` |
| Wire terrain toggle | `lib/features/topology/scene_3d_viewport.dart` |
| Wire camera stats HUD (live from CameraController) | `lib/features/topology/scene_3d_viewport.dart` |
| Wire double-click entity navigation | `lib/features/topology/scene_3d_viewport.dart` |
| Implement screen-space entity picking (raycast) | `lib/domain/cesium_3d/cesium_engine.dart` |
| Full integration test: all toggle permutations | `test/cesium_3d/full_integration_test.dart` |
| Performance benchmark: 10k entities, 50k paths @ 60fps | `test/cesium_3d/performance_benchmark_test.dart` |

### Phase 5: Hardening & Optimization (Week 9-10)
**Goal:** Production quality: error recovery, performance tuning, cross-platform verification.

| Task | Deliverable |
|---|---|
| Add tile cache persistence (SQLite BLOB on disk) | `lib/domain/cesium_3d/tile_cache.dart` |
| Add LoD adaptation based on frame timing | `lib/domain/cesium_3d/lod_controller.dart` |
| Add cesium-native crash recovery (process restart) | `lib/domain/cesium_3d/engine_recovery.dart` |
| Add memory pressure monitoring | `lib/domain/cesium_3d/memory_monitor.dart` |
| Cross-platform build verification (macOS + Linux) | CI pipeline |
| Performance profiling with Instruments/Perf | Performance report |
| Documentation: architecture, API, build instructions | `docs/cesium-native-integration/` |

---

## Appendix A: Directory Structure

```
app_flutter/
├── lib/
│   ├── domain/
│   │   └── cesium_3d/
│   │       ├── cesium_engine.dart              # High-level engine wrapper
│   │       ├── globe_scene_controller.dart      # Per-frame orchestrator
│   │       ├── camera_controller.dart           # User input → camera state
│   │       ├── entity_manager.dart              # Entity lifecycle + diffing
│   │       ├── link_manager.dart                # Link lifecycle + arc logic
│   │       ├── tile_cache.dart                  # Multi-tier tile cache
│   │       ├── lod_controller.dart              # Adaptive LoD
│   │       ├── entity.dart                      # GlobeEntity, GlobeLink
│   │       ├── map_style.dart                   # Imagery + terrain config
│   │       ├── virtual_camera.dart              # Camera data class (existing)
│   │       ├── coordinate_transformer.dart       # ECEF/screen transforms
│   │       ├── native/
│   │       │   ├── bridge_bindings.dart         # ffigen-generated FFI bindings
│   │       │   ├── native_resource.dart         # RAII native memory
│   │       │   ├── tileset_config.dart          # C struct marshaling
│   │       │   └── error_handler.dart           # C error → Dart exception
│   │       └── renderers/
│   │           ├── globe_renderer.dart           # Globe mesh + terrain
│   │           ├── entity_renderer.dart          # Instanced sprite renderer
│   │           ├── link_renderer.dart            # Polyline renderer
│   │           ├── label_renderer.dart           # SDF billboard renderer
│   │           ├── drop_line_renderer.dart       # Vertical drop line renderer
│   │           ├── starfield_renderer.dart       # Background stars
│   │           ├── atmosphere_renderer.dart       # Rayleigh atmosphere
│   │           ├── tile_atlas.dart               # GPU texture atlas
│   │           └── globe_mesh.dart               # Icosphere generator
│   └── features/
│       └── topology/
│           ├── scene_3d_viewport.dart            # HUD + config panel (updated)
│           ├── topographical_view.dart           # 2D/3D toggle (updated)
│           └── topology_map.dart                 # 2D canvas (unchanged)
├── shaders/
│   ├── globe.vert                               # Terrain-displaced globe vertex
│   ├── globe.frag                               # Imagery sampling fragment
│   ├── starfield.vert                            # Star quad vertex
│   ├── starfield.frag                            # Star point fragment
│   ├── atmosphere.frag                           # Rayleigh scattering
│   ├── entity_sprite.vert                        # Instanced entity billboard
│   ├── entity_sprite.frag                        # Entity color/texture
│   ├── link_polyline.vert                        # Link line strip vertex
│   ├── link_polyline.frag                        # Link color fragment
│   └── label_sdf.frag                            # SDF text rendering
├── third_party/
│   └── cesium-native/                            # Git submodule
└── cesium_native_bridge/
    ├── CMakeLists.txt                            # Build configuration
    ├── include/
    │   └── bridge.h                              # Public C ABI header
    └── src/
        ├── bridge.cpp                            # Lifecycle + initialization
        ├── camera_marshal.cpp                    # Camera struct ↔ cesium-native
        ├── tile_data_marshal.cpp                 # Tile data ↔ serialized buffer
        ├── resource_manager.cpp                  # Native memory tracking
        └── error_propagator.cpp                  # Error code → message
```

## Appendix B: Key Design Decisions

| Decision | Rationale |
|---|---|
| **C ABI over C++ exceptions** | Dart FFI cannot catch C++ exceptions. All cross-boundary functions return `int32_t` status codes. Error messages are retrieved via `bridge_get_last_error()`. |
| **Calloc over malloc** | `calloc` zero-initializes; critical for struct marshaling where uninitialized padding bytes cause undefined behavior in FFI. |
| **NativeFinalizer over manual free** | Guarantees native memory release even if Dart code throws or forgets. Prevents memory leaks in error paths. |
| **Tile atlas over individual textures** | Reduces GPU texture binds from N to 1 per render pass. Enables single draw call for all tile imagery. |
| **Instanced rendering for entities** | Single draw call for 10k+ entities. CPU uploads instance buffer once per frame. |
| **No physics on main thread** | Graph layout and tile decompression run on background isolates. Main thread only records GPU commands. |
| **SDF font atlas for labels** | Single texture for all label text. Resolution-independent. GPU-accelerated rendering via fragment shader distance field evaluation. |
