using UnityEngine;
using UnityEngine.InputSystem;

public class FlyCamera : MonoBehaviour
{
    [Header("Movement Settings")]
    [SerializeField] float moveSpeed = 10f;
    [SerializeField] float fastMoveFactor = 3f;
    [SerializeField] float lookSensitivity = 0.1f;

    float rotationX = 0f;
    float rotationY = 0f;

    void Start()
    {
        // Lock the cursor to the center of the screen
        Cursor.lockState = CursorLockMode.Locked;

        // Initialize rotation based on current transform
        Vector3 rot = transform.localRotation.eulerAngles;
        rotationX = rot.y;
        rotationY = -rot.x;
    }

    void Update()
    {
        HandleRotation();
        HandleMovement();

        // Escape to unlock mouse
        if (Keyboard.current.escapeKey.wasPressedThisFrame)
            Cursor.lockState = CursorLockMode.None;
    }

    void HandleRotation()
    {
        if (Mouse.current == null) return;

        // Get mouse delta from the new input system
        Vector2 mouseDelta = Mouse.current.delta.ReadValue() * lookSensitivity;

        rotationX += mouseDelta.x;
        rotationY += mouseDelta.y;
        rotationY = Mathf.Clamp(rotationY, -90f, 90f);

        transform.localRotation = Quaternion.Euler(-rotationY, rotationX, 0f);
    }

    void HandleMovement()
    {
        if (Keyboard.current == null) return;

        Vector3 direction = Vector3.zero;

        // Standard WASD
        if (Keyboard.current.wKey.isPressed) direction += transform.forward;
        if (Keyboard.current.sKey.isPressed) direction -= transform.forward;
        if (Keyboard.current.aKey.isPressed) direction -= transform.right;
        if (Keyboard.current.dKey.isPressed) direction += transform.right;

        // Vertical Movement (Q/E or Space/Ctrl)
        if (Keyboard.current.eKey.isPressed || Keyboard.current.spaceKey.isPressed)
            direction += Vector3.up;
        if (Keyboard.current.qKey.isPressed || Keyboard.current.leftCtrlKey.isPressed)
            direction -= Vector3.up;

        // Sprinting
        float currentSpeed = moveSpeed;
        if (Keyboard.current.leftShiftKey.isPressed)
            currentSpeed *= fastMoveFactor;

        transform.position += direction * currentSpeed * Time.deltaTime;
    }
}