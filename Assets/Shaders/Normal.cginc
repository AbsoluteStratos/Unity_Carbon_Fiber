#define FLT_MIN         1.175494351e-38 // Minimum representable positive floating-point number
#define HALF_MIN 6.103515625e-5  // 2^-14, the same value for 10, 11 and 16-bit: https://www.khronos.org/opengl/wiki/Small_Float_Formats

// Normalize that account for vectors with zero length
float3 SafeNormalize(float3 inVec)
{
    float dp3 = max(FLT_MIN, dot(inVec, inVec));
    return inVec * rsqrt(dp3);
}

half3 SafeNormalize(half3 inVec)
{
    half dp3 = max(HALF_MIN, dot(inVec, inVec));
    return inVec * rsqrt(dp3);
}

float3 TransformTangentToWorld(float3 dirTS, float3x3 worldToTangent)
{
    // Use transpose transformation to go from tangent to world as the matrix is orthogonal
    return mul(dirTS, worldToTangent);
}

float3 TransformWorldToTangent(float3 dirWS, float3x3 worldToTangent)
{
    return mul(worldToTangent, dirWS);
}


void Unity_NormalFromHeight_Tangent_float(float In, float Strength, float3 Position, float3x3 TangentMatrix, out float3 Out)
{

    #if defined(SHADER_STAGE_RAY_TRACING) && defined(RAYTRACING_SHADER_GRAPH_DEFAULT)
    #error 'Normal From Height' node is not supported in ray tracing, please provide an alternate implementation, relying for instance on the 'Raytracing Quality' keyword
    #endif
    float3 worldDerivativeX = ddx(Position);
    float3 worldDerivativeY = ddy(Position);

    float3 crossX = cross(TangentMatrix[2].xyz, worldDerivativeX);
    float3 crossY = cross(worldDerivativeY, TangentMatrix[2].xyz);
    float d = dot(worldDerivativeX, crossY);
    float sgn = d < 0.0 ? (-1.0f) : 1.0f;
    float surface = sgn / max(0.000000000000001192093f, abs(d));

    float dHdx = ddx(In);
    float dHdy = ddy(In);
    float3 surfGrad = surface * (dHdx*crossY + dHdy*crossX);
    Out = SafeNormalize(TangentMatrix[2].xyz - (Strength * surfGrad));
    Out = TransformWorldToTangent(Out, TangentMatrix);
}


void NormalBlend(float3 A, float3 B, out float3 Out)
{
    Out = SafeNormalize(float3(A.rg + B.rg, A.b * B.b));
}

void NormalFromHeight(NormalData IN, float3 worldPos, float Bump, float Strength, out float3 Out){
    float3x3 TangentMatrix = float3x3(IN.worldTangent, IN.worldBiTangent, IN.worldNormal);
    float3 Position = worldPos;
    Unity_NormalFromHeight_Tangent_float(Bump, Strength, Position, TangentMatrix, Out);
}