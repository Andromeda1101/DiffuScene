#!/bin/bash
# 评估已生成的图像（如果已经有生成的图像，直接进行评估）

set -e

cd ./scripts

# 检查参数
if [ $# -lt 2 ]; then
    echo "用法: $0 <生成的图像目录> <房间类型>"
    echo "示例: $0 ../outputs/test_generation bedrooms"
    echo ""
    echo "房间类型可选: bedrooms, diningrooms, livingrooms"
    exit 1
fi

GENERATED_IMAGES_DIR="$1"
ROOM_TYPE="$2"

# 验证参数
if [ ! -d "${GENERATED_IMAGES_DIR}" ]; then
    echo "错误: 图像目录不存在: ${GENERATED_IMAGES_DIR}"
    exit 1
fi

# 配置
REAL_IMAGES_DIR="../3d_front_processed/${ROOM_TYPE}_objfeats_32_64"
SPLITS_CSV="../config/${ROOM_TYPE%s}_threed_front_splits.csv"  # bedrooms -> bedroom
OUTPUT_DIR="${GENERATED_IMAGES_DIR}/evaluation_results_$(date +%Y%m%d_%H%M%S)"

mkdir -p "${OUTPUT_DIR}"

echo "======================================"
echo "评估已存在的图像"
echo "======================================"
echo "生成图像目录: ${GENERATED_IMAGES_DIR}"
echo "真实图像目录: ${REAL_IMAGES_DIR}"
echo "房间类型: ${ROOM_TYPE}"
echo "======================================"

# 检查图像数量
GENERATED_COUNT=$(find "${GENERATED_IMAGES_DIR}" -name "*.png" | wc -l)
echo "发现 ${GENERATED_COUNT} 张生成的图像"

if [ ${GENERATED_COUNT} -eq 0 ]; then
    echo "错误: 在 ${GENERATED_IMAGES_DIR} 中没有找到 PNG 图像"
    exit 1
fi

# 检查依赖
if ! python -c "from cleanfid import fid" 2>/dev/null; then
    echo "正在安装 cleanfid..."
    pip install cleanfid
fi

# 计算 FID/KID
echo ""
echo "正在计算 FID 和 KID 分数..."
python compute_fid_scores.py \
    "${REAL_IMAGES_DIR}" \
    "${GENERATED_IMAGES_DIR}" \
    "${SPLITS_CSV}" 2>&1 | tee "${OUTPUT_DIR}/fid_kid_results.txt"

# 计算 Precision/Recall
echo ""
echo "正在计算 Precision 和 Recall..."
python improved_precision_recall.py \
    "${REAL_IMAGES_DIR}" \
    "${GENERATED_IMAGES_DIR}" \
    "${SPLITS_CSV}" 2>&1 | tee "${OUTPUT_DIR}/precision_recall_results.txt"

echo ""
echo "======================================"
echo "评估完成！"
echo "结果保存在: ${OUTPUT_DIR}"
echo "======================================"
