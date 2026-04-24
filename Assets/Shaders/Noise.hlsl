#ifndef NOISE_HLSL_INCLUDED
#define NOISE_HLSL_INCLUDED

void random_2to1(float2 input, out float rnd) 
{
    uint2 v = (uint2)(int2)round(input);
    v.y ^= 1103515245U;
    v.x += v.y;
    v.x *= v.y;
    v.x ^= v.x >> 5u;
    v.x *= 0x27d4eb2du;
    rnd = (v.x >> 8) * (1.0 / float(0x00ffffff));
}
void random_2to2(float2 input, out float2 rnd) 
{
    uint2 v = (uint2)(int2)round(input);
    v.y ^= 1103515245U;
    v.x += v.y;
    v.x *= v.y;
    v.x ^= v.x >> 5u;
    v.x *= 0x27d4eb2du;
    v.y ^= (v.x << 3u);
    rnd = (v >> 8) * (1.0 / float(0x00ffffff));
} 

// GRADIENT 
float2 Direction(float2 p) 
{
	float x; random_2to1(p, x);
	return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
}

void GradientNoise_float(float2 UV, float2 Scale, out float Out) 
{
	float2 p = UV * Scale.xy;
	float2 ip = floor(p);
	float2 fp = frac(p);
	float d00 = dot(Direction(ip), fp);
	float d01 = dot(Direction(ip + float2(0,1)), fp - float2(0,1));
	float d10 = dot(Direction(ip + float2(1,0)), fp - float2(1,0));
	float d11 = dot(Direction(ip + float2(1,1)), fp - float2(1,1));
	fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
	Out = lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x) + 0.5;
}
 
#endif //NOISE_HLSL_INCLUDED
