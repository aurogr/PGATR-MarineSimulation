
void DistortUV_float(float2 UV, float Amount, out float2 Out) 
{
	float time = _Time.y;

	UV.y += Amount * 0.01 * (sin(UV.x * 3.5 + time * 0.35) + sin(UV.x * 4.6 + time * 1.05) + sin(UV.x * 7.3 + time * 0.45)) / 3.0;
	UV.x += Amount * 0.12 * (sin(UV.y * 4.0 + time * 0.50) + sin(UV.y * 6.8 + time * 0.75) + sin(UV.y * 11.3 + time * 0.2)) / 3.0;
	UV.y += Amount * 0.12 * (sin(UV.x * 4.2 + time * 0.64) + sin(UV.x * 6.3 + time * 1.65) + sin(UV.x * 8.2 + time * 0.45)) / 3.0;

	Out = UV;
}

half3 RGBtoHSV(half3 In)
{
    half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    half4 P = lerp(half4(In.bg, K.wz), half4(In.gb, K.xy), step(In.b, In.g));
    half4 Q = lerp(half4(P.xyw, In.r), half4(In.r, P.yzx), step(P.x, In.r));
    half D = Q.x - min(Q.w, Q.y);
    half E = 1e-10;
    return half3(abs(Q.z + (Q.w - Q.y) / (6.0 * D + E)), D / (Q.x + E), Q.x);
}

half3 HSVtoRGB(half3 In)
{
    half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    half3 P = abs(frac(In.xxx + K.xyz) * 6.0 - K.www);
    return In.z * lerp(K.xxx, saturate(P - K.xxx), In.y);
}

void HSVLerp_half(half4 A, half4 B, half T, out half4 Out)
{
    A.xyz = RGBtoHSV(A.xyz);
    B.xyz = RGBtoHSV(B.xyz);

    half t = T; // used to lerp alpha, needs to remain unchanged

    half hue;
    half d = B.x - A.x; // hue difference

    if (A.x > B.x)
    {
        half temp = B.x;
        B.x = A.x;
        A.x = temp;

        d = -d;
        T = 1 - T;
    }

    if (d > 0.5)
    {
        A.x = A.x + 1;
        hue = (A.x + T * (B.x - A.x)) % 1;
    }

    if (d <= 0.5) hue = A.x + T * d;

    half sat = A.y + T * (B.y - A.y);
    half val = A.z + T * (B.z - A.z);
    half alpha = A.w + t * (B.w - A.w);

    half3 rgb = HSVtoRGB(half3(hue, sat, val));

    Out = half4(rgb, alpha);
}

void NormalFromHeight_float3(float IN, float Strenght, float3 Position, float3x3 TangentMatrix, out float3 Out)
{
    //position en WS
    float3 worldDX = ddx(Position);
    float3 worldDY = ddy(Position);

    //cross en TS
    float3 crossX = cross(TangentMatrix[2].xyz, worldDX);
    float3 crossY = cross(worldDY, TangentMatrix[2].xyz);
    float d = dot(worldDX, crossY);
    float sgn = d < 0.0 ? (-1.0f) : 1.0f;
    float surface = sgn / max(0.00006103515625f, abs(d));

    float dHdx = ddx(IN);
    float dHdy = ddy(IN);

    float3 surfGrad = surface * (dHdx * crossY + dHdy * crossX);

    Out = SafeNormalize(TangentMatrix[2].xyz - (Strenght * surfGrad));
    Out = TransformWorldToTangent(Out, TangentMatrix);
}
