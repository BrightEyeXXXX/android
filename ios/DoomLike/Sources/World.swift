import Foundation

struct Enemy {
    var x: Double
    var y: Double
    var health: Double = 40
    var attackCooldown: Double = 0
    var alerted = false
    var hitFlash: Double = 0
    var isAlive: Bool { health > 0 }
}

struct RayHit {
    var dist: Double
    var side: Int      // 0: x-side, 1: y-side
    var cell: UInt8
    var wallX: Double  // 0...1 position along the wall
}

struct PlayerInput {
    var moveForward: Double = 0   // -1...1
    var moveStrafe: Double = 0    // -1...1
    var turn: Double = 0          // radians this frame
    var fire = false
}

enum GameStatus { case playing, won, dead }

final class World {
    static let layout: [String] = [
        "1111111111111111",
        "1P00000100000001",
        "1000000100000E01",
        "1002200000022001",
        "1000000100000001",
        "1110111100111101",
        "1000000000000001",
        "10E00033000000E1",
        "1000000330000001",
        "1011110000111101",
        "1000000100000001",
        "1000E00100E00001",
        "1000000000000001",
        "1033000220003301",
        "10000E0000E00001",
        "1111111111111111",
    ]

    private(set) var grid: [[UInt8]] = []
    var width: Int { grid.first?.count ?? 0 }
    var height: Int { grid.count }

    var px = 1.5, py = 1.5, angle = 0.0
    var health = 100.0
    var ammo = 60
    var kills = 0
    var enemies: [Enemy] = []
    var status: GameStatus = .playing
    var fireCooldown = 0.0
    var muzzleFlash = 0.0
    var damageFlash = 0.0

    init() { reset() }

    func reset() {
        grid = []
        enemies = []
        for (y, row) in World.layout.enumerated() {
            var line: [UInt8] = []
            for (x, ch) in row.enumerated() {
                switch ch {
                case "P":
                    px = Double(x) + 0.5; py = Double(y) + 0.5
                    line.append(0)
                case "E":
                    enemies.append(Enemy(x: Double(x) + 0.5, y: Double(y) + 0.5))
                    line.append(0)
                default:
                    line.append(UInt8(String(ch)) ?? 0)
                }
            }
            grid.append(line)
        }
        angle = 0; health = 100; ammo = 60; kills = 0
        status = .playing; fireCooldown = 0; muzzleFlash = 0; damageFlash = 0
    }

    func cell(_ x: Int, _ y: Int) -> UInt8 {
        guard y >= 0, y < height, x >= 0, x < width else { return 1 }
        return grid[y][x]
    }

    func isWall(_ x: Double, _ y: Double) -> Bool { cell(Int(floor(x)), Int(floor(y))) != 0 }

    private func canStand(_ x: Double, _ y: Double, r: Double = 0.22) -> Bool {
        !(isWall(x - r, y - r) || isWall(x + r, y - r) || isWall(x - r, y + r) || isWall(x + r, y + r))
    }

    func castRay(ox: Double, oy: Double, dx: Double, dy: Double) -> RayHit {
        var mapX = Int(floor(ox)), mapY = Int(floor(oy))
        let ddx = dx == 0 ? 1e30 : abs(1 / dx)
        let ddy = dy == 0 ? 1e30 : abs(1 / dy)
        let stepX = dx < 0 ? -1 : 1, stepY = dy < 0 ? -1 : 1
        var sideX = dx < 0 ? (ox - Double(mapX)) * ddx : (Double(mapX) + 1 - ox) * ddx
        var sideY = dy < 0 ? (oy - Double(mapY)) * ddy : (Double(mapY) + 1 - oy) * ddy
        var side = 0
        var c: UInt8 = 1
        for _ in 0..<64 {
            if sideX < sideY { sideX += ddx; mapX += stepX; side = 0 }
            else { sideY += ddy; mapY += stepY; side = 1 }
            c = cell(mapX, mapY)
            if c != 0 { break }
        }
        let dist = side == 0 ? sideX - ddx : sideY - ddy
        var wx = side == 0 ? oy + dist * dy : ox + dist * dx
        wx -= floor(wx)
        return RayHit(dist: max(dist, 0.0001), side: side, cell: c, wallX: wx)
    }

    func update(dt: Double, input: PlayerInput) {
        muzzleFlash = max(0, muzzleFlash - dt)
        damageFlash = max(0, damageFlash - dt)
        fireCooldown = max(0, fireCooldown - dt)
        guard status == .playing else { return }

        angle += input.turn
        let dirX = cos(angle), dirY = sin(angle)
        let speed = 3.0
        let vx = (dirX * input.moveForward - dirY * input.moveStrafe) * speed * dt
        let vy = (dirY * input.moveForward + dirX * input.moveStrafe) * speed * dt
        if canStand(px + vx, py) { px += vx }
        if canStand(px, py + vy) { py += vy }

        if input.fire { fire() }
        updateEnemies(dt: dt)

        if health <= 0 { health = 0; status = .dead }
        else if enemies.allSatisfy({ !$0.isAlive }) { status = .won }
    }

    private func fire() {
        guard fireCooldown == 0, ammo > 0 else { return }
        ammo -= 1
        fireCooldown = 0.3
        muzzleFlash = 0.08
        let dirX = cos(angle), dirY = sin(angle)
        let wallDist = castRay(ox: px, oy: py, dx: dirX, dy: dirY).dist
        var best: (idx: Int, dist: Double)?
        for (i, e) in enemies.enumerated() where e.isAlive {
            let dx = e.x - px, dy = e.y - py
            let dist = hypot(dx, dy)
            guard dist < wallDist else { continue }
            let along = dx * dirX + dy * dirY
            let across = abs(dx * -dirY + dy * dirX)
            if along > 0, across < 0.3, best == nil || dist < best!.dist { best = (i, dist) }
        }
        if let b = best {
            enemies[b.idx].health -= 20
            enemies[b.idx].alerted = true
            enemies[b.idx].hitFlash = 0.12
            if !enemies[b.idx].isAlive { kills += 1 }
        }
    }

    private func updateEnemies(dt: Double) {
        for i in enemies.indices where enemies[i].isAlive {
            var e = enemies[i]
            e.attackCooldown = max(0, e.attackCooldown - dt)
            e.hitFlash = max(0, e.hitFlash - dt)
            let dx = px - e.x, dy = py - e.y
            let dist = hypot(dx, dy)
            let los = castRay(ox: e.x, oy: e.y, dx: dx / dist, dy: dy / dist).dist > dist
            if los && dist < 8 { e.alerted = true }
            if e.alerted && dist > 0.8 {
                let s = 1.2 * dt
                let nx = e.x + dx / dist * s, ny = e.y + dy / dist * s
                if canStand(nx, e.y, r: 0.25) { e.x = nx }
                if canStand(e.x, ny, r: 0.25) { e.y = ny }
            }
            if dist <= 1.0 && los && e.attackCooldown == 0 {
                e.attackCooldown = 1.0
                health -= 10
                damageFlash = 0.25
            }
            enemies[i] = e
        }
    }
}
