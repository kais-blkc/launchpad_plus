import AppKit

/// Жест «щипок четырьмя/пятью пальцами» через приватный MultitouchSupport.
/// Сводим пальцы — открыть, разводим — закрыть. Системный жест Launchpad/«Приложения»
/// нужно отключить в Настройки → Трекпад → Дополнительные жесты.
final class TrackpadGesture {
    var onPinchIn: (() -> Void)?
    var onPinchOut: (() -> Void)?

    private typealias Callback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Register = @convention(c) (UnsafeMutableRawPointer, Callback) -> Void
    private typealias StartStop = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias Stop = @convention(c) (UnsafeMutableRawPointer) -> Void

    private static let touchStride = 96      // sizeof(MTTouch)
    private static let normXOffset = 32      // normalized.position.x
    private static let normYOffset = 36

    private static let minFingers = 4
    private static let pinchInRatio: Float = 0.72
    private static let pinchOutRatio: Float = 1.35

    // Состояние жеста; callback вызывается с приватного потока, наружу — через main.
    fileprivate static var shared: TrackpadGesture?
    private var baseline: Float = 0
    private var lastCount: Int32 = 0
    private var fired = false

    private var devices: CFArray?
    private var handle: UnsafeMutableRawPointer?

    func start() {
        TrackpadGesture.shared = self
        guard let lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let createSym = dlsym(lib, "MTDeviceCreateList"),
              let registerSym = dlsym(lib, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(lib, "MTDeviceStart")
        else { NSLog("Launchpad+: MultitouchSupport недоступен"); return }
        handle = lib

        let create = unsafeBitCast(createSym, to: CreateList.self)
        let register = unsafeBitCast(registerSym, to: Register.self)
        let startDevice = unsafeBitCast(startSym, to: StartStop.self)

        guard let list = create()?.takeRetainedValue() else { return }
        devices = list
        for i in 0..<CFArrayGetCount(list) {
            guard let device = CFArrayGetValueAtIndex(list, i) else { continue }
            let ptr = UnsafeMutableRawPointer(mutating: device)
            register(ptr, { _, touches, count, _, _ in
                TrackpadGesture.shared?.handle(touches: touches, count: count)
                return 0
            })
            startDevice(ptr, 0)
        }

        // После сна устройства перестают присылать кадры — перезапускаем.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.restart() }
    }

    private func restart() {
        stopDevices()
        start()
    }

    private func stopDevices() {
        guard let lib = handle, let list = devices, let stopSym = dlsym(lib, "MTDeviceStop") else { return }
        let stop = unsafeBitCast(stopSym, to: Stop.self)
        for i in 0..<CFArrayGetCount(list) {
            if let device = CFArrayGetValueAtIndex(list, i) { stop(UnsafeMutableRawPointer(mutating: device)) }
        }
        devices = nil
    }

    // MARK: - Распознавание

    fileprivate func handle(touches: UnsafeMutableRawPointer?, count: Int32) {
        guard let touches, count >= Int32(Self.minFingers) else {
            lastCount = count; baseline = 0; fired = false
            return
        }

        var xs: [Float] = [], ys: [Float] = []
        for i in 0..<Int(count) {
            let base = touches + i * Self.touchStride
            xs.append(base.load(fromByteOffset: Self.normXOffset, as: Float.self))
            ys.append(base.load(fromByteOffset: Self.normYOffset, as: Float.self))
        }
        let cx = xs.reduce(0, +) / Float(count), cy = ys.reduce(0, +) / Float(count)
        var spread: Float = 0
        for i in 0..<xs.count { spread += ((xs[i] - cx) * (xs[i] - cx) + (ys[i] - cy) * (ys[i] - cy)).squareRoot() }
        spread /= Float(count)

        // Число пальцев поменялось — отсчёт начинаем заново, чтобы посадка пальцев не считалась щипком.
        if count != lastCount || baseline == 0 {
            lastCount = count; baseline = spread; return
        }
        guard !fired, baseline > 0.01 else { return }

        let ratio = spread / baseline
        if ratio < Self.pinchInRatio {
            fired = true
            DispatchQueue.main.async { self.onPinchIn?() }
        } else if ratio > Self.pinchOutRatio {
            fired = true
            DispatchQueue.main.async { self.onPinchOut?() }
        }
    }
}
