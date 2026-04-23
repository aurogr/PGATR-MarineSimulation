using UnityEngine;

public class FlockManager : MonoBehaviour
{
    //public ComputeShader computeShader;
    [SerializeField] Material renderMat;
    [SerializeField] int flockSize = 100;
    [SerializeField] float startingPosRadius;
    [SerializeField] float minSpeed;
    [SerializeField] float maxSpeed;
    ComputeBuffer boidBuffer;
    struct Boid
    {
        public Vector3 position;
        public Vector3 direction;
        public float speed;
    }

    void Start()
    {
        // create buffer, 24 bytes per object (3 floats for position, 3 for direction and 1 for speed)
        boidBuffer = new ComputeBuffer(flockSize, 28);

        // initialize with random positions and velocities
        Boid[] boids = new Boid[flockSize];
        for (int i = 0; i < flockSize; i++)
        {
            boids[i].position = Random.insideUnitSphere * startingPosRadius;
            // Generate a random horizontal angle
            float angle = Random.Range(0f, Mathf.PI * 2f);

            // Create direction: X = cos, Z = sin, Y = 0 (to keep them level)
            Vector3 randomDir = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle));
            boids[i].direction = randomDir.normalized;
            boids[i].speed = Random.Range(minSpeed, maxSpeed);
        }
        boidBuffer.SetData(boids);
    }

    void Update()
    {
        //// 1. Run the Compute Shader to update positions
        //int kernel = computeShader.FindKernel("CSMain");
        //computeShader.SetBuffer(kernel, "boidsBuffer", boidBuffer);
        //computeShader.Dispatch(kernel, Mathf.CeilToInt(seagullCount / 64f), 1, 1);

        // 2. Pass the buffer to the Rendering Material
        renderMat.SetBuffer("_BoidBuffer", boidBuffer);
    }


    void OnRenderObject()
    {
        // Render points procedurally
        renderMat.SetPass(0);
        Graphics.DrawProceduralNow(MeshTopology.Points, flockSize);
    }

    void OnDestroy() => boidBuffer.Release();
}