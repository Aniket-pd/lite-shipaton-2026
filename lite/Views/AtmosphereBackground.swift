import SwiftUI
import UIKit

/// A single deterministic particle scene. Particle state comes from an
/// absolute clock rather than stored Core Animation playback, so tab updates
/// cannot restart or exhaust the flow.
struct AtmosphereBackground: UIViewRepresentable {
    var isActive: Bool
    let animationEpoch: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeUIView(context: Context) -> AtmosphereUIView {
        AtmosphereUIView(animationEpoch: animationEpoch)
    }

    func updateUIView(_ view: AtmosphereUIView, context: Context) {
        view.configure(
            isActive: isActive,
            reduceMotion: reduceMotion,
            increaseContrast: contrast == .increased,
            reduceTransparency: reduceTransparency
        )
    }

    static func dismantleUIView(_ view: AtmosphereUIView, coordinator: ()) {
        view.setActive(false)
    }
}

final class AtmosphereUIView: UIView {
    private let foundation = CAGradientLayer()
    private let atmosphere = CALayer()
    private let warmLight = CAGradientLayer()
    private let coolLight = CAGradientLayer()
    private let particles = AtmosphereUIView.makeParticles()
    private var particleLayers: [CALayer] = []
    private let animationEpoch: TimeInterval
    private var displayLink: CADisplayLink?

    private var isActive = false
    private var reduceMotion = false
    private var increaseContrast = false
    private var reduceTransparency = false
    private var applicationIsActive = UIApplication.shared.applicationState == .active
    private var lastSize = CGSize.zero
    private var particleTextures: [CGImage?] = []

    init(animationEpoch: TimeInterval) {
        self.animationEpoch = animationEpoch
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        isOpaque = true

        layer.addSublayer(foundation)
        layer.addSublayer(atmosphere)
        atmosphere.addSublayer(warmLight)
        atmosphere.addSublayer(coolLight)
        foundation.startPoint = CGPoint(x: 0, y: 0)
        foundation.endPoint = CGPoint(x: 1, y: 1)
        foundation.locations = [0, 0.48, 1]

        for light in [warmLight, coolLight] {
            light.type = .radial
            light.startPoint = CGPoint(x: 0.5, y: 0.5)
            light.endPoint = CGPoint(x: 1, y: 1)
            light.locations = [0, 0.38, 1]
        }

        configureAppearance()
        for particle in particles {
            let sprite = CALayer()
            sprite.contents = particleTextures[particle.depth]
            sprite.bounds = CGRect(x: 0, y: 0, width: particle.diameter, height: particle.diameter)
            atmosphere.addSublayer(sprite)
            particleLayers.append(sprite)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(environmentChanged),
            name: .NSProcessInfoPowerStateDidChange, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func configure(
        isActive: Bool,
        reduceMotion: Bool,
        increaseContrast: Bool,
        reduceTransparency: Bool
    ) {
        self.isActive = isActive
        self.reduceMotion = reduceMotion
        self.increaseContrast = increaseContrast
        self.reduceTransparency = reduceTransparency
        updatePlayback()
    }

    func setActive(_ active: Bool) {
        isActive = active
        updatePlayback()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updatePlayback()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, bounds.size != lastSize else { return }
        lastSize = bounds.size

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        foundation.frame = bounds
        atmosphere.frame = bounds
        warmLight.frame = CGRect(x: -bounds.width * 0.65, y: -bounds.height * 0.52,
                                 width: bounds.width * 1.9, height: bounds.height * 1.23)
        coolLight.frame = CGRect(x: -bounds.width * 0.65, y: bounds.height * 0.44,
                                 width: bounds.width * 1.9, height: bounds.height * 0.76)
        CATransaction.commit()
        renderFrame()
    }

    private func configureAppearance() {
        foundation.colors = [color(0x151722), color(0x0A0E19), color(0x080D16)].map(\.cgColor)
        setGlow(warmLight, color: color(0xDEC5AA), alpha: 0.28)
        setGlow(coolLight, color: color(0xA8C0D0), alpha: 0.10)
        particleTextures = [color(0xCEB485), color(0xE6C596), color(0xD9BA87)]
            .enumerated().map { index, tone in
                makeParticleTexture(color: tone, isSoft: index == 2)
            }
    }

    @objc private func renderFrame() {
        guard lastSize.width > 0, lastSize.height > 0 else { return }
        let time = reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
            ? animationEpoch
            : Date.timeIntervalSinceReferenceDate
        let elapsed = time - animationEpoch

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        warmLight.setAffineTransform(CGAffineTransform(
            translationX: sin(elapsed / 23 * .pi) * 14, y: 0
        ))
        coolLight.setAffineTransform(CGAffineTransform(
            translationX: sin(elapsed / 31 * .pi) * -18, y: 0
        ))
        for (sprite, particle) in zip(particleLayers, particles) {
            let progress = positiveRemainder(elapsed / particle.duration + particle.phase)
            sprite.position = particle.position(at: progress, size: lastSize)
            sprite.opacity = Float(particle.opacity(at: progress))
        }
        CATransaction.commit()
    }

    private func updatePlayback() {
        let stationary = reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
        let shouldPlay = isActive && window != nil && applicationIsActive
            && !stationary && !reduceTransparency

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        atmosphere.opacity = reduceTransparency ? 0 : (increaseContrast ? 0.4 : 1)
        CATransaction.commit()
        renderFrame()

        if shouldPlay, displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(renderFrame))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else if !shouldPlay, let displayLink {
            displayLink.invalidate()
            self.displayLink = nil
        }
    }

    @objc private func environmentChanged() { updatePlayback() }

    @objc private func applicationDidBecomeActive() {
        applicationIsActive = true
        updatePlayback()
    }

    @objc private func applicationWillResignActive() {
        applicationIsActive = false
        updatePlayback()
    }

    private func positiveRemainder(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
    }

    private func setGlow(_ light: CAGradientLayer, color: UIColor, alpha: CGFloat) {
        light.colors = [alpha, alpha * 0.45, 0].map { color.withAlphaComponent($0).cgColor }
    }

    private func makeParticleTexture(color: UIColor, isSoft: Bool) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48), format: format)
        return renderer.image { output in
            let alphas: [CGFloat] = isSoft ? [0.7, 0.5, 0.12, 0] : [1, 0.85, 0.28, 0]
            let colors = alphas.map { color.withAlphaComponent($0).cgColor } as CFArray
            let locations: [CGFloat] = isSoft ? [0, 0.26, 0.63, 1] : [0, 0.28, 0.60, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations
            ) else { return }
            output.cgContext.drawRadialGradient(
                gradient, startCenter: CGPoint(x: 24, y: 24), startRadius: 0,
                endCenter: CGPoint(x: 24, y: 24), endRadius: 24, options: []
            )
        }.cgImage
    }

    private struct Particle {
        let depth: Int
        let origin: CGPoint
        let travel: CGPoint
        let diameter: CGFloat
        let alpha: Double
        let duration: TimeInterval
        let phase: Double

        func opacity(at progress: Double) -> Double {
            switch progress {
            case ..<0.06: 0
            case 0.06..<0.38: alpha * smooth((progress - 0.06) / 0.32)
            case 0.38..<0.62: alpha * (1 - 0.1 * smooth((progress - 0.38) / 0.24))
            case 0.62..<0.94: alpha * 0.9 * (1 - smooth((progress - 0.62) / 0.32))
            default: 0
            }
        }

        func position(at progress: Double, size: CGSize) -> CGPoint {
            let driftScale = 4.8
            let vector = CGVector(dx: travel.x * size.width * driftScale,
                                  dy: travel.y * size.height * driftScale)
            let inset = diameter / 2 + 5 * driftScale
            let start = CGPoint(
                x: min(max(origin.x * size.width - vector.dx / 2, inset),
                       max(inset, size.width - inset - vector.dx)),
                y: min(max(origin.y * size.height - vector.dy / 2, inset - vector.dy),
                       max(inset - vector.dy, size.height - inset))
            )
            let end = CGPoint(x: start.x + vector.dx, y: start.y + vector.dy)
            let control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - 5 * driftScale)
            let control2 = CGPoint(x: start.x + (end.x - start.x) * 0.70, y: end.y + 5 * driftScale)
            let t = CGFloat(progress)
            let inverse = 1 - t
            return CGPoint(
                x: inverse * inverse * inverse * start.x
                    + 3 * inverse * inverse * t * control1.x
                    + 3 * inverse * t * t * control2.x + t * t * t * end.x,
                y: inverse * inverse * inverse * start.y
                    + 3 * inverse * inverse * t * control1.y
                    + 3 * inverse * t * t * control2.y + t * t * t * end.y
            )
        }

        private func smooth(_ value: Double) -> Double {
            value * value * (3 - 2 * value)
        }
    }

    private static func makeParticles() -> [Particle] {
        var seed: UInt64 = 0x4C495445
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 32) / Double(UInt32.max)
        }
        var result: [Particle] = []
        for depth in 0..<3 {
            for _ in 0..<[84, 34, 10][depth] {
                let x = 0.04 + next() * 0.88
                let y = 0.84 - x * 0.31 + (next() + next() - 1) * 0.21
                result.append(Particle(
                    depth: depth,
                    origin: CGPoint(x: x, y: y),
                    travel: CGPoint(x: 0.025 + next() * 0.055, y: -0.012 - next() * 0.025),
                    diameter: [1.0, 2.4, 7.0][depth] + next() * [1.5, 3.7, 7.0][depth],
                    alpha: [0.22, 0.30, 0.18][depth] + next() * [0.22, 0.23, 0.13][depth],
                    duration: 32 + next() * 16,
                    phase: next()
                ))
            }
        }
        return result
    }

    private func color(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
