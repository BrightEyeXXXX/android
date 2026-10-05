import CoreGraphics
import Foundation

/// Software raycaster rendering into a low-resolution RGBA buffer.
final class Renderer {
    static let width = 320
    static let height = 200

    private var pixels = [UInt32](repeating: 0, count: Renderer.width * Renderer.height)
    private var zBuffer = [Double](repeating: 0, count: Renderer.width)
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    @inline(__always)
    private func pack(_ r: Double, _ g: Double, _ b: Double) -> UInt32 {
        let ri = UInt32(max(0, min(255, r))), gi = UInt32(max(0, min(255, g))), bi = UInt32(max(0, min(255, b)))
        return ri | (gi << 8) | (bi << 16) | (0xFF << 24)
    }

    private func wallColor(_ cell: UInt8) -> (Double, Double, Double) {
        switch cell {
        case 2: return (170, 100, 60)
        case 3: return (60, 150, 90)
        default: return (110, 120, 160)
        }
    }

    func render(world w: World) -> CGImage? {
        let W = Renderer.width, H = Renderer.height
        drawBackground()

        let dirX = cos(w.angle), dirY = sin(w.angle)
        let planeX = -dirY * 0.66, planeY = dirX * 0.66

        for x in 0..<W {
            let cam = 2 * Double(x) / Double(W) - 1
            let rdx = dirX + planeX * cam, rdy = dirY + planeY * cam
            let hit = w.castRay(ox: w.px, oy: w.py, dx: rdx, dy: rdy)
            zBuffer[x] = hit.dist
            let lineH = Int(Double(H) / hit.dist)
            let start = H / 2 - lineH / 2
            let y0 = max(0, start), y1 = min(H - 1, start + lineH)
            if y0 > y1 { continue }
            let base = wallColor(hit.cell)
            let light = max(0.15, 1.0 - hit.dist / 14.0) * (hit.side == 1 ? 0.7 : 1.0)
            for y in y0...y1 {
                let v = Double(y - start) / Double(max(lineH, 1))
                let row = Int(v * 8)
                let u = hit.wallX + (row % 2 == 0 ? 0 : 0.125)
                let mortar = (v * 8).truncatingRemainder(dividingBy: 1) < 0.08
                    || (u * 4).truncatingRemainder(dividingBy: 1) < 0.06
                let k = light * (mortar ? 0.55 : 1.0)
                pixels[y * W + x] = pack(base.0 * k, base.1 * k, base.2 * k)
            }
        }

        drawEnemies(world: w, dirX: dirX, dirY: dirY, planeX: planeX, planeY: planeY)

        let data = pixels.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private func drawBackground() {
        let W = Renderer.width, H = Renderer.height
        for y in 0..<H {
            let t = abs(Double(y) - Double(H) / 2) / (Double(H) / 2)
            let c = y < H / 2 ? pack(30 + 20 * (1 - t), 30 + 20 * (1 - t), 40 + 25 * (1 - t))
                              : pack(40 * t + 15, 36 * t + 12, 30 * t + 10)
            for x in 0..<W { pixels[y * W + x] = c }
        }
    }

    private func drawEnemies(world w: World, dirX: Double, dirY: Double, planeX: Double, planeY: Double) {
        let W = Renderer.width, H = Renderer.height
        let invDet = 1.0 / (planeX * dirY - dirX * planeY)
        let sorted = w.enemies.sorted {
            hypot($0.x - w.px, $0.y - w.py) > hypot($1.x - w.px, $1.y - w.py)
        }
        for e in sorted {
            let dx = e.x - w.px, dy = e.y - w.py
            let tx = invDet * (dirY * dx - dirX * dy)
            let ty = invDet * (-planeY * dx + planeX * dy)
            if ty < 0.15 { continue }
            let screenX = Int(Double(W) / 2 * (1 + tx / ty))
            let size = Int(Double(H) / ty)
            let alive = e.isAlive
            let spriteH = alive ? size : size / 4
            let top = H / 2 + size / 2 - spriteH
            let left = screenX - size / 2
            let light = max(0.25, 1.0 - ty / 14.0)
            for sx in max(0, left)..<max(0, min(W, left + size)) where zBuffer[sx] > ty {
                let u = Double(sx - left) / Double(size)
                for sy in max(0, top)..<max(0, min(H, top + spriteH)) {
                    let v = Double(sy - top) / Double(max(spriteH, 1))
                    guard let c = enemyColor(u: u, v: v, alive: alive, flash: e.hitFlash > 0) else { continue }
                    pixels[sy * W + sx] = pack(c.0 * light, c.1 * light, c.2 * light)
                }
            }
        }
    }

    /// Procedural demon silhouette. Returns nil for transparent pixels.
    private func enemyColor(u: Double, v: Double, alive: Bool, flash: Bool) -> (Double, Double, Double)? {
        if !alive { // corpse
            return abs(u - 0.5) < 0.4 && v > 0.3 ? (110, 20, 20) : nil
        }
        let cx = u - 0.5
        if flash { return abs(cx) < 0.3 && v > 0.1 ? (255, 255, 255) : nil }
        // head
        if v < 0.28 {
            let hx = cx, hy = v - 0.14
            guard hx * hx / 0.025 + hy * hy / 0.02 < 1 else { return nil }
            if v > 0.1 && v < 0.17 && abs(abs(cx) - 0.07) < 0.03 { return (255, 230, 40) } // eyes
            return (150, 60, 40)
        }
        // body + arms
        if v < 0.65 {
            if abs(cx) < 0.22 { return (130, 45, 35) }
            if abs(cx) < 0.34 && v < 0.55 { return (150, 60, 40) }
            return nil
        }
        // legs
        if abs(abs(cx) - 0.1) < 0.08 { return (90, 35, 30) }
        return nil
    }
}
