#!/bin/bash
# 快速评估脚本（生成较少场景，用于快速测试）

set -e

# ============ 配置参数 ============
ROOM_TYPE="bedrooms"
CONFIG_FILE="config/text/diffusion_${ROOM_TYPE}_instancond_lat32_v_bert.yaml"
MODEL_CHECKPOINT="pretrained_diffusion/${ROOM_TYPE}_bert/model_32000"
PICKLED_DATA="3d_front_processed/threed_future_model_bedroom.pkl"
SPLITS_CSV="config/bedroom_threed_front_splits.csv"

OUTPUT_DIR="outputs/quick_eval_${ROOM_TYPE}_$(date +%Y%m%d_%H%M%S)"
GENERATED_IMAGES_DIR="${OUTPUT_DIR}/generated_images"
REAL_IMAGES_DIR="3d_front_processed/${ROOM_TYPE}_objfeats_32_64"

# 快速测试参数
NUM_SEQUENCES=20  # 只生成20个场景用于快速测试
NUM_SAMPLES=1000  # 使用较少样本

echo "======================================"
echo "DiffuScene 快速评估（测试模式）"
echo "======================================"
echo "注意: 这是快速测试模式，仅生成 ${NUM_SEQUENCES} 个场景"
echo "要获得可靠的评估结果，请使用 run_evaluation.sh"
echo "======================================"

# 检查依赖
if ! python -c "from cleanfid import fid" 2>/dev/null; then
    echo "正在安装 cleanfid..."
    pip install cleanfid
fi

# 检查必要文件
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}"
    exit 1
fi

# 生成场景
echo ""
echo "正在生成 ${NUM_SEQUENCES} 个场景..."
mkdir -p "${GENERATED_IMAGES_DIR}"

python scripts/generate_diffusion.py \
    "${CONFIG_FILE}" \
    "${GENERATED_IMAGES_DIR}" \
    "${PICKLED_DATA}" \
    --weight_file "${MODEL_CHECKPOINT}" \
    --n_sequences ${NUM_SEQUENCES} \
    --render_top2down \
    --without_screen \
    --background 1,1,1,1

if [ $? -ne 0 ]; then
    echo "错误: 场景生成失败"
    exit 1
fi

GENERATED_COUNT=$(find "${GENERATED_IMAGES_DIR}" -name "*.png" | wc -l)
echo "✓ 生成了 ${GENERATED_COUNT} 张图像"

# 计算 FID
echo ""
echo "计算 FID/KID..."
python scripts/compute_fid_scores.py \
    "${REAL_IMAGES_DIR}" \
    "${GENERATED_IMAGES_DIR}" \
    "${SPLITS_CSV}" 2>&1 | tee "${OUTPUT_DIR}/results.txt"

# 计算 Precision/Recall
echo ""
echo "计算 Precision/Recall..."
python scripts/improved_precision_recall.py \
    "${REAL_IMAGES_DIR}" \
    "${GENERATED_IMAGES_DIR}" \
    "${SPLITS_CSV}" \
    --num_samples ${NUM_SAMPLES} 2>&1 | tee -a "${OUTPUT_DIR}/results.txt"

echo ""
echo "======================================"
echo "快速评估完成！"
echo "结果保存在: ${OUTPUT_DIR}/results.txt"
echo "======================================"
