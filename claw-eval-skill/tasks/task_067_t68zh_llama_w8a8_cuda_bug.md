---
id: task_067_t68zh_llama_w8a8_cuda_bug
name: Claw-Eval T68zh_llama_w8a8_cuda_bug
category: coding
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

题目标题： Review一下这个 LLaMA W8A8 量化算子的致命 Bug

题目描述：
我是负责推理引擎优化的架构师。最近为了在边缘设备（NVIDIA Orin）上跑 LLaMA-7B，让实习生手写了一个自定义的 W8A8（权重INT8，激活INT8）矩阵乘法（GEMM）CUDA Kernel。
目的是替代 cuBLAS，想通过极简实现来减小 binary 体积。但他提交的代码跑出来的结果完全是乱码（PPL 爆炸），而且速度比 FP16 还慢。
这是他写的量化逻辑说明和核心 CUDA 代码片段（简化版）：

1. 量化方案：
对 Weight 和 Activation 都采用 Per-Tensor Symmetric Quantization（逐张量对称量化）。
公式：Q = clip(round(X / scale), -127, 127)，其中 scale = max(abs(X)) / 127。

2. CUDA Kernel (C++) 片段：
```cpp
__global__ void w8a8_matmul_kernel(const int8_t* A, const int8_t* B, float* C,
    float scale_a, float scale_b, int N, int K) {
    // A: M x K (Row Major)
    // B: K x N (Column Major, 转置过以优化读取)
    // C: M x N

    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < N && col < N) {
        // 定义累加器
        int8_t sum = 0;

        for (int k = 0; k < K; ++k) {
            // 简单的点积
            int8_t a_val = A[row * K + k];
            int8_t b_val = B[col * K + k]; // B是列优先，所以这样写

            // 乘加
            sum += a_val * b_val;
        }

        // 反量化写入显存
        C[row * N + col] = (float)sum * scale_a * scale_b;
    }
}
```

请你作为 Tech Lead，指出上述方案中至少 3 个导致精度崩盘或性能低下的致命错误（Fatal Errors），并从底层原理层面解释为什么这么做不行，最后给出针对 LLaMA 架构特性的正确修正思路。

要求：
- 不要给我通用的代码优化建议（如"加注释"），只谈硬核的数学计算和 CUDA 硬件机制。
- 必须解释清楚为什么实习生的量化策略对 LLaMA 这种模型是行不通的。
- 必须指出代码中关于数据类型处理的严重数学谬误。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T68zh_llama_w8a8_cuda_bug`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

你正在评估一份关于LLaMA W8A8量化CUDA Kernel致命Bug的技术审查报告。基于以下评分标准逐项打分：

【正向评分项】（满分100%）
1. [权重10%] 指出int8_t累加器导致整数溢出（应使用int32_t） — 这是最关键的精度Bug
2. [权重10%] 解释LLaMA激活值存在Outlier特性，Per-Tensor对称量化无法处理 — 需要Per-Channel或Per-Token量化
3. [权重9%] 指出矩阵B的非合并访问模式导致带宽利用率低
4. [权重9%] 提及Shared Memory Tiling分块优化策略
5. [权重8%] 分析算术强度约1 Op/Byte，在Roofline模型中属于Memory Bound
6. [权重8%] 提及使用Ampere架构async copy指令（cp.async）进行异步拷贝
7. [权重8%] 提及Padding或Swizzling防止Shared Memory Bank Conflicts
8. [权重6%] 提及Double Buffering或pipeline策略实现指令级并行
9. [权重6%] 提及向量化加载指令（LDS.128/float4/int4）或ld.global.nc
10. [权重6%] 提及ldmatrix指令从shared memory加载到寄存器以使用Tensor Cores
11. [权重6%] 利用NVIDIA Orin（Ampere架构）的2:4结构化稀疏性提升吞吐
12. [权重7%] 反量化公式中Activation Scale按行对齐、Weight Scale按列对齐的逐元素乘法
13. [权重7%] 边界检查bug：if (row < N && col < N) 应为 row < M && col < N

【负向扣分项】（出现时扣分）
14. [扣6%] 引用不存在的CUDA函数或API
15. [扣6%] 伪造学术论文引用
16. [扣4%] 建议使用float16作为累加器（应为int32）
17. [扣4%] 错误建议使用非对称量化（asymmetric quantization）作为修正方案
