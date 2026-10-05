# DoomLike (iOS)

Doom-style 3D shooter using a software raycaster (320x200 buffer, SwiftUI front end). iOS 16+, landscape.

## Build
```
brew install xcodegen
cd ios/DoomLike && xcodegen generate && open DoomLike.xcodeproj
```
Run on a simulator or device.

## Controls
- Left stick: move / strafe
- Drag right half of screen: turn
- FIRE button: shoot (hold to auto-fire)

Goal: kill all demons. Enemies chase on sight and melee you.

## Layout
- `World.swift` map, player, enemies, hitscan, DDA ray casting
- `Renderer.swift` walls, billboard sprites, z-buffer
- `GameModel.swift` CADisplayLink game loop
- `GameView.swift` SwiftUI view, touch controls, HUD
