/*
 * 创建LowPoly水面模型。
 * 调用CreateSeaMesh函数创建水面模型。
 * debug时，可在编辑器界面右键调用DebugCreateNoDepth直接生成模型
 */

using UnityEngine;

public class CreateWaterPlane : MonoBehaviour
{
    [Tooltip("模型所使用的Mesh Filter")]
    public MeshFilter meshFilter;

    [Tooltip("X轴上四边面数量")]
    public int x;
    [Tooltip("Z轴上四边面数量")]
    public int z;
    [Tooltip("每个四边面的大小")]
    public float size;

    /// <summary>
    /// 创建水面模型，不包含水的深度。用于深海区域的水面
    /// </summary>
    /// <param name="segX">X轴上四边面数量</param>
    /// <param name="segZ">Z轴上四边面数量</param>
    /// <param name="quadSize">每个四边面的大小</param>
    /// <returns></returns>
    public Mesh CreateSeaMesh(int segX, int segZ, float quadSize)
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
            }
        }

        mesh.SetVertices(verts);
        mesh.SetTriangles(tris, 0);
        return mesh;
    }

    /// <summary>
    /// DEBUG用。
    /// </summary>
    [ContextMenu("DEBUG Create No Water Depth")]
    private void DebugCreateNoDepth()
    {
        meshFilter.mesh = CreateSeaMesh(x, z, size);
    }
}
