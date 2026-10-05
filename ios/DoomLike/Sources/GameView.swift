import SwiftUI

struct GameView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = model.frame {
                Image(decorative: img, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(CGFloat(Renderer.width) / CGFloat(Renderer.height), contentMode: .fit)
                    .ignoresSafeArea()
            }

            Color.red.opacity(model.damage * 1.2).ignoresSafeArea().allowsHitTesting(false)

            // Look area (right half): horizontal drag turns.
            LookPad { dx in model.input.turn += Double(dx) * 0.006 }

            Crosshair().allowsHitTesting(false)
            WeaponView(firing: model.muzzle).allowsHitTesting(false)
            HUD(model: model).allowsHitTesting(false)

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Joystick { x, y in
                        model.input.moveStrafe = x
                        model.input.moveForward = -y
                    }
                    .padding(.leading, 32)
                    Spacer()
                    FireButton(onChange: { model.firing = $0 })
                        .padding(.trailing, 32)
                }
                .padding(.bottom, 24)
            }

            if model.status != .playing {
                EndOverlay(won: model.status == .won) { model.restart() }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

private struct LookPad: View {
    var onDrag: (CGFloat) -> Void
    @State private var lastX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geo.size.width / 2)
                .offset(x: geo.size.width / 2)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if let l = lastX { onDrag(v.location.x - l) }
                        lastX = v.location.x
                    }
                    .onEnded { _ in lastX = nil })
        }
        .ignoresSafeArea()
    }
}

private struct Joystick: View {
    var onChange: (Double, Double) -> Void
    @State private var offset = CGSize.zero
    private let radius: CGFloat = 60

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.15)).frame(width: radius * 2, height: radius * 2)
            Circle().fill(Color.white.opacity(0.5)).frame(width: 56, height: 56).offset(offset)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                let dx = v.translation.width, dy = v.translation.height
                let len = max(hypot(dx, dy), 0.001)
                let k = min(len, radius) / len
                offset = CGSize(width: dx * k, height: dy * k)
                onChange(Double(offset.width / radius), Double(offset.height / radius))
            }
            .onEnded { _ in
                offset = .zero
                onChange(0, 0)
            })
    }
}

private struct FireButton: View {
    var onChange: (Bool) -> Void
    @State private var pressed = false

    var body: some View {
        Circle()
            .fill(Color.red.opacity(pressed ? 0.9 : 0.6))
            .frame(width: 88, height: 88)
            .overlay(Text("FIRE").font(.system(size: 16, weight: .heavy)).foregroundColor(.white))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed { pressed = true; onChange(true) }
                }
                .onEnded { _ in
                    pressed = false
                    onChange(false)
                })
    }
}

private struct Crosshair: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.8)).frame(width: 14, height: 2)
            Rectangle().fill(Color.white.opacity(0.8)).frame(width: 2, height: 14)
        }
    }
}

private struct WeaponView: View {
    var firing: Bool
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if firing {
                Circle().fill(Color.yellow).frame(width: 40, height: 40).blur(radius: 4)
            }
            RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.35)).frame(width: 26, height: 70)
            RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.2)).frame(width: 70, height: 36)
        }
        .offset(y: 8)
    }
}

private struct HUD: View {
    @ObservedObject var model: GameModel
    var body: some View {
        VStack {
            HStack {
                stat("HEALTH", "\(model.health)", model.health < 30 ? .red : .white)
                stat("AMMO", "\(model.ammo)", model.ammo < 10 ? .orange : .white)
                stat("KILLS", "\(model.kills)/\(model.totalEnemies)", .white)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.top, 8)
            Spacer()
        }
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
            Text(value).font(.system(size: 22, weight: .heavy, design: .monospaced)).foregroundColor(color)
        }
        .padding(.trailing, 14)
    }
}

private struct EndOverlay: View {
    var won: Bool
    var onRestart: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(won ? "YOU WIN" : "YOU DIED")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundColor(won ? .green : .red)
                Button("RESTART", action: onRestart)
                    .font(.system(size: 20, weight: .bold))
                    .padding(.horizontal, 28).padding(.vertical, 10)
                    .background(Color.white).foregroundColor(.black).cornerRadius(8)
            }
        }
    }
}
