import SwiftUI
import MetalKit
import Metal

public struct FluidVisualizerView: View {
    let isPlaying: Bool
    let audioLevel: Float
    let isBeatActive: Bool
    let palette: [SIMD3<Float>]
    
    @State private var isPaused = false
    @State private var lastDragLocation: CGPoint? = nil
    @State private var lastDragTime: Date = Date()
    
    // Shared graphics queue
    @State private var engineHolder: EngineHolder? = nil
    
    public init(isPlaying: Bool, audioLevel: Float, isBeatActive: Bool, palette: [SIMD3<Float>]) {
        self.isPlaying = isPlaying
        self.audioLevel = audioLevel
        self.isBeatActive = isBeatActive
        self.palette = palette
    }
    
    public var body: some View {
        GeometryReader { geo in
            FluidMTKViewRepresentable(
                isPlaying: isPlaying,
                audioLevel: audioLevel,
                isBeatActive: isBeatActive,
                isPaused: isPaused,
                palette: palette,
                engineHolder: engineHolder
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(location: value.location, in: geo.size)
                    }
                    .onEnded { _ in
                        lastDragLocation = nil
                    }
            )
        }
        .onAppear {
            isPaused = false
            if engineHolder == nil {
                if let device = MTLCreateSystemDefaultDevice() {
                    engineHolder = EngineHolder(device: device)
                }
            }
        }
        .onDisappear {
            isPaused = true
        }
    }
    
    private func handleDrag(location: CGPoint, in size: CGSize) {
        guard let engine = engineHolder?.engine, size.width > 0, size.height > 0 else { return }
        
        let now = Date()
        let dt = Float(now.timeIntervalSince(lastDragTime))
        
        let normX = Float(location.x / size.width)
        let normY = Float(location.y / size.height)
        
        if let last = lastDragLocation {
            let dx = Float((location.x - last.x) / size.width) / max(0.001, dt)
            let dy = Float((location.y - last.y) / size.height) / max(0.001, dt)
            
            // Limit impulse to avoid crazy blowups
            let speed = sqrt(dx*dx + dy*dy)
            let maxSpeed: Float = 3.0
            let scale = speed > maxSpeed ? maxSpeed / speed : 1.0
            
            // Random color from palette
            let color = palette.randomElement() ?? SIMD3<Float>(1.0, 1.0, 1.0)
            
            // Inject force and dye color
            engine.triggerSplat(
                x: normX,
                y: 1.0 - normY, // Flip coordinate space for fluid physics
                dx: dx * scale * 0.05,
                dy: -dy * scale * 0.05,
                color: color * 1.5,
                radius: 0.0015
            )
        }
        
        lastDragLocation = location
        lastDragTime = now
    }
}

// MARK: - Engine Holder
// Simple helper object to hold the compilation states across re-renders
private final class EngineHolder: @unchecked Sendable {
    let engine: FluidSimulationEngine?
    let commandQueue: MTLCommandQueue?
    
    init(device: MTLDevice) {
        self.engine = try? FluidSimulationEngine(device: device)
        self.commandQueue = device.makeCommandQueue()
    }
}

// MARK: - MTKView Representable (macOS NSViewRepresentable)
private struct FluidMTKViewRepresentable: NSViewRepresentable {
    let isPlaying: Bool
    let audioLevel: Float
    let isBeatActive: Bool
    let isPaused: Bool
    let palette: [SIMD3<Float>]
    let engineHolder: EngineHolder?
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = engineHolder?.engine != nil ? mtkView.device : nil
        
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
        }
        
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.01, blue: 0.04, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false
        mtkView.autoResizeDrawable = true
        mtkView.preferredFramesPerSecond = 120
        mtkView.delegate = context.coordinator
        
        context.coordinator.setup(view: mtkView)
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.isPaused = isPaused || !isPlaying
        context.coordinator.update(
            audioLevel: audioLevel,
            isBeatActive: isBeatActive,
            palette: palette
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(holder: engineHolder)
    }
    
    // MARK: - Coordinator
    final class Coordinator: NSObject, MTKViewDelegate {
        private let holder: EngineHolder?
        private var audioLevel: Float = 0.0
        private var isBeatActive = false
        private var palette: [SIMD3<Float>] = []
        private var lastTime = Date()
        private var beatSplatCooldown = false
        private var ambientSplatAccumulator: TimeInterval = 0
        
        init(holder: EngineHolder?) {
            self.holder = holder
        }
        
        func setup(view: MTKView) {
            guard let engine = holder?.engine else { return }
            engine.resize(width: Int(view.drawableSize.width), height: Int(view.drawableSize.height))
        }
        
        func update(audioLevel: Float, isBeatActive: Bool, palette: [SIMD3<Float>]) {
            self.audioLevel = audioLevel
            self.palette = palette
            
            // Audio beat trigger splat
            if isBeatActive && !beatSplatCooldown {
                beatSplatCooldown = true
                triggerBeatSplat()
                
                // Beat cooldown (80ms)
                Task {
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    self.beatSplatCooldown = false
                }
            }
        }
        
        private func triggerBeatSplat() {
            guard let engine = holder?.engine else { return }
            
            // Splat at random locations near the center
            let rx = Float.random(in: 0.35...0.65)
            let ry = Float.random(in: 0.35...0.65)
            
            // Direction outward from center
            let dx = (rx - 0.5) * 0.8
            let dy = (ry - 0.5) * 0.8
            
            // Select random colors from the mode's active palette
            let color = palette.randomElement() ?? SIMD3<Float>(0.5, 0.2, 0.8)
            
            engine.triggerSplat(
                x: rx,
                y: ry,
                dx: dx,
                dy: dy,
                color: color * (1.2 + audioLevel * 1.5),
                radius: 0.003 + audioLevel * 0.003
            )
        }
        
        // MARK: - MTKViewDelegate
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            guard let engine = holder?.engine else { return }
            engine.resize(width: Int(size.width), height: Int(size.height))
        }
        
        func draw(in view: MTKView) {
            guard let engine = holder?.engine,
                  let commandQueue = holder?.commandQueue,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor
            else { return }
            
            let now = Date()
            let dt = Float(now.timeIntervalSince(lastTime))
            lastTime = now
            
            // Cap delta time to prevent large steps when frame rate drops
            let stepDt = min(0.033, dt > 0 ? dt : 0.008)
            
            // Run physics tick
            engine.tick(commandQueue: commandQueue, dt: stepDt)
            ambientSplatAccumulator += TimeInterval(stepDt)
            if ambientSplatAccumulator > ambientInterval {
                ambientSplatAccumulator = 0
                triggerAmbientSplat()
            }
            
            // Render to drawable screen FBO
            if let commandBuffer = commandQueue.makeCommandBuffer() {
                engine.draw(
                    view: view,
                    renderPassDescriptor: renderPassDescriptor,
                    commandBuffer: commandBuffer,
                    kickPulse: isBeatActive ? audioLevel * 0.5 : 0.0
                )
                
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
        }

        private var ambientInterval: TimeInterval {
            audioLevel > 0.08 ? 0.18 : 0.42
        }

        private func triggerAmbientSplat() {
            guard let engine = holder?.engine else { return }

            let time = Float(Date().timeIntervalSince1970)
            let x = 0.5 + 0.32 * sin(time * 0.38)
            let y = 0.5 + 0.26 * sin(time * 0.27 + 2.1)
            let dx = 0.025 * cos(time * 0.38)
            let dy = 0.025 * cos(time * 0.27 + 2.1)
            let color = palette.randomElement() ?? SIMD3<Float>(0.4, 0.18, 0.85)
            let level = max(0.035, audioLevel)

            engine.triggerSplat(
                x: x,
                y: y,
                dx: dx,
                dy: dy,
                color: color * (0.12 + level * 0.32),
                radius: 0.0018 + level * 0.002
            )
        }
    }
}
