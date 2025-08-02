//
//  Shaders.metal
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 02/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// ==========================================================
// Global sampler reused by all shaders
// ==========================================================
constexpr sampler fluidSampler(
                               filter::nearest,
                               address::clamp_to_edge,
                               coord::normalized
                               );

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 textureCoorinates [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoorinates;
};

// ==========================================================
// Vertex shader
// ==========================================================
vertex VertexOut vertexShader(constant VertexIn* vertexArray [[buffer(0)]],
                              unsigned int vid [[vertex_id]]) {
    VertexIn v = vertexArray[vid];
    VertexOut out;
    out.position = float4(v.position, 0.0, 1.0);
    out.textureCoorinates = v.textureCoorinates;
    return out;
}

// ==========================================================
// Visualization
// ==========================================================
fragment half4 visualizeScalarOld1(VertexOut in [[stage_in]],
                                   texture2d<float, access::sample> tex [[texture(0)]]) {
    float4 color = tex.sample(fluidSampler, in.textureCoorinates);
    float3 baseColor = float3(0.8, 0.8, 0.8);
    return half4(half3(baseColor * abs(color.xxx)), 1.0);
}

fragment half4 visualizeScalarOld2(VertexOut in [[stage_in]],
                                   texture2d<float, access::sample> tex [[texture(0)]]) {
    float4 color = tex.sample(fluidSampler, in.textureCoorinates);
    float3 baseColor = float3(0.2, 0.4, 1.0);
    return half4(half3(baseColor * abs(color.xxx)), 1.0);
}

fragment half4 visualizeScalar(VertexOut in [[stage_in]],
                               texture2d<float, access::sample> tex [[texture(0)]]) {
    half4 sampled = half4(tex.sample(fluidSampler, in.textureCoorinates));
    half3 baseColor = half3(0.2h, 0.4h, 1.0h);
    return half4(baseColor * abs(sampled.xxx), 1.0h);
}

fragment half4 visualizeVector(VertexOut in [[stage_in]],
                               texture2d<float, access::sample> tex [[texture(0)]]) {
    half4 sampled = half4(tex.sample(fluidSampler, in.textureCoorinates));
    return half4(0.5h) + 0.5h * sampled;
}

// ==========================================================
// BufferData
// ==========================================================
struct BufferData {
    float2 positions[5];
    float2 impulses[5];
    float2 impulseScalar;
    float2 offsets;
    float2 screenSize;
    float inkRadius;
};

// ==========================================================
// Utility
// ==========================================================
inline float2 bilerpFrag(texture2d<float> texture, float2 p, float2 screenSize) {
    float2 base = floor(p - 0.5) + 0.5;
    float4 ij = float4(base, base + 1.0);
    float4 uv = ij / screenSize.xyxy;
    
    float2 d11 = texture.sample(fluidSampler, uv.xy).xy;
    float2 d21 = texture.sample(fluidSampler, uv.zy).xy;
    float2 d12 = texture.sample(fluidSampler, uv.xw).xy;
    float2 d22 = texture.sample(fluidSampler, uv.zw).xy;
    
    float2 a = p - base;
    return mix(mix(d11, d21, a.x), mix(d12, d22, a.x), a.y);
}

inline half gaussSplat(half2 p, half r) {
    return exp(-dot(p, p) / r);
}

// ==========================================================
// Forces
// ==========================================================
fragment half2 applyForceVector(VertexOut in [[stage_in]],
                                texture2d<float, access::sample> input [[texture(0)]],
                                constant BufferData &buf [[buffer(0)]]) {
    
    half2 screenSize = half2(buf.screenSize);
    half radius = half(buf.inkRadius);
    
    float2 sampleVal = input.sample(fluidSampler, in.textureCoorinates).xy;
    half2 final = half2(sampleVal);
    
    for (int i = 0; i < 5; ++i) {
        half2 impulse = half2(buf.impulses[i]);
        half2 location = half2(buf.positions[i]);
        half valid = (location.x + location.y) > 0 ? 1.0h : 0.0h;
        
        half2 coords = location - half2(in.textureCoorinates) * screenSize;
        final += valid * (impulse * gaussSplat(coords, radius));
    }
    return final;
}

fragment half2 applyForceScalar(VertexOut in [[stage_in]],
                                texture2d<float, access::sample> input [[texture(0)]],
                                constant BufferData &buf [[buffer(0)]]) {
    
    half2 impulseScalar = half2(buf.impulseScalar);
    half2 screenSize = half2(buf.screenSize);
    half radius = half(buf.inkRadius);
    
    float2 sampleVal = input.sample(fluidSampler, in.textureCoorinates).xy;
    half2 final = half2(sampleVal);
    
    for (int i = 0; i < 5; ++i) {
        half2 location = half2(buf.positions[i]);
        half valid = (location.x + location.y) > 0 ? 1.0h : 0.0h;
        
        half2 coords = location - half2(in.textureCoorinates) * screenSize;
        final += valid * (impulseScalar * gaussSplat(coords, radius));
    }
    return final;
}

// ==========================================================
// Fluid simulation steps
// ==========================================================
fragment half2 advect(VertexOut in [[stage_in]],
                      texture2d<float, access::sample> velocity [[texture(0)]],
                      texture2d<float, access::sample> advected [[texture(1)]],
                      constant BufferData &buf [[buffer(0)]]) {
    
    float2 screenSize = buf.screenSize;
    float2 uv = (in.textureCoorinates * screenSize)
    - velocity.sample(fluidSampler, in.textureCoorinates).xy;
    
    return 0.998h * half2(bilerpFrag(advected, uv, screenSize));
}

fragment half2 divergence(VertexOut in [[stage_in]],
                          texture2d<float, access::sample> velocity [[texture(0)]],
                          constant BufferData &buf [[buffer(0)]]) {
    
    float2 uv = in.textureCoorinates;
    float2 off = buf.offsets;
    float2 dx = float2(off.x, 0.0);
    float2 dy = float2(0.0, off.y);
    
    float vl = velocity.sample(fluidSampler, uv - dx).x;
    float vr = velocity.sample(fluidSampler, uv + dx).x;
    float vb = velocity.sample(fluidSampler, uv - dy).y;
    float vt = velocity.sample(fluidSampler, uv + dy).y;
    
    float div = 0.5 * (vr - vl + vt - vb);
    return half2(div, 0.0);
}

fragment half2 jacobi(VertexOut in [[stage_in]],
                      texture2d<float, access::sample> x [[texture(0)]],
                      texture2d<float, access::sample> b [[texture(1)]],
                      constant BufferData &buf [[buffer(0)]]) {
    
    float2 uv = in.textureCoorinates;
    float2 off = buf.offsets;
    float2 dx = float2(off.x, 0.0);
    float2 dy = float2(0.0, off.y);
    
    float xl = x.sample(fluidSampler, uv - dx).x;
    float xr = x.sample(fluidSampler, uv + dx).x;
    float xb = x.sample(fluidSampler, uv - dy).x;
    float xt = x.sample(fluidSampler, uv + dy).x;
    float bc = b.sample(fluidSampler, uv).x;
    
    return half2((xl + xr + xb + xt - bc) * 0.25, 0.0);
}

fragment half2 vorticity(VertexOut in [[stage_in]],
                         texture2d<float, access::sample> velocity [[texture(0)]],
                         constant BufferData &buf [[buffer(0)]]) {
    
    float2 uv = in.textureCoorinates;
    float2 off = buf.offsets;
    float2 dx = float2(off.x, 0.0);
    float2 dy = float2(0.0, off.y);
    
    float vl = velocity.sample(fluidSampler, uv - dx).y;
    float vr = velocity.sample(fluidSampler, uv + dx).y;
    float vb = velocity.sample(fluidSampler, uv - dy).x;
    float vt = velocity.sample(fluidSampler, uv + dy).x;
    
    return half2(0.5 * ((vr - vl) - (vt - vb)), 0.0);
}

fragment half2 vorticityConfinement(VertexOut in [[stage_in]],
                                    texture2d<float, access::sample> velocity [[texture(0)]],
                                    texture2d<float, access::sample> vort [[texture(1)]],
                                    constant BufferData &buf [[buffer(0)]]) {
    
    float2 screenSize = buf.screenSize;
    float2 uv = in.textureCoorinates;
    float2 off = buf.offsets;
    float2 dx = float2(off.x, 0.0);
    float2 dy = float2(0.0, off.y);
    
    float vl = vort.sample(fluidSampler, uv - dx).x;
    float vr = vort.sample(fluidSampler, uv + dx).x;
    float vb = vort.sample(fluidSampler, uv - dy).x;
    float vt = vort.sample(fluidSampler, uv + dy).x;
    float vc = vort.sample(fluidSampler, uv).x;
    
    float2 force = 0.5 * float2(fabs(vt) - fabs(vb), fabs(vr) - fabs(vl));
    force *= rsqrt(max(2.4414e-4, dot(force, force))) * float2(0.4, 0.4) * vc;
    force.y *= -1.0;
    
    float2 velc = velocity.sample(fluidSampler, uv).xy;
    float2 result = velc + force;
    
    float2 grid = uv * screenSize;
    if (grid.x <= 1 || grid.y <= 1 || grid.x >= screenSize.x - 1 || grid.y >= screenSize.y - 1)
        result = float2(0.0);
    
    return half2(result);
}

fragment half2 gradient(VertexOut in [[stage_in]],
                        texture2d<float, access::sample> p [[texture(0)]],
                        texture2d<float, access::sample> w [[texture(1)]],
                        constant BufferData &buf [[buffer(0)]]) {
    
    float2 screenSize = buf.screenSize;
    float2 uv = in.textureCoorinates;
    float2 off = buf.offsets;
    float2 dx = float2(off.x, 0.0);
    float2 dy = float2(0.0, off.y);
    
    float pl = p.sample(fluidSampler, uv - dx).x;
    float pr = p.sample(fluidSampler, uv + dx).x;
    float pb = p.sample(fluidSampler, uv - dy).x;
    float pt = p.sample(fluidSampler, uv + dy).x;
    
    float2 grad = 0.5 * float2(pr - pl, pt - pb);
    float2 wc = w.sample(fluidSampler, uv).xy;
    float2 result = wc - grad;
    
    float2 grid = uv * screenSize;
    if (grid.x <= 1 || grid.y <= 1 || grid.x >= screenSize.x - 1 || grid.y >= screenSize.y - 1)
        result = float2(0.0);
    
    return half2(result);
}
