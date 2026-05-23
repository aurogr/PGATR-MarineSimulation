using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.Rendering.Universal;

public class FlyCamera : MonoBehaviour
{
    [Header("Movement Settings")]
    [SerializeField] float moveSpeed = 10f;
    [SerializeField] float fastMoveFactor = 3f;
    [SerializeField] float lookSensitivity = 0.1f;

    float rotationX = 0f;
    float rotationY = 0f;

    Camera cam; 
    UniversalAdditionalCameraData urpCameraData;

    private CameraClearFlags originalClearFlags;
    private Color originalBackgroundColor;


    void Start()
    {
        cam = GetComponent<Camera>();

        if (cam != null)
        {
            // Fetch the hidden component URP automatically adds to cameras
            urpCameraData = cam.GetComponent<UniversalAdditionalCameraData>();

            originalClearFlags = cam.clearFlags;
            originalBackgroundColor = cam.backgroundColor;
        }

        LockCursor();

        Vector3 rot = transform.localRotation.eulerAngles;
        rotationX = rot.y;
        rotationY = -rot.x;
    }

    void Update()
    {
        if (Keyboard.current.escapeKey.wasPressedThisFrame)
        {
            UnlockCursor();
        }
        if (Mouse.current.leftButton.wasPressedThisFrame && Cursor.lockState == CursorLockMode.None)
        {
            LockCursor();
        }
        if (Cursor.lockState == CursorLockMode.Locked)
        {
            HandleRotation();
            HandleMovement();
        }
    }

    void LockCursor()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void UnlockCursor()
    {
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
    }

    void HandleRotation()
    {
        if (Mouse.current == null) return;

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

        if (Keyboard.current.wKey.isPressed) direction += transform.forward;
        if (Keyboard.current.sKey.isPressed) direction -= transform.forward;
        if (Keyboard.current.aKey.isPressed) direction -= transform.right;
        if (Keyboard.current.dKey.isPressed) direction += transform.right;

        if (Keyboard.current.eKey.isPressed || Keyboard.current.spaceKey.isPressed)
            direction += Vector3.up;
        if (Keyboard.current.qKey.isPressed || Keyboard.current.leftCtrlKey.isPressed)
            direction -= Vector3.up;

        float currentSpeed = moveSpeed;
        if (Keyboard.current.leftShiftKey.isPressed)
            currentSpeed *= fastMoveFactor;

        transform.position += direction * currentSpeed * Time.deltaTime;
    }

    private void OnTriggerEnter(Collider other)
    {
        // Make sure your water zone object has this exact Tag in the inspector
        if (other.CompareTag("SeaVolume"))
        {
            Debug.Log("Entered SeaVolume, enabling underwater effects.");
            RenderSettings.fog = true;
            EnableUnderwaterEffects();
        }
    }

    private void OnTriggerExit(Collider other)
    {
        // Make sure your water zone object has this exact Tag in the inspector
        if (other.CompareTag("SeaVolume"))
        {
            Debug.Log("Exited SeaVolume, disabling underwater effects.");
            RenderSettings.fog = true;
            DisableUnderwaterEffects();
        }
    }


    void EnableUnderwaterEffects()
    {
        // 1. Setup Global Fog
        RenderSettings.fog = true;

        // 2. Change URP Background Type to Solid Color at runtime
        if (cam != null)
        {
            if (urpCameraData != null)
            {
                // Forces URP to ignore the Skybox rendering step and clear to color
                urpCameraData.renderType = CameraRenderType.Base;
                cam.clearFlags = CameraClearFlags.Color;
            }
        }
    }

    void DisableUnderwaterEffects()
    {
        if (cam != null)
        {
            cam.backgroundColor = originalBackgroundColor;
            cam.clearFlags = originalClearFlags;

            if (urpCameraData != null)
            {
                cam.clearFlags = CameraClearFlags.Skybox;
            }
        }
    }
}