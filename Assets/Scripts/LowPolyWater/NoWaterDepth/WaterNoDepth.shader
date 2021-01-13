/*
* 因为我们在LowPoly下使用了GeometryShader，所以需要使用两个Pass来避免深度问题。
*/

Shader "LowPoly/Water_2Pass_NoWaterDepth"
{
    Properties
    {
		//水面颜色
		_BaseColor("Base color", COLOR) = (.54, .95, .99, 0.5)
		//反光颜色
		_SpecColor("Specular Material Color", Color) = (1,1,1,1)
		//水面反光度
		_Shininess("Shininess", Float) = 10

		//三个GerstnerWave波叠加。如有需要可增加/删减。
		_WaveA("Wave A (dirX, dirZ, steepness, wavelength)", Vector) = (1,0,0.5,10)
		_WaveB("Wave B (dirX, dirZ, steepness, wavelength)", Vector) = (0,1,0.25,20)
		_WaveC("Wave C (dirX, dirZ, steepness, wavelength)", Vector) = (1,1,0.15,10)
		
		//星球曲率
		_Distort("Earthy Distortion", Float) = -0.0000005
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		//Pass 1. 绘制水面
        Pass
        {
            CGPROGRAM
			#pragma require geometry
            #pragma vertex vert
			#pragma geometry geom
            #pragma fragment frag
            //#pragma multi_compile_fog

            #include "UnityCG.cginc"
			#include "UnityLightingCommon.cginc" // for _LightColor0
			
			//VertexShader（顶点着色器）输入
			struct VertexInput
			{
				float4 vertex : POSITION;
			};
			
			//VertexShader（顶点着色器）输出至GeometryShader（几何着色器）
			struct v2g
			{
				float4 vertex : POSITION;
			};

			//GeometryShader（几何着色器）输出至FragmentShader（片元着色器）
			struct g2f
			{
				float4 pos : SV_POSITION;
				float4 posWorld : TEXCOORD0;
				float3 normalDir : TEXCOORD1;
			};

			uniform float4 _BaseColor;
			uniform float _Shininess;
			float4 _WaveA, _WaveB, _WaveC;
			float _Distort;

			//Gerstner波函数。输入wave和位置p，输出Gerstner扭曲增量
			float3 GerstnerWave(float4 wave, float3 p)
			{
				float wavelength = wave.w;
				float k = 2 * UNITY_PI / wave.w;
				float f = k * (dot(normalize(wave.xy), p.xz) - sqrt(9.8 / k) * _Time.y);
				float cosf = cos(f);
				return float3(cosf, sin(f), cosf) * (wave.z / k);
			}

			//Vertex Shader（顶点着色器）
			v2g vert(VertexInput v)
			{
				v2g o;
				o.vertex = v.vertex;
				//顶点由局部坐标转换为世界坐标
				float3 worldSpaceVertex = mul(unity_ObjectToWorld, (v.vertex)).xyz;
				//叠三个GerstnerWave。
				o.vertex.xyz = v.vertex + GerstnerWave(_WaveA, worldSpaceVertex) +
					GerstnerWave(_WaveB, worldSpaceVertex) +
					GerstnerWave(_WaveC, worldSpaceVertex);

				//地球曲率扭曲（可选）
				float3 worldPos = _WorldSpaceCameraPos - mul(unity_ObjectToWorld, (o.vertex)).xyz;
				float distance2 = worldPos.x * worldPos.x + worldPos.z * worldPos.z;
				o.vertex.y += _Distort * distance2;

				return o;
			}

			//Geometry Shader（几何着色器），以三角形为单位。在此计算法线。
			[maxvertexcount(3)]
			void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;

				//计算此三角形的法线
				float3 nrm = normalize(cross(input[1].vertex - input[0].vertex, input[2].vertex - input[0].vertex));

				for (int i = 0; i < 3; i++)
				{
					//在此将顶点从局部坐标转换为NDC坐标（？）
					o.pos = UnityObjectToClipPos(input[i].vertex);
					//计算世界坐标系坐标
					o.posWorld = mul(unity_ObjectToWorld, input[i].vertex);
					//计算世界坐标系法线
					o.normalDir = normalize(mul(float4(nrm, 0.0), unity_WorldToObject).xyz);
					//把此顶点输入TriangleStream
					triStream.Append(o);
				}
				triStream.RestartStrip();
			}

			//计算水面颜色。
			//Ebru Dogan https://assetstore.unity.com/packages/tools/particles-effects/lowpoly-water-107563
			half4 CalculateBaseColor(g2f input)
			{
				//水面法线方向
				float3 normalDirection = normalize(input.normalDir);
				//视角方向
				float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);
				float3 lightDirection;
				float attenuation;

				//是谁照亮了水面？
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
					UNITY_LIGHTMODEL_AMBIENT.rgb * _BaseColor.rgb;

				float3 diffuseReflection =
					attenuation * _LightColor0.rgb * _BaseColor.rgb
					* max(0.0, dot(normalDirection, lightDirection));

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

			//Fragment Shader（片元着色器），返回颜色
			fixed4 frag(g2f i): SV_Target
			{
				return CalculateBaseColor(i);
			}
            ENDCG
        }

		/*
		Pass 2, 用ShadowPass再绘制一次，输出深度
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
			};

			struct v2g
			{
				float4 vertex : POSITION;
			};

			struct g2f
			{
				float4 pos : SV_POSITION;
			};

			uniform float4 _BaseColor;
			uniform float _Shininess;

			float4 _WaveA, _WaveB, _WaveC;
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
				float3 worldSpaceVertex = mul(unity_ObjectToWorld, (v.vertex)).xyz;

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
