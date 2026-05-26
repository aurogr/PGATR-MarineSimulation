# Academic project. Marine Simulation Demo
University project for the subject "Graphic processors & Real-Time Applications" where we had to demonstrate advanced GPU programming techniques in Unity.

https://github.com/user-attachments/assets/5770d411-474a-4d63-ae55-fc864b91cebb


- The sea is done with a tessellation shader, that increases geometric density based on camera proximity to optimize performance. It also has movement bia displacement of the height map in a wave pattern.

| Sand tessellation | Sea tessellation |
| :---: | :---: |
| <img width="500" alt="ezgif-78a69b194098234c" src="https://github.com/user-attachments/assets/349ea3b2-95f0-4ce8-b24d-225cfad5a2fe" /> | <img width="500" alt="sea" src="https://github.com/user-attachments/assets/b7d3a6f7-655e-4ae4-a8ba-43a80a386726" /> |

- The fish and birds are done with a geometry shader, that creates the necessary tris from a single point in space to be able to apply the bird and fish meshes. It also moves said geometry to simulate natural wing and tail animations.

- Birds and fish also follow a boid flocking algorithm, made with a compute shader on the GPU, for high-performance steering behaviors.

| Boid behaviour | Follow target |
| :---: | :---: |
| <img width="500" alt="ezgif-78a69b194098234c" src="https://github.com/user-attachments/assets/24132bfc-07ca-4999-b60f-73c019bc7b97" /> | <img width="500" alt="sea" src="https://github.com/user-attachments/assets/4047bce0-bbf7-4d4a-a0a6-2d3dff8e6012" /> |
