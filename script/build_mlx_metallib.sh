#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MLX_METALLIB="$ROOT_DIR/.build/mlx-metal/default.metallib"

if [[ -f "$MLX_METALLIB" ]]; then
  echo "$MLX_METALLIB"
  exit 0
fi

MLX_ROOT="$ROOT_DIR/.build/checkouts/mlx-swift/Source/Cmlx/mlx"
KERNEL_DIR="$MLX_ROOT/mlx/backend/metal/kernels"
BUILD_DIR="$(dirname "$MLX_METALLIB")"

if [[ ! -d "$KERNEL_DIR" ]]; then
  echo "missing MLX checkout kernel directory: $KERNEL_DIR" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

kernels=(
  arg_reduce
  conv
  gemv
  layer_norm
  random
  rms_norm
  rope
  scaled_dot_product_attention
  fence
  arange
  binary
  binary_two
  copy
  fft
  reduce
  quantized
  fp_quantized
  scan
  softmax
  logsumexp
  sort
  ternary
  unary
  steel/conv/kernels/steel_conv
  steel/conv/kernels/steel_conv_3d
  steel/conv/kernels/steel_conv_general
  steel/gemm/kernels/steel_gemm_fused
  steel/gemm/kernels/steel_gemm_gather
  steel/gemm/kernels/steel_gemm_masked
  steel/gemm/kernels/steel_gemm_splitk
  steel/gemm/kernels/steel_gemm_segmented
  gemv_masked
  steel/attn/kernels/steel_attention
)

air_files=()
for kernel in "${kernels[@]}"; do
  air_file="$BUILD_DIR/$(basename "$kernel").air"
  xcrun -sdk macosx metal \
    -x metal \
    -Wall \
    -Wextra \
    -fno-fast-math \
    -Wno-c++17-extensions \
    -Wno-c++20-extensions \
    -c "$KERNEL_DIR/$kernel.metal" \
    -I"$MLX_ROOT" \
    -o "$air_file"
  air_files+=("$air_file")
done

xcrun -sdk macosx metallib "${air_files[@]}" -o "$MLX_METALLIB"
echo "$MLX_METALLIB"
