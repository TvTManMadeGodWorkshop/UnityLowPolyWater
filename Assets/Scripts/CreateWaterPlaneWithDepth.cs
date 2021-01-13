
/*
 * 创建LowPoly水面模型，并将深度和颜色写入模型的uv0和Color。
 * 调用CreateSeaMeshWithDepth函数创建水面模型。
 * debug时，可在编辑器界面右键调用DebugCreateWithDepth直接生成模型
 */

using UnityEngine;

public class CreateWaterPlaneWithDepth : MonoBehaviour
{
    [Tooltip("模型所使用的Mesh Filter")]
    public MeshFilter meshFilter;

    [Tooltip("X轴上四边面数量")]
    public int x;
    [Tooltip("Z轴上四边面数量")]
    public int z;
    [Tooltip("每个四边面的大小")]
    public float size;
    [Tooltip("水面颜色随深度变化")]
    public Gradient waterDepthColor;
    [Tooltip("最大水深")]
    public float maxWaterDepth;

    /// <summary>
    /// 创建水面模型，不包含水的深度。用于深海区域的水面
    /// </summary>
    /// <param name="segX">X轴上四边面数量</param>
    /// <param name="segZ">Z轴上四边面数量</param>
    /// <param name="quadSize">每个四边面的大小</param>
    /// <returns></returns>
    public Mesh CreateSeaMeshWithDepth(int segX, int segZ, float quadSize)
    {
        Mesh mesh = new Mesh();

        //Unity模型顶点Index默认为16位。如模型顶点数大于2^16=65535，则应当使用32位Index。
        if (segX * segZ >= 65535)
        {
            mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        }

        //新建三角形数组。长度 = 三角形个数 * 3 = 四边面个数 * 6。
        int[] tris = new int[segX * segZ * 6];
        //新建顶点数组。注意LowPoly下，相邻顶点是分开的（因为法线不一样）！
        Vector3[] verts = new Vector3[segX * segZ * 6];
        //新建uv数组
        Vector2[] uvs = new Vector2[segX * segZ * 6];
        //新建顶点颜色数组
        Color[] colors = new Color[segX * segZ * 6];

        for (int i = 0; i < segX; i++)
        {
            for (int j = 0; j < segZ; j++)
            {
                int index = (i * segZ + j) * 6;

                //计算四个角的顶点坐标
                Vector3 v00 = new Vector3(i * size, 0, j * size);
                Vector3 v01 = new Vector3(i * size, 0, (j + 1) * size);
                Vector3 v10 = new Vector3((i + 1) * size, 0, j * size);
                Vector3 v11 = new Vector3((i + 1) * size, 0, (j + 1) * size);
                //写入顶点数组
                verts[index] = v00;
                verts[index + 1] = v01;
                verts[index + 2] = v11;
                verts[index + 3] = v00;
                verts[index + 4] = v11;
                verts[index + 5] = v10;
                //写入三角形数组
                tris[index] = index;
                tris[index + 1] = index + 1;
                tris[index + 2] = index + 2;
                tris[index + 3] = index + 3;
                tris[index + 4] = index + 4;
                tris[index + 5] = index + 5;

                //计算深度
                float depth00 = GetDepth(v00);
                float depth01 = GetDepth(v01);
                float depth10 = GetDepth(v10);
                float depth11 = GetDepth(v11);

                //深度写入UV0.y
                uvs[index].y = depth00;
                uvs[index + 1].y = depth01;
                uvs[index + 2].y = depth11;
                uvs[index + 3].y = depth00;
                uvs[index + 4].y = depth11;
                uvs[index + 5].y = depth10;

                //计算海水颜色
                Color col00 = GetColor(depth00);
                Color col01 = GetColor(depth01);
                Color col10 = GetColor(depth10);
                Color col11 = GetColor(depth11);

                //写入颜色数组
                colors[index] = col00;
                colors[index + 1] = col01;
                colors[index + 2] = col11;
                colors[index + 3] = col00;
                colors[index + 4] = col11;
                colors[index + 5] = col10;
            }
        }

        mesh.SetVertices(verts);
        mesh.SetTriangles(tris, 0);
        //写入uv0数组，即TEXCOORD0。反正我们也没用到贴图……
        mesh.SetUVs(0, uvs);
        mesh.SetColors(colors);
        mesh.Optimize();
        return mesh;
    }

    /// <summary>
    /// 获取海水深度，使用Raycast。注意返回的深度是正的！
    /// </summary>
    /// <param name="pos">位置</param>
    public float GetDepth(Vector3 pos)
    {
        //如果Raycast没有命中，则证明海底非常深，深度为默认最深的数值。
        float waterDepth = maxWaterDepth;

        //从空中100米向下发射Raycast，然后距离再减100。这样就能避免离岸近的地方显示为深水区了！
        if (Physics.Raycast(pos + Vector3.up * 100, Vector3.down, out RaycastHit info, maxWaterDepth + 100))
        {
            waterDepth = Mathf.Max(info.distance - 100, 0);
        }
        return waterDepth;
    }

    /// <summary>
    /// 根据深度获取颜色
    /// </summary>
    /// <param name="waterDepth">深度</param>
    public Color GetColor(float waterDepth)
    {
        return waterDepthColor.Evaluate(waterDepth / maxWaterDepth);
    }

    /// <summary>
    /// DEBUG用。
    /// </summary>
    [ContextMenu("DEBUG Create With Water Depth")]
    private void DebugCreateWithDepth()
    {
        meshFilter.mesh = CreateSeaMeshWithDepth(x, z, size);
    }
}

