/*
* Use Double Passes to Avoid Depth Missing due to Geom Shader Problems.
*/

Shader "LowPoly/Water_2Pass_withDepth"
{
    Properties
    {
		_SpecColor("Specular Material Color", Color) = (1,1,1,1)
		_Shininess("Shininess", Float) = 10

		_WaveA("Wave A (dirx, dirZ, steepness, wavelength)", Vector) = (1,0,0.5,10)
		_WaveB("Wave B (dirx, dirZ, steepness, wavelength)", Vector) = (0,1,0.25,20)
		_WaveC("Wave C (dirx, dirZ, steepness, wavelength)", Vector) = (1,1,0.15,10)

		_DepthPercent("Water Depth Percent", Float) = 0.1
		_DepthClamp("Water Depth Clamp Threshold", Float) = -100

		_Distort("Earthy Distortion", Float) = -0.0000005
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		//Pass 1. Draw Water
        Pass
        {
            CGPROGRAM
			#pragma require geometry
            #pragma vertex vert
			#pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
			#include "UnityLightingCommon.cginc" // for _LightColor0

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 color : COLOR;
				float2 uv: TEXCOORD0;
			};

			struct v2g
			{
				float4 vertex : POSITION;
				float3 color : COLOR;

			};

			struct g2f
			{
				float4 pos : SV_POSITION;
				float3 color : COLOR;
				float4 posWorld : TEXCOORD0;
				float3 normalDir : TEXCOORD1;
			};

			uniform float _Shininess;

			float4 _WaveA, _WaveB, _WaveC;

			float _DepthPercent;
			float _DepthClamp;

			float _Distort;


			float3 GerstnerWave(float4 wave, float3 p)
			{
				float wavelength = wave.w;
				float k = 2 * UNITY_PI / wave.w;
				float f = k * (dot(normalize(wave.xy), p.xz) - sqrt(9.8 / k) * _Time.y);
				float cosf = cos(f);
				return float3(cosf, sin(f), cosf) * (wave.z / k);
			}

			v2g vert(VertexInput v)
			{
				v2g o;
				o.vertex = v.vertex;
				o.color = v.color;
				float3 worldSpaceVertex = mul(unity_ObjectToWorld, (v.vertex)).xyz;

				float waterDepth = min(v.uv.y, _DepthClamp);

				_WaveA.z *= waterDepth * _DepthPercent;
				_WaveB.z *= waterDepth * _DepthPercent;
				_WaveC.z *= waterDepth * _DepthPercent;

				o.vertex.xyz = v.vertex + GerstnerWave(_WaveA, worldSpaceVertex) +
					GerstnerWave(_WaveB, worldSpaceVertex) +
					GerstnerWave(_WaveC, worldSpaceVertex);

				//World Distortion
				float3 worldPos = _WorldSpaceCameraPos - mul(unity_ObjectToWorld, (o.vertex)).xyz;
				float distance2 = worldPos.x * worldPos.x + worldPos.z * worldPos.z;
				o.vertex.y += _Distort * distance2;

				return o;
			}

			[maxvertexcount(3)]
			void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;

				//NRM of this Tris
				float3 nrm = normalize(cross(input[1].vertex - input[0].vertex, input[2].vertex - input[0].vertex));

				for (int i = 0; i < 3; i++)
				{
					half2 tileableUv = mul(unity_ObjectToWorld, (input[i].vertex)).xz;

					o.pos = UnityObjectToClipPos(input[i].vertex);
					o.color = input[i].color;

					//UNITY_TRANSFER_FOG(o, o.pos);
					half3 worldNormal = UnityObjectToWorldNormal(nrm);
					float4x4 modelMatrix = unity_ObjectToWorld;
					float4x4 modelMatrixInverse = unity_WorldToObject;
					o.posWorld = mul(unity_ObjectToWorld, input[i].vertex);
					o.normalDir = normalize(mul(float4(nrm, 0.0), modelMatrixInverse).xyz);

					float3 worldPos = mul(unity_ObjectToWorld, input[i].vertex).xyz;
					float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

					triStream.Append(o);
				}
				triStream.RestartStrip();
			}

			half4 CalculateBaseColor(g2f input)
			{
				float3 normalDirection = normalize(input.normalDir);

				float3 viewDirection = normalize(
					_WorldSpaceCameraPos - input.posWorld.xyz);
				float3 lightDirection;
				float attenuation;

				if (0.0 == _WorldSpaceLightPos0.w) // directional light?
				{
					attenuation = 1.0; // no attenuation
					lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				}
				else // point or spot light
				{
					float3 vertexToLightSource =
						_WorldSpaceLightPos0.xyz - input.posWorld.xyz;
					float distance = length(vertexToLightSource);
					attenuation = 1.0 / distance; // linear attenuation 
					lightDirection = normalize(vertexToLightSource);
				}

				float3 ambientLighting =
					UNITY_LIGHTMODEL_AMBIENT.rgb * input.color.rgb;
					//UNITY_LIGHTMODEL_AMBIENT.rgb * _BaseColor.rgb;

				float3 diffuseReflection =
					attenuation * _LightColor0.rgb * input.color.rgb
					* max(0.0, dot(normalDirection, lightDirection));
					//attenuation * _LightColor0.rgb * _BaseColor.rgb
					//* max(0.0, dot(normalDirection, lightDirection));

				float3 specularReflection;
				if (dot(normalDirection, lightDirection) < 0.0)
					// light source on the wrong side?
				{
					specularReflection = float3(0.0, 0.0, 0.0);
					// no specular reflection
				}
				else
				{
					specularReflection = attenuation * _LightColor0.rgb  * _SpecColor.rgb * pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess);
				}

				return half4(ambientLighting + diffuseReflection + specularReflection, 1.0);
			}

			
			fixed4 frag(g2f i): SV_Target
			{
				return CalculateBaseColor(i);
				//depth = length(i.pos) / _ProjectionParams.y;
			}
            ENDCG
        }

		/*
		Pass 2, Cast Shadow to get Depth
		*/
		Pass
		{
			Tags { "LightMode" = "ShadowCaster" }
			CGPROGRAM
			#pragma require geometry
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "UnityLightingCommon.cginc" // for _LightColor0
			#pragma multi_compile_shadowcaster noshadowmask nodynlightmap nodirlightmap nolightmap

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 color : COLOR;
				float2 uv: TEXCOORD0;
			};

			struct v2g
			{
				float4 vertex : POSITION;
				float3 color : COLOR;

			};

			struct g2f
			{
				float4 pos : SV_POSITION;
			};

			uniform float4 _BaseColor;
			uniform float _Shininess;

			float4 _WaveA, _WaveB, _WaveC;

			float _DepthPercent;
			float _DepthClamp;
			float _Distort;

			float3 GerstnerWave(float4 wave, float3 p)
			{
				float wavelength = wave.w;
				float k = 2 * UNITY_PI / wave.w;
				float f = k * (dot(normalize(wave.xy), p.xz) - sqrt(9.8 / k) * _Time.y);
				float cosf = cos(f);
				return float3(cosf, sin(f), cosf) * (wave.z / k);
			}

			v2g vert(VertexInput v)
			{
				v2g o;
				o.vertex = v.vertex;
				o.color = v.color;
				float3 worldSpaceVertex = mul(unity_ObjectToWorld, (v.vertex)).xyz;

				float waterDepth = min(v.uv.y, _DepthClamp);
				_WaveA.z *= waterDepth * _DepthPercent;
				_WaveB.z *= waterDepth * _DepthPercent;
				_WaveC.z *= waterDepth * _DepthPercent;

				o.vertex.xyz = v.vertex + GerstnerWave(_WaveA, worldSpaceVertex) +
					GerstnerWave(_WaveB, worldSpaceVertex) +
					GerstnerWave(_WaveC, worldSpaceVertex);

				//World Distortion
				float3 worldPos = _WorldSpaceCameraPos - mul(unity_ObjectToWorld, (o.vertex)).xyz;
				float distance2 = worldPos.x * worldPos.x + worldPos.z * worldPos.z;
				o.vertex.y += _Distort * distance2;

				return o;
			}

			[maxvertexcount(3)]
			void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;

				//NRM of this Tris
				float3 nrm = normalize(cross(input[1].vertex - input[0].vertex, input[2].vertex - input[0].vertex));

				for (int i = 0; i < 3; i++)
				{
					half2 tileableUv = mul(unity_ObjectToWorld, (input[i].vertex)).xz;

					o.pos = UnityObjectToClipPos(input[i].vertex);
					triStream.Append(o);
				}
				triStream.RestartStrip();
			}

			

			fixed4 frag(g2f i) : SV_Target
			{
				return fixed4(0,0,0,0);
			}
		ENDCG
		}
    }
}
