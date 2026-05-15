import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @State private var dragAnchor: CGPoint?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)

            controlPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 14)
                .allowsHitTesting(false)

            PetSpriteView(state: viewModel.activityState, facingRight: viewModel.isFacingRight)
                .frame(width: viewModel.petSize.width, height: viewModel.petSize.height)
                .position(viewModel.petPosition)
                .animation(.linear(duration: 1.0 / 30.0), value: viewModel.petPosition)
                .contentShape(Circle())
                .allowsHitTesting(true)
                .onTapGesture {
                    viewModel.onCatTap()
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { gesture in
                            if dragAnchor == nil {
                                dragAnchor = viewModel.petPosition
                            }
                            let base = dragAnchor ?? viewModel.petPosition
                            let next = CGPoint(
                                x: base.x + gesture.translation.width,
                                y: base.y + gesture.translation.height
                            )
                            viewModel.onDragChanged(next)
                        }
                        .onEnded { _ in
                            dragAnchor = nil
                            viewModel.onDragEnded()
                        }
                )
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pet AI Demo")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Text("状态")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(viewModel.activityState.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Picker("节奏", selection: Binding(
                get: { viewModel.tempoProfile },
                set: { viewModel.setTempoProfile($0) }
            )) {
                ForEach(TempoProfile.allCases) { profile in
                    Text(profile.rawValue).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Toggle(isOn: Binding(
                get: { viewModel.isPaused },
                set: { viewModel.setPaused($0) }
            )) {
                Text("暂停")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .toggleStyle(.switch)

            Text("点击猫咪: 原地跳跃\n拖拽猫咪: 放置到新地面")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PetSpriteView: View {
    let state: PetActivityState
    let facingRight: Bool

    private var bodyColor: Color {
        switch state {
        case .jump: return Color(red: 0.89, green: 0.53, blue: 0.22)
        case .run: return Color(red: 0.86, green: 0.48, blue: 0.2)
        case .drag: return Color(red: 0.94, green: 0.62, blue: 0.24)
        default: return Color(red: 0.82, green: 0.44, blue: 0.19)
        }
    }

    private var statusText: String {
        switch state {
        case .idle: return "Zz"
        case .walk: return "walk"
        case .run: return "run"
        case .jump: return "jump"
        case .drag: return "drag"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [bodyColor.opacity(0.96), Color(red: 0.58, green: 0.29, blue: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 88, height: 66)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.26), lineWidth: 1.6)
                )
                .shadow(color: .black.opacity(0.26), radius: 12, y: 7)

            CatEarPair()
                .offset(y: -34)

            HStack(spacing: 14) {
                Circle().fill(Color.black).frame(width: 6, height: 6)
                Circle().fill(Color.black).frame(width: 6, height: 6)
            }
            .offset(y: -6)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.98, green: 0.75, blue: 0.63))
                .frame(width: 10, height: 7)
                .offset(y: 3)

            CatTail(state: state)
                .offset(x: facingRight ? 42 : -42, y: 2)
                .scaleEffect(x: facingRight ? 1 : -1, y: 1)

            Text(statusText)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.22))
                .clipShape(Capsule())
                .offset(y: 27)
        }
        .scaleEffect(state == .jump ? 1.03 : 1)
        .animation(.easeInOut(duration: 0.18), value: state)
    }
}

private struct CatEarPair: View {
    var body: some View {
        HStack(spacing: 28) {
            Triangle()
                .fill(Color(red: 0.76, green: 0.38, blue: 0.16))
                .frame(width: 16, height: 16)
            Triangle()
                .fill(Color(red: 0.76, green: 0.38, blue: 0.16))
                .frame(width: 16, height: 16)
        }
    }
}

private struct CatTail: View {
    let state: PetActivityState
    @State private var wag = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(red: 0.52, green: 0.24, blue: 0.1))
            .frame(width: 28, height: 10)
            .rotationEffect(.degrees(wag ? 18 : -16))
            .onAppear {
                let base: Double
                switch state {
                case .run: base = 0.14
                case .jump: base = 0.18
                default: base = 0.3
                }
                withAnimation(.easeInOut(duration: base).repeatForever(autoreverses: true)) {
                    wag.toggle()
                }
            }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
