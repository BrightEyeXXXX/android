import SwiftUI
import QuartzCore

final class GameModel: ObservableObject {
    @Published var frame: CGImage?
    @Published var health = 100
    @Published var ammo = 60
    @Published var kills = 0
    @Published var totalEnemies = 0
    @Published var status: GameStatus = .playing
    @Published var muzzle = false
    @Published var damage = 0.0

    /// Written by touch controls, consumed every tick.
    var input = PlayerInput()
    var firing = false

    private let world = World()
    private let renderer = Renderer()
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0

    init() { totalEnemies = world.enemies.count }

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
        last = CACurrentMediaTime()
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    func restart() {
        world.reset()
        totalEnemies = world.enemies.count
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let dt = min(now - last, 0.05)
        last = now

        var frameInput = input
        frameInput.fire = firing
        input.turn = 0   // turn is a one-shot delta
        world.update(dt: dt, input: frameInput)

        frame = renderer.render(world: world)
        health = Int(world.health)
        ammo = world.ammo
        kills = world.kills
        status = world.status
        muzzle = world.muzzleFlash > 0
        damage = world.damageFlash
    }
}
