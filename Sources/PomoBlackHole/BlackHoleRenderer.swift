import AppKit
import MetalKit

struct RendererState {
    var progress: Float = 0
    var completion: Float = 0
    var liveDistortion = false
    var windowFrame = CGRect.zero
    var screenFrame = CGRect.zero
}

private struct GPUUniforms {
    var progress: Float
    var completion: Float
    var liveDistortion: Float
    var padding: Float = 0
    var windowFrame: SIMD4<Float>
    var screenFrame: SIMD4<Float>
}

final class BlackHoleRenderer: NSObject, MTKViewDelegate, @unchecked Sendable {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?
    private weak var capture: ScreenCaptureManager?
    private let stateLock = NSLock()
    private var state = RendererState()

    @MainActor
    init?(view: MTKView, capture: ScreenCaptureManager) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        self.capture = capture
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 30

        do {
            let library = try device.makeLibrary(source: Self.shader, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }
        super.init()
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        view.delegate = self
    }

    func update(_ newState: RendererState) {
        stateLock.withLock { state = newState }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

        let snapshot = stateLock.withLock { state }
        encoder.setRenderPipelineState(pipeline)

        var retainedTexture: CVMetalTexture?
        var desktopTexture: MTLTexture?
        if snapshot.liveDistortion,
           let pixelBuffer = capture?.copyLatestPixelBuffer(),
           let textureCache {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            var cvTexture: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(
                nil, textureCache, pixelBuffer, nil, .bgra8Unorm,
                width, height, 0, &cvTexture
            )
            retainedTexture = cvTexture
            if let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture) {
                desktopTexture = texture
            }
        }
        var uniforms = GPUUniforms(
            progress: snapshot.progress,
            completion: snapshot.completion,
            liveDistortion: desktopTexture == nil ? 0 : 1,
            windowFrame: SIMD4(
                Float(snapshot.windowFrame.origin.x),
                Float(snapshot.windowFrame.origin.y),
                Float(snapshot.windowFrame.width),
                Float(snapshot.windowFrame.height)
            ),
            screenFrame: SIMD4(
                Float(snapshot.screenFrame.origin.x),
                Float(snapshot.screenFrame.origin.y),
                Float(snapshot.screenFrame.width),
                Float(snapshot.screenFrame.height)
            )
        )
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GPUUniforms>.stride, index: 0)
        if let desktopTexture {
            encoder.setFragmentTexture(desktopTexture, index: 0)
        }

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        _ = retainedTexture
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;

    struct VOut { float4 position [[position]]; float2 uv; };
    struct State {
        float progress;
        float completion;
        float liveDistortion;
        float pad;
        float4 windowFrame;
        float4 screenFrame;
    };

    vertex VOut vertex_main(uint id [[vertex_id]]) {
        float2 p[4] = { {-1,-1}, {1,-1}, {-1,1}, {1,1} };
        float2 u[4] = { {0,1}, {1,1}, {0,0}, {1,0} };
        return { float4(p[id], 0, 1), u[id] };
    }

    float hash(float2 p) {
        return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
    }

    fragment float4 fragment_main(VOut in [[stage_in]],
                                  constant State &s [[buffer(0)]],
                                  texture2d<float> desktop [[texture(0)]]) {
        constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear);
        // MTKView texture coordinates are top-left based, while AppKit window
        // coordinates are bottom-left based. Keep all lens math in AppKit space,
        // and flip only once when converting the final point to texture space.
        float2 windowLocal = float2(in.uv.x, 1.0 - in.uv.y);
        float2 p = windowLocal * 2.0 - 1.0;
        p.x *= s.windowFrame.z / max(1.0, s.windowFrame.w);
        float r = length(p);
        float angle = atan2(p.y, p.x);
        float growth = mix(0.18, 0.72, smoothstep(0.0, 1.0, s.progress));
        growth *= (1.0 - s.completion * 0.82);
        float horizon = growth * 0.34;
        float influence = growth;
        float feather = 1.0 - smoothstep(influence * 0.82, influence, r);
        if (feather <= 0.001) discard_fragment();

        float3 color = float3(0.0);
        float alpha = feather;
        if (s.liveDistortion > 0.5) {
            float lensRange = max(0.001, influence - horizon);
            float lensPosition = clamp((influence - r) / lensRange, 0.0, 1.0);
            float pull = pow(lensPosition, 3.0);
            // Keep the angular pull constant throughout the timer. A lower
            // exponent lets the spiral remain visible farther from the core.
            float twist = pow(pull, 1.08) * 1.42;
            float2 warped = float2(cos(twist) * p.x - sin(twist) * p.y,
                                   sin(twist) * p.x + cos(twist) * p.y);
            warped *= 1.0 + pull * 0.82;
            float2 local = (warped / float2(s.windowFrame.z / max(1.0, s.windowFrame.w), 1.0) + 1.0) * 0.5;
            float2 screenPoint = s.windowFrame.xy + local * s.windowFrame.zw;
            float2 screenUV = float2(
                (screenPoint.x - s.screenFrame.x) / max(1.0, s.screenFrame.z),
                1.0 - (screenPoint.y - s.screenFrame.y) / max(1.0, s.screenFrame.w)
            );
            color = desktop.sample(smp, screenUV).rgb;
            color *= 1.0 - pull * 0.82;
            color *= smoothstep(horizon * 0.78, horizon * 1.12, r);
        }

        float3 emission = float3(0.0);
        float disk = exp(-pow((r - horizon * 1.68) / max(0.014, growth * 0.065), 2.0));
        float turbulence = 0.82 + 0.18 * sin(angle * 5.0 - s.progress * 13.0);
        float approaching = pow(0.5 + 0.5 * cos(angle - 0.65), 2.2);
        float3 coolDisk = float3(0.62, 0.055, 0.008);
        float3 hotDisk = float3(1.0, 0.58, 0.12);
        float3 diskColor = mix(coolDisk, hotDisk, approaching);
        float diskEnergy = disk * turbulence * (0.38 + approaching * 0.72);
        emission += diskColor * diskEnergy * (1.0 + s.completion * 1.2);

        float lens = exp(-pow((r - horizon * 1.13) / 0.012, 2.0));
        emission += mix(float3(0.20, 0.32, 0.58), float3(0.92, 0.66, 0.28), approaching) * lens * 0.18;
        if (r < horizon * 0.78) color = float3(0.0);

        float stars = step(0.996, hash(floor(in.uv * 210.0 + s.progress * 7.0)));
        emission += diskColor * stars * feather * smoothstep(horizon * 1.2, influence, r) * 0.45;
        float flash = s.completion * exp(-pow((r - growth * (0.5 + s.completion)) / 0.04, 2.0));
        emission += float3(0.52, 0.68, 1.0) * flash * 1.35;
        color += emission / (1.0 + max(float3(0.0), emission) * 0.42);
        alpha = max(alpha * (s.liveDistortion > 0.5 ? 1.0 : 0.55), max(disk, lens));
        return float4(color, clamp(alpha, 0.0, 1.0));
    }
    """
}
