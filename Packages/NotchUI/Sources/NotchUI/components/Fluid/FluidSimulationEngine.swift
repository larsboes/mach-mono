import Metal
import MetalKit

public final class FluidSimulationEngine: @unchecked Sendable {
    private let device: MTLDevice
    
    // Compute Pipeline States
    private var advectPipeline: MTLComputePipelineState!
    private var curlPipeline: MTLComputePipelineState!
    private var vorticityPipeline: MTLComputePipelineState!
    private var divergencePipeline: MTLComputePipelineState!
    private var clearPipeline: MTLComputePipelineState!
    private var pressurePipeline: MTLComputePipelineState!
    private var gradientPipeline: MTLComputePipelineState!
    private var splatPipeline: MTLComputePipelineState!
    
    // Render Pipeline State
    private var renderPipeline: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    
    // Texture buffers
    private struct DoubleBufferedTexture {
        var read: MTLTexture
        var write: MTLTexture
        mutating func swap() {
            let tmp = read
            read = write
            write = tmp
        }
    }
    
    private var velocity: DoubleBufferedTexture!
    private var dye: DoubleBufferedTexture!
    private var pressure: DoubleBufferedTexture!
    private var divergence: MTLTexture!
    private var curl: MTLTexture!
    
    // Queue for thread-safe deferred splats
    private struct SplatRequest {
        let x: Float
        let y: Float
        let dx: Float
        let dy: Float
        let color: SIMD3<Float>
        let radius: Float
    }
    private let splatQueue = OSAllocatedUnfairLock(initialState: [SplatRequest]())
    
    // Configs
    private var simWidth = 128
    private var simHeight = 128
    private var dyeWidth = 512
    private var dyeHeight = 512
    
    public var curlStrength: Float = 26.0
    public var velocityDissipation: Float = 0.22
    public var dyeDissipation: Float = 0.9
    public var splatForce: Float = 5200.0
    
    // MARK: - Init
    public init(device: MTLDevice) throws {
        self.device = device
        try compilePipelines()
    }
    
    private func compilePipelines() throws {
        let options = MTLCompileOptions()
        let library = try device.makeLibrary(source: FluidShaders.source, options: options)
        
        // Compute functions
        advectPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "advect")!)
        curlPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "curl")!)
        vorticityPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "vorticity")!)
        divergencePipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "divergence")!)
        clearPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "clear")!)
        pressurePipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "pressure")!)
        gradientPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "gradient")!)
        splatPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "splat")!)
        
        // Graphics pipeline description
        let renderDesc = MTLRenderPipelineDescriptor()
        renderDesc.vertexFunction = library.makeFunction(name: "fluidVertex")
        renderDesc.fragmentFunction = library.makeFunction(name: "fluidFragment")
        renderDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        renderPipeline = try device.makeRenderPipelineState(descriptor: renderDesc)
        
        // Create bilinear sampler
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDesc)
    }
    
    // MARK: - Resizing & Allocation
    public func resize(width: Int, height: Int, simScale: Float = 0.25) {
        let targetSimW = max(32, Int(Float(width) * simScale))
        let targetSimH = max(32, Int(Float(height) * simScale))
        
        // Only reallocate if dimensions changed materially
        if targetSimW == simWidth && targetSimH == simHeight && dyeWidth == width && dyeHeight == height {
            return
        }
        
        simWidth = targetSimW
        simHeight = targetSimH
        dyeWidth = width
        dyeHeight = height
        
        // Allocate Textures
        velocity = DoubleBufferedTexture(
            read: makeTexture(width: simWidth, height: simHeight, format: .rg16Float),
            write: makeTexture(width: simWidth, height: simHeight, format: .rg16Float)
        )
        pressure = DoubleBufferedTexture(
            read: makeTexture(width: simWidth, height: simHeight, format: .r16Float),
            write: makeTexture(width: simWidth, height: simHeight, format: .r16Float)
        )
        dye = DoubleBufferedTexture(
            read: makeTexture(width: dyeWidth, height: dyeHeight, format: .rgba16Float),
            write: makeTexture(width: dyeWidth, height: dyeHeight, format: .rgba16Float)
        )
        
        divergence = makeTexture(width: simWidth, height: simHeight, format: .r16Float)
        curl = makeTexture(width: simWidth, height: simHeight, format: .r16Float)
    }
    
    private func makeTexture(width: Int, height: Int, format: MTLPixelFormat) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        return device.makeTexture(descriptor: desc)!
    }
    
    // MARK: - Thread-Safe Splat Triggers
    public func triggerSplat(x: Float, y: Float, dx: Float, dy: Float, color: SIMD3<Float>, radius: Float) {
        let request = SplatRequest(x: x, y: y, dx: dx, dy: dy, color: color, radius: radius)
        splatQueue.withLock { queue in
            queue.append(request)
        }
    }
    
    // MARK: - Simulation Tick
    public func tick(commandQueue: MTLCommandQueue, dt: Float) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // 1. Process deferred splats
        let queuedSplats = splatQueue.withLock { queue -> [SplatRequest] in
            let copy = queue
            queue.removeAll()
            return copy
        }
        
        for request in queuedSplats {
            applySplat(commandBuffer: commandBuffer, request: request)
        }
        
        // 2. Step physics
        stepPhysics(commandBuffer: commandBuffer, dt: dt)
        
        commandBuffer.commit()
    }
    
    private func applySplat(commandBuffer: MTLCommandBuffer, request: SplatRequest) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(splatPipeline)
        
        let aspectRatio = Float(dyeWidth) / Float(dyeHeight)
        
        // A: Apply to velocity texture (inject force)
        encoder.setTexture(velocity.read, index: 0)
        encoder.setTexture(velocity.write, index: 1)
        
        var point = SIMD2<Float>(request.x, request.y)
        var forceColor = SIMD3<Float>(request.dx * splatForce, request.dy * splatForce, 0.0)
        var radius = request.radius
        var aspect = aspectRatio
        
        encoder.setBytes(&point, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
        encoder.setBytes(&forceColor, length: MemoryLayout<SIMD3<Float>>.size, index: 1)
        encoder.setBytes(&radius, length: MemoryLayout<Float>.size, index: 2)
        encoder.setBytes(&aspect, length: MemoryLayout<Float>.size, index: 3)
        
        dispatch(encoder: encoder, width: simWidth, height: simHeight)
        velocity.swap()
        
        // B: Apply to dye texture (inject color)
        encoder.setTexture(dye.read, index: 0)
        encoder.setTexture(dye.write, index: 1)
        
        var dyeColor = request.color
        encoder.setBytes(&dyeColor, length: MemoryLayout<SIMD3<Float>>.size, index: 1)
        
        dispatch(encoder: encoder, width: dyeWidth, height: dyeHeight)
        dye.swap()
        
        encoder.endEncoding()
    }
    
    private func stepPhysics(commandBuffer: MTLCommandBuffer, dt: Float) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        var currentDt = dt
        
        // 1. Compute Curl
        encoder.setComputePipelineState(curlPipeline)
        encoder.setTexture(velocity.read, index: 0)
        encoder.setTexture(curl, index: 1)
        dispatch(encoder: encoder, width: simWidth, height: simHeight)
        
        // 2. Apply Vorticity Confinement
        encoder.setComputePipelineState(vorticityPipeline)
        encoder.setTexture(velocity.read, index: 0)
        encoder.setTexture(curl, index: 1)
        encoder.setTexture(velocity.write, index: 2)
        
        var strength = curlStrength
        encoder.setBytes(&strength, length: MemoryLayout<Float>.size, index: 0)
        encoder.setBytes(&currentDt, length: MemoryLayout<Float>.size, index: 1)
        dispatch(encoder: encoder, width: simWidth, height: simHeight)
        velocity.swap()
        
        // 3. Compute Divergence
        encoder.setComputePipelineState(divergencePipeline)
        encoder.setTexture(velocity.read, index: 0)
        encoder.setTexture(divergence, index: 1)
        dispatch(encoder: encoder, width: simWidth, height: simHeight)
        
        // 4. Clear/decay pressure slightly
        encoder.setComputePipelineState(clearPipeline)
        encoder.setTexture(pressure.read, index: 0)
        encoder.setTexture(pressure.write, index: 1)
        var decay: Float = 0.8
        encoder.setBytes(&decay, length: MemoryLayout<Float>.size, index: 0)
        dispatch(encoder: encoder, width: simWidth, height: simHeight)
        pressure.swap()
        
        // 5. Solve pressure (Jacobi relaxation, 20 iterations)
        encoder.setComputePipelineState(pressurePipeline)
        encoder.setTexture(divergence, index: 1)
        
        for _ in 0..<20 {
            encoder.setTexture(pressure.read, index: 0)
            encoder.setTexture(pressure.write, index: 2)
            dispatch(encoder: encoder, width: simWidth, height: simHeight)
            pressure.swap()
        }
        
        // 6. Gradient Subtract (projection step)
        encoder.setComputePipelineState(gradientPipeline)
        encoder.setTexture(pressure.read, index: 0)
        encoder.setTexture(velocity.read, index: 1)
        encoder.setTexture(velocity.write, index: 2)
        dispatch(encoder: encoder, width: simWidth, height: simHeight)
        velocity.swap()
        
        // 7. Advect Velocity
        encoder.setComputePipelineState(advectPipeline)
        encoder.setTexture(velocity.read, index: 0)
        encoder.setTexture(velocity.read, index: 1)
        encoder.setTexture(velocity.write, index: 2)
        encoder.setBytes(&currentDt, length: MemoryLayout<Float>.size, index: 0)
        var velDiss = velocityDissipation
        encoder.setBytes(&velDiss, length: MemoryLayout<Float>.size, index: 1)
        dispatch(encoder: encoder, width: simWidth, height: simHeight)
        velocity.swap()
        
        // 8. Advect Dye (Color)
        encoder.setTexture(velocity.read, index: 0)
        encoder.setTexture(dye.read, index: 1)
        encoder.setTexture(dye.write, index: 2)
        encoder.setBytes(&currentDt, length: MemoryLayout<Float>.size, index: 0)
        var colorDiss = dyeDissipation
        encoder.setBytes(&colorDiss, length: MemoryLayout<Float>.size, index: 1)
        dispatch(encoder: encoder, width: dyeWidth, height: dyeHeight)
        dye.swap()
        
        encoder.endEncoding()
    }
    
    private func dispatch(encoder: MTLComputeCommandEncoder, width: Int, height: Int) {
        let w = advectPipeline.threadExecutionWidth
        let h = advectPipeline.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        
        let threadgroups = MTLSize(
            width: (width + w - 1) / w,
            height: (height + h - 1) / h,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
    }
    
    // MARK: - Graphics Render Render
    public func draw(view: MTKView, renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer, kickPulse: Float) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        encoder.setRenderPipelineState(renderPipeline)
        encoder.setFragmentTexture(dye.read, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        
        var boost: Float = 1.0 + kickPulse
        encoder.setFragmentBytes(&boost, length: MemoryLayout<Float>.size, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        encoder.endEncoding()
    }
}

// MARK: - Thread-safe Spinlock (using Swift OSAllocatedUnfairLock if OS support allows, fallback under iOS/macOS)
import os

private final class OSAllocatedUnfairLock<State>: @unchecked Sendable {
    private let lock = os_unfair_lock_t.allocate(capacity: 1)
    private var state: State
    
    init(initialState: State) {
        lock.initialize(to: os_unfair_lock())
        state = initialState
    }
    
    deinit {
        lock.deallocate()
    }
    
    func withLock<R>(_ block: (inout State) -> R) -> R {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return block(&state)
    }
}
