# RTX 5090 (Blackwell) Setup Guide for vLLM

## Compatibility Verification
Based on the analysis of `docker/Dockerfile` and `requirements/cuda.txt`:
- **CUDA Version:** 12.9.1 (Compatible with Blackwell)
- **Compute Capability:** 12.0 (Native Blackwell support)
- **PyTorch Version:** 2.9.1 (Cutting-edge support)

## Recommended Docker Command
Run the following command to start vLLM on your RTX 5090.
**Note:** `--enforce-eager` is removed to enable CUDA Graphs for better performance.

```bash
sudo docker run -d --gpus all \
--restart unless-stopped \
-v ~/.cache/huggingface:/root/.cache/huggingface \
-p 8000:8000 \
--ipc=host \
--env VLLM_USE_V1=0 \
vllm/vllm-openai:latest \
--model Qwen/Qwen2.5-32B-Instruct-AWQ \
--max-model-len 32768 \
--kv-cache-dtype fp8 \
--gpu-memory-utilization 0.9 \
--quantization awq
```

## Stopping the Container
To stop the running container:

1.  Find the CONTAINER ID or NAME:
    ```bash
    sudo docker ps
    ```
2.  Stop the container gracefully:
    ```bash
    sudo docker stop <CONTAINER_ID_OR_NAME>
    ```

## Notes
- **Image:** `vllm/vllm-openai:latest` automatically pulls the correct image.
- **Drivers:** Ensure NVIDIA drivers (580.x+) and Container Toolkit are installed on the host.
