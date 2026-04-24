using UnityEngine;

public class BoidManager : MonoBehaviour
{
    //public ComputeShader computeShader;
    [Header("Start settings")]
    [SerializeField] Material renderMat;
    [SerializeField] ComputeShader computeShader;
    [SerializeField] int flockSize = 100;
    [SerializeField] float minBoidSize;
    [SerializeField] float maxBoidSize;
    [SerializeField] AnimationCurve sizeDistribution;

    [Header("Simulation settings")]
    [SerializeField][Range(0.0f, 50.0f)] float neighborDetectionRadius;
    [SerializeField][Range(0.0f, 10.0f)] float neighborAvoidanceRadius;
    [SerializeField] float minSpeed;
    [SerializeField] float maxSpeed;

    [Header("Boundary settings")]
    [SerializeField] Vector3 boxSize;
    [SerializeField][Range(0.0f, 10.0f)] float boundaryWeight;

    [Header("Target following settings")]
    [SerializeField] bool followTarget;
    [SerializeField] Transform target;
    [SerializeField][Range (0.0f, 10.0f)] float targetWeight;

    [Header("Boid rules settings")]
    [SerializeField][Range(0.0f, 10.0f)] float separationWeight;
    [SerializeField][Range(0.0f, 10.0f)] float alignmentWeight;
    [SerializeField][Range(0.0f, 10.0f)] float cohesionWeight;

    ComputeBuffer boidBuffer;

    struct Boid
    {
        public Vector3 position;
        public Vector3 velocity;
        public float size;
    }

    void Start()
    {
        // create buffer, 28 bytes per object (3 floats for position, 3 for velocity, 1 for size)
        boidBuffer = new ComputeBuffer(flockSize, 28);

        // initialize with random positions, velocities and size
        Boid[] boids = new Boid[flockSize];
        for (int i = 0; i < flockSize; i++)
        {
            // Random position within boundary box
            float x = Random.Range(-boxSize.x * 0.5f, boxSize.x * 0.5f);
            float y = Random.Range(-boxSize.y * 0.5f, boxSize.y * 0.5f);
            float z = Random.Range(-boxSize.z * 0.5f, boxSize.z * 0.5f);
            boids[i].position = transform.position + new Vector3(x, y, z);
            boids[i].velocity = Random.insideUnitSphere * Random.Range(minSpeed, maxSpeed);
            float t = Random.value;
            float biasedT = sizeDistribution.Evaluate(t);
            boids[i].size = Mathf.Lerp(minBoidSize, maxBoidSize, biasedT);
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

        // Pass parameters to the compute shader
        computeShader.SetFloat("_DeltaTime", Time.deltaTime);
        computeShader.SetInt("_BoidCount", flockSize);
        computeShader.SetFloat("_NeighborRadius", neighborDetectionRadius);
        computeShader.SetFloat("_AvoidanceRadius", neighborAvoidanceRadius);
        computeShader.SetFloat("_MinSpeed", minSpeed);
        computeShader.SetFloat("_MaxSpeed", maxSpeed);

        computeShader.SetVector("_BoxCenter", transform.position);
        computeShader.SetVector("_BoxSize", boxSize);
        computeShader.SetFloat("_BoundaryWeight", boundaryWeight);

        computeShader.SetBool("_FollowTarget", followTarget);
        computeShader.SetVector("_TargetPosition", target.position);
        computeShader.SetFloat("_TargetWeight", targetWeight);

        computeShader.SetFloat("_SeparationWeight", separationWeight);
        computeShader.SetFloat("_AlignmentWeight", alignmentWeight);
        computeShader.SetFloat("_CohesionWeight", cohesionWeight);

        computeShader.Dispatch(kernel, Mathf.CeilToInt(flockSize / 64f), 1, 1);
    }
}