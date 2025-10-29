# 3D Models Directory

Place your `.glb` or `.gltf` 3D house models in this directory.

## Included Model

**`house.gltf`** - A simple red cube for testing AR placement. Replace this with your own architectural model.

## ⚠️ Troubleshooting Model Loading

If you see errors loading the model:

### Option 1: Use GLB format (recommended)
Convert your `.gltf` to `.glb` (binary format) which is more reliable:
- Use [glTF Tools VSCode Extension](https://marketplace.visualstudio.com/items?itemName=cesium.gltf-vscode)
- Or use online converter: [glTF Viewer](https://gltf-viewer.donmccurdy.com/)

### Option 2: Use a hosted URL
Instead of local assets, use a public URL:
```dart
ARNode(
  type: NodeType.webGLB,  // Note: webGLB not localGLTF2
  uri: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Binary/Duck.glb",
  scale: Vector3(0.1, 0.1, 0.1),
  ...
)
```

### Option 3: Test with sample models
Download tested models from:
- [glTF Sample Models](https://github.com/KhronosGroup/glTF-Sample-Models/tree/master/2.0)
- Use `Duck.glb`, `Box.glb`, or `Avocado.glb` for testing

## Requirements
- Format: glTF 2.0 (.glb or .gltf recommended)
- Coordinate System: +Y Up
- Include materials and textures in the export
- Recommended tools: Blender, SketchUp, Revit
- Keep polygon count reasonable for mobile (< 100k triangles)

## Export Tips from Blender
1. Select your house model
2. File > Export > glTF 2.0 (.glb/.gltf)
3. Check these options:
   - ✅ Include → Selected Objects
   - ✅ Transform → +Y Up
   - ✅ Include Materials / Textures
   - ✅ Compression (optional, for smaller files)
4. Save as `house.gltf` or `house.glb`

## Model Sources

Free 3D architectural models:
- [Sketchfab](https://sketchfab.com/tags/house) - Filter by "Downloadable"
- [Poly Haven](https://polyhaven.com/) - Public domain assets
- [Clara.io](https://clara.io/) - Free models section
- [Free3D](https://free3d.com/3d-models/house) - Architecture category

## Default Model

The app looks for `assets/models/house.gltf` by default. You can modify the path in `lib/screens/ar_house_screen.dart` to switch between models.

## Animation Support

The new `ar_flutter_plugin_2` supports animated glTF models! You can use models with skeletal animations, morph targets, or keyframe animations.
