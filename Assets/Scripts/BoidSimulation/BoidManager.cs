using UnityEngine;

public class BoidManager : MonoBehaviour
{
    //public ComputeShader computeShader;
    [Header("Start settings")]
    [SerializeField] Material renderMat;
    [SerializeField] ComputeShader computeShader;
    [SerializeField] int flockSize = 100;
    [SerializeField] float startingPosRadius;

    [Header("Simulation settings")]
    [SerializeField] float neighborRadius;
    [SerializeField] float avoidanceRadius;
    [SerializeField] float minSpeed;
    [SerializeField] float maxSpeed;

    [Header("Boid rules settings")]
    [SerializeField] float separationWeight;
    [SerializeField] float alignmentWeight;
    [SerializeField] float cohesionWeight;

    ComputeBuffer boidBuffer;

    struct Boid
    {
        public Vector3 position;
        public Vector3 velocity;
    }

    void Start()
    {
        // create buffer, 24 bytes per object (3 floats for position, 3 for velocity)
        boidBuffer = new ComputeBuffer(flockSize, 24);

        // initialize with random positions and velocities
        Boid[] boids = new Boid[flockSize];
        for (int i = 0; i < flockSize; i++)
        {
            boids[i].position = Random.insideUnitSphere * startingPosRadius;
            // Generate velocity by random direction and speed
            float angle = Random.Range(0f, Mathf.PI * 2f);
            Vector3 randomDir = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle));
            boids[i].velocity = randomDir.normalized * Random.Range(minSpeed, maxSpeed);
        }
        boidBuffer.SetData(boids);
    }

    void Update()
    {
        UpdateComputeShader();

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

    void UpdateComputeShader()
    { 
        int kernel = computeShader.FindKernel("CSMain");
        computeShader.SetBuffer(kernel, "_boidBuffer", boidBuffer);
        computeShader.Dispatch(kernel, Mathf.CeilToInt(flockSize / 64f), 1, 1);

        computeShader.SetFloat("_DeltaTime", Time.deltaTime);
        computeShader.SetInt("_BoidCount", flockSize);
        computeShader.SetFloat("_NeighborRadius", neighborRadius);
        computeShader.SetFloat("_AvoidanceRadius", avoidanceRadius);
        computeShader.SetFloat("_MinSpeed", minSpeed);
        computeShader.SetFloat("_MaxSpeed", maxSpeed);
        computeShader.SetFloat("_SeparationWeight", separationWeight);
        computeShader.SetFloat("_AlignmentWeight", alignmentWeight);
        computeShader.SetFloat("_CohesionWeight", cohesionWeight);
    }
}