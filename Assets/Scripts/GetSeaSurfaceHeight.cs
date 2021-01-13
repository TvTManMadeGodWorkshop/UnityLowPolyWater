using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GetSeaSurfaceHeight: MonoBehaviour
{
    public static GetSeaSurfaceHeight singleton;

    public Vector4 wave1;
    public Vector4 wave2;
    public Vector4 wave3;

    private void Start()
    {
        singleton = this;
    }

    Vector3 GerstnerWave(Vector4 wave, Vector3 p)
    {
        float wavelength = wave.w;
        float k = 2 * Mathf.PI / wave.w;
        float f = k * (Vector2.Dot((new Vector2(wave.x, wave.y)).normalized, new Vector2(p.x, p.z)) - Mathf.Sqrt(9.8f / k) * Time.time);
        float cosf = Mathf.Cos(f);
        return new Vector3(cosf, Mathf.Sin(f), cosf) * (wave.z / k);
    }

    public float GetHeight(Vector3 pos)
    {
        Vector3 result = GerstnerWave(wave1, pos) + GerstnerWave(wave2, pos) + GerstnerWave(wave3, pos);
        return result.y;
    }
}
