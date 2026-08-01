import Foundation

public enum FluidShaders {
    public static let source = """
#include <metal_stdlib>
using namespace metal;

// Bilinear interpolation helper
float4 bilinearSample(texture2d<float, access::read> tex, float2 uv, float2 size) {
    float2 f = uv * size - 0.5;
    int2 i00 = int2(floor(f));
    int2 i11 = i00 + 1;
    
    // Clamp to bounds
    int2 size_i = int2(size);
    i00 = clamp(i00, int2(0), size_i - 1);
    i11 = clamp(i11, int2(0), size_i - 1);
    
    float2 weight = fract(f);
    
    float4 t00 = tex.read(uint2(i00.x, i00.y));
    float4 t10 = tex.read(uint2(i11.x, i00.y));
    float4 t01 = tex.read(uint2(i00.x, i11.y));
    float4 t11 = tex.read(uint2(i11.x, i11.y));
    
    return mix(mix(t00, t10, weight.x), mix(t01, t11, weight.x), weight.y);
}

// 1. Advection Kernel
kernel void advect(
    texture2d<float, access::read> uVelocity [[texture(0)]],
    texture2d<float, access::read> uSource [[texture(1)]],
    texture2d<float, access::write> uTarget [[texture(2)]],
    constant float &dt [[buffer(0)]],
    constant float &dissipation [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uTarget.get_width() || gid.y >= uTarget.get_height()) return;
    
    float2 size = float2(uTarget.get_width(), uTarget.get_height());
    float2 uv = (float2(gid) + 0.5) / size;
    
    // Read velocity at current location
    float2 vel = uVelocity.read(gid).xy;
    
    // Backtrace uv coordinate
    float2 uvBack = uv - dt * vel / size;
    
    // Sample source at backtraced coordinate
    float4 value = bilinearSample(uSource, uvBack, size);
    
    // Apply dissipation
    float4 finalValue = value / (1.0 + dissipation * dt);
    
    uTarget.write(finalValue, gid);
}

// 2. Curl Kernel
kernel void curl(
    texture2d<float, access::read> uVelocity [[texture(0)]],
    texture2d<float, access::write> uCurl [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint w = uVelocity.get_width();
    uint h = uVelocity.get_height();
    if (gid.x >= w || gid.y >= h) return;
    
    uint2 xL = uint2(clamp(int(gid.x) - 1, 0, int(w) - 1), gid.y);
    uint2 xR = uint2(clamp(int(gid.x) + 1, 0, int(w) - 1), gid.y);
    uint2 xB = uint2(gid.x, clamp(int(gid.y) - 1, 0, int(h) - 1));
    uint2 xT = uint2(gid.x, clamp(int(gid.y) + 1, 0, int(h) - 1));
    
    float L = uVelocity.read(xL).y;
    float R = uVelocity.read(xR).y;
    float B = uVelocity.read(xB).x;
    float T = uVelocity.read(xT).x;
    
    float val = 0.5 * (R - L - T + B);
    uCurl.write(float4(val, 0.0, 0.0, 1.0), gid);
}

// 3. Vorticity Confinement Kernel
kernel void vorticity(
    texture2d<float, access::read> uVelocity [[texture(0)]],
    texture2d<float, access::read> uCurl [[texture(1)]],
    texture2d<float, access::write> uTarget [[texture(2)]],
    constant float &curlVal [[buffer(0)]],
    constant float &dt [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint w = uVelocity.get_width();
    uint h = uVelocity.get_height();
    if (gid.x >= w || gid.y >= h) return;
    
    uint2 xL = uint2(clamp(int(gid.x) - 1, 0, int(w) - 1), gid.y);
    uint2 xR = uint2(clamp(int(gid.x) + 1, 0, int(w) - 1), gid.y);
    uint2 xB = uint2(gid.x, clamp(int(gid.y) - 1, 0, int(h) - 1));
    uint2 xT = uint2(gid.x, clamp(int(gid.y) + 1, 0, int(h) - 1));
    
    float L = abs(uCurl.read(xL).x);
    float R = abs(uCurl.read(xR).x);
    float B = abs(uCurl.read(xB).x);
    float T = abs(uCurl.read(xT).x);
    float C = uCurl.read(gid).x;
    
    float2 force = 0.5 * float2(T - B, R - L);
    
    // Safeguard division
    float len = length(force) + 0.0001;
    force /= len;
    
    force *= curlVal * C;
    force.y *= -1.0;
    
    float2 vel = uVelocity.read(gid).xy + force * dt;
    vel = clamp(vel, float2(-1000.0), float2(1000.0));
    
    uTarget.write(float4(vel, 0.0, 1.0), gid);
}

// 4. Divergence Kernel
kernel void divergence(
    texture2d<float, access::read> uVelocity [[texture(0)]],
    texture2d<float, access::write> uDivergence [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint w = uVelocity.get_width();
    uint h = uVelocity.get_height();
    if (gid.x >= w || gid.y >= h) return;
    
    uint2 xL = uint2(clamp(int(gid.x) - 1, 0, int(w) - 1), gid.y);
    uint2 xR = uint2(clamp(int(gid.x) + 1, 0, int(w) - 1), gid.y);
    uint2 xB = uint2(gid.x, clamp(int(gid.y) - 1, 0, int(h) - 1));
    uint2 xT = uint2(gid.x, clamp(int(gid.y) + 1, 0, int(h) - 1));
    
    float L = uVelocity.read(xL).x;
    float R = uVelocity.read(xR).x;
    float B = uVelocity.read(xB).y;
    float T = uVelocity.read(xT).y;
    
    // Boundary conditions
    float2 C = uVelocity.read(gid).xy;
    if (gid.x == 0) L = -C.x;
    if (gid.x == w - 1) R = -C.x;
    if (gid.y == 0) B = -C.y;
    if (gid.y == h - 1) T = -C.y;
    
    float div = 0.5 * (R - L + T - B);
    uDivergence.write(float4(div, 0.0, 0.0, 1.0), gid);
}

// 5. Clear Kernel
kernel void clear(
    texture2d<float, access::read> uSource [[texture(0)]],
    texture2d<float, access::write> uTarget [[texture(1)]],
    constant float &value [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uTarget.get_width() || gid.y >= uTarget.get_height()) return;
    
    float4 val = uSource.read(gid);
    uTarget.write(value * val, gid);
}

// 6. Jacobi Pressure Solver Kernel
kernel void pressure(
    texture2d<float, access::read> uPressure [[texture(0)]],
    texture2d<float, access::read> uDivergence [[texture(1)]],
    texture2d<float, access::write> uTarget [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint w = uPressure.get_width();
    uint h = uPressure.get_height();
    if (gid.x >= w || gid.y >= h) return;
    
    uint2 xL = uint2(clamp(int(gid.x) - 1, 0, int(w) - 1), gid.y);
    uint2 xR = uint2(clamp(int(gid.x) + 1, 0, int(w) - 1), gid.y);
    uint2 xB = uint2(gid.x, clamp(int(gid.y) - 1, 0, int(h) - 1));
    uint2 xT = uint2(gid.x, clamp(int(gid.y) + 1, 0, int(h) - 1));
    
    float L = uPressure.read(xL).x;
    float R = uPressure.read(xR).x;
    float B = uPressure.read(xB).x;
    float T = uPressure.read(xT).x;
    float div = uDivergence.read(gid).x;
    
    float p = 0.25 * (L + R + B + T - div);
    uTarget.write(float4(p, 0.0, 0.0, 1.0), gid);
}

// 7. Gradient Subtraction Kernel
kernel void gradient(
    texture2d<float, access::read> uPressure [[texture(0)]],
    texture2d<float, access::read> uVelocity [[texture(1)]],
    texture2d<float, access::write> uTarget [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint w = uPressure.get_width();
    uint h = uPressure.get_height();
    if (gid.x >= w || gid.y >= h) return;
    
    uint2 xL = uint2(clamp(int(gid.x) - 1, 0, int(w) - 1), gid.y);
    uint2 xR = uint2(clamp(int(gid.x) + 1, 0, int(w) - 1), gid.y);
    uint2 xB = uint2(gid.x, clamp(int(gid.y) - 1, 0, int(h) - 1));
    uint2 xT = uint2(gid.x, clamp(int(gid.y) + 1, 0, int(h) - 1));
    
    float L = uPressure.read(xL).x;
    float R = uPressure.read(xR).x;
    float B = uPressure.read(xB).x;
    float T = uPressure.read(xT).x;
    
    float2 vel = uVelocity.read(gid).xy;
    vel -= float2(R - L, T - B) * 0.5;
    
    uTarget.write(float4(vel, 0.0, 1.0), gid);
}

// 8. Splat Kernel
kernel void splat(
    texture2d<float, access::read> uTarget [[texture(0)]],
    texture2d<float, access::write> uWrite [[texture(1)]],
    constant float2 &point [[buffer(0)]],
    constant float3 &color [[buffer(1)]],
    constant float &radius [[buffer(2)]],
    constant float &aspectRatio [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uWrite.get_width() || gid.y >= uWrite.get_height()) return;
    
    float2 size = float2(uWrite.get_width(), uWrite.get_height());
    float2 uv = (float2(gid) + 0.5) / size;
    
    float2 p = uv - point;
    p.x *= aspectRatio;
    
    // Gaussian falloff
    float d2 = dot(p, p);
    float splatVal = exp(-d2 / radius);
    
    float3 base = uTarget.read(gid).xyz;
    float3 result = base + splatVal * color;
    
    uWrite.write(float4(result, 1.0), gid);
}

// 9. Graphics Shaders for Render pass
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut fluidVertex(uint vid [[vertex_id]]) {
    // Standard full-screen quad vertex shader
    const float2 positions[4] = {
        float2(-1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0)
    };
    
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y; // Flip Y for Metal texture coordinates
    return out;
}

fragment float4 fluidFragment(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> uTexture [[texture(0)]],
    sampler s [[sampler(0)]],
    constant float &uBoost [[buffer(0)]]
) {
    float4 dyeColor = uTexture.sample(s, in.uv);
    float3 c = dyeColor.rgb * uBoost;
    
    // Vignette
    float d = distance(in.uv, float2(0.5));
    float vignette = smoothstep(0.95, 0.45, d) * 0.35 + 0.65;
    c *= vignette;
    
    return float4(c, 1.0);
}
"""
}
