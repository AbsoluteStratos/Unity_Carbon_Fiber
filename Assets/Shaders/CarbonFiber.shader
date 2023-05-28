
// Adopted from: https://www.youtube.com/watch?v=1qh2J4oQzy0
Shader "Custom/Week19-CarbonFiber"
{
    Properties
    {
        [Toggle] _Toggle("Color Settings", Float) = 1
        _VerticalWeaveColor("Vertical Color", Color) = (0.08, 0.08, 0.08, 1)
        _HorizontalWeaveColor("Horizontal Color", Color) = (0.15, 0.15, 0.15, 1)
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Glossiness ("Glossiness", Range(0,1)) = 0.5
        _ClearCoat_Smoothness ("ClearCoat Smoothness", Range(0, 1)) = 0.6
		_ClearCoat_Metallic("ClearCoat Metallic",Range(0, 1)) = 0.5
        _WeaveFloor("Weave Shadow Floor", Range(0,1)) = 0.0

        [Toggle] _Toggle("Geometric Settings", Float) = 1
        _HorizontalScale ("Horizontal Scale", float) = 5.0
        _VerticalScale ("Vertical Scale", float) = 5.0
        _NormalScale("Normal Scale", Range(0., 0.1)) = 0.05

        
        _HorizontalNoiseScale("Horizontal Brush Effect Scale", float) = 500
        _VerticalNoiseScale("Vertical Brush Effect Scale", float) = 500
        _BrushStrength("Brush Effect Normal Strength", Range(0, 0.05)) = 0.005
        _Rotation ("Rotation", Range(0, 3.1415)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert finalcolor:clearCoat

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0
        
        sampler2D _MainTex;

        struct Input
        {
            float2 texUV;
            float3 worldTangent;
            float3 worldBiTangent;
            float3 worldPos;
            float3 worldNormal; 
            float3 viewDir;
            float3 shapeNormal; 
            INTERNAL_DATA
        };

        struct NormalData
        {
            float3 worldNormal;
            float3 worldTangent;
            float3 worldBiTangent;
        };

        half _Glossiness, _Metallic, _ClearCoat_Smoothness, _ClearCoat_Metallic;
        fixed4 _VerticalWeaveColor, _HorizontalWeaveColor;
        float _HorizontalScale, _VerticalScale, _Rotation, _WeaveFloor, _NormalScale, _BrushStrength, _HorizontalNoiseScale, _VerticalNoiseScale;
        
        #include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#include "UnityShaderUtilities.cginc"
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		#include "UnityPBSLighting.cginc"
		#include "AutoLight.cginc"

        #include "Voroino.cginc"
        #include "Normal.cginc"
        #include "GradientNoise.cginc"
        #include "ClearCoat.cginc"

        void vert (inout appdata_tan v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            // o.vertex = UnityObjectToClipPos(v.vertex);
            o.texUV = v.texcoord;
            float3 normal = UnityObjectToWorldNormal(v.normal);
            o.shapeNormal = UnityObjectToWorldNormal(v.normal);
            o.worldTangent = UnityObjectToWorldDir(v.tangent);
            o.worldBiTangent = cross(o.worldTangent, normal);
        }

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Stitch checker board
            float2 uv1 = frac(float2(1*_HorizontalScale*IN.texUV.x, 1*_VerticalScale*IN.texUV.y));
            float2 uv2 = frac(float2(2*_HorizontalScale*IN.texUV.x, 2*_VerticalScale*IN.texUV.y));
            float2 uv3 = frac(float2(4*_HorizontalScale*IN.texUV.x, 4*_VerticalScale*IN.texUV.y));
            float ymask = 0.5*step(0.5, uv1.y) + 0.25*step(0.5, uv2.y); // Vertical offsets for horizonal weaves
            float xmask = 0.5*step(0.5, uv1.x) + 0.25*step(0.5, uv2.x); // Horizonal offsets for vertical weaves

            float2 uv = frac(float2(_HorizontalScale*IN.texUV.x + ymask, 2*_VerticalScale*IN.texUV.y)); // For horizontal weave
            float2 uvv = frac(float2(2*_HorizontalScale*IN.texUV.x, _VerticalScale*IN.texUV.y + xmask)); // For vertical weave
            float mask = step(0.5, uv.x);
            // Use voronoi with no randomness to get the gradients of the weaves
            float vorOutx, vorCells;
            float2 vorUV = float2(uv.x, 0);
            Voronoi(vorUV, 0.0, 2.0, 0.0, vorOutx, vorCells);

            float vorOuty;
            vorUV = float2(0, uvv.y);
            Voronoi(vorUV, 0.0, 2.0, 0.0, vorOuty, vorCells);

            // Combine weaves
            float weave = lerp(vorOutx, vorOuty, mask);
            weave = lerp(_WeaveFloor, 1.0, weave); // Apply floor (basically min shadow)

             // Add some color
            float3 col = weave*lerp(_HorizontalWeaveColor, _VerticalWeaveColor, mask);

            // Set up normals
            NormalData ND;
            // See bottom of: https://docs.unity3d.com/Manual/SL-SurfaceShaders.html
            ND.worldNormal = WorldNormalVector (IN, o.Normal);
            ND.worldTangent = IN.worldTangent;
            ND.worldBiTangent = IN.worldBiTangent;
            float3 wnormal;
            NormalFromHeight(ND, IN.worldPos, weave, _NormalScale, wnormal);

            float brushx, brushy;
            GradientNoise(IN.texUV, float2(_HorizontalNoiseScale, 1), brushx);
            GradientNoise(IN.texUV, float2(1, _VerticalNoiseScale), brushy);

            float brush = 0.01*lerp(brushy, brushx, mask);
            float3 bnormal;
            NormalFromHeight(ND, IN.worldPos, brush, _BrushStrength, bnormal);
            float3 normal;
            NormalBlend(wnormal, bnormal, normal);
            // uv = frac(uv);
            // uv.x = uv.x + 0.25*(1-step(0.25, uv.y)) + 0.25*step(0.25, uv.y)*(1-step(0.5, uv.y)) 
            //         + 0.25*step(0.5, uv.y)*(1-step(0.75, uv.y)) + 0.25*step(0.75, uv.y);

            // float cboard = step(0.25, uv.x)*step(0.25, uv.y) + 
            //     (1-step(0.25, uv.x))*(1-step(0.25, uv.y))*step(0.5, uv.x)*step(0.5, uv.y) +
            //     (1-step(0.5, uv.x))*(1-step(0.5, uv.y))*step(0.75, uv.x)*step(0.75, uv.y) +
            //     step(0.75, uv.x)*step(0.75, uv.y);


            // Output!
            o.Albedo = col;
            o.Normal = normal;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = 1.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
