# Academic project. Marine Simulation Demo
University project for the subject "Graphic processors & Real-Time Applications" where we had to demonstrate advanced GPU programming techniques in Unity.

- The sea is done with a tessellation shader, that increases geometric density based on camera proximity to optimize performance. It also has movement bia displacement of the height map in a wave pattern.

- The fish and birds are done with a geometry shader, that creates the necessary tris from a single point in space to be able to apply the bird and fish meshes. It also moves said geometry to simulate natural wing and tail animations.

- Birds and fish also follow a boid flocking algorithm, made with a compute shader on the GPU, for high-performance steering behaviors.
