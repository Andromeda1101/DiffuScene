#!/bin/bash
# 完整的评估流程脚本
# 用途: 生成场景并计算评估指标 (FID, KID, Precision, Recall)
# Please update the path to your own environment before running the script

set -e  # 遇到错误时退出

cd ./scripts

# ============ 配置参数 ============
ROOM_TYPE="bedrooms"  # 可选: bedrooms, diningrooms, livingrooms
CONFIG_FILE="../config/text/diffusion_${ROOM_TYPE}_instancond_lat32_v_bert.yaml"
MODEL_CHECKPOINT="../pretrained_diffusion/${ROOM_TYPE}_bert/model_32000"
PICKLED_DATA="../3d_front_processed/threed_future_model_bedroom.pkl"
SPLITS_CSV="../config/bedroom_threed_front_splits.csv"
THREED_FUTURE_MODELS_DIR="../dataset/3D-FUTURE-model"

# 输出目录
OUTPUT_DIR="../outputs/evaluation_${ROOM_TYPE}_$(date +%Y%m%d_%H%M%S)"
GENERATED_IMAGES_DIR="${OUTPUT_DIR}/generated_images"
REAL_IMAGES_DIR="../3d_front_processed/${ROOM_TYPE}_objfeats_32_64"

# 生成参数
NUM_SEQUENCES=100  # 生成场景数量，建议至少100个以获得可靠的评估结果

# 评估参数
NUM_SAMPLES=5000  # 用于precision/recall计算的样本数
BATCH_SIZE=50

echo "======================================"
echo "DiffuScene 评估流程"
echo "======================================"
echo "房间类型: ${ROOM_TYPE}"
echo "配置文件: ${CONFIG_FILE}"
echo "模型检查点: ${MODEL_CHECKPOINT}"
echo "生成数量: ${NUM_SEQUENCES}"
echo "输出目录: ${OUTPUT_DIR}"
echo "======================================"

# ============ Step 0: 依赖检查 ============
echo ""
echo "[Step 0/4] 检查依赖..."

# 检查cleanfid
if ! python -c "from cleanfid import fid" 2>/dev/null; then
    echo "错误: cleanfid 未正确安装"
    echo "正在尝试安装 cleanfid..."
    pip install cleanfid
fi

# 检查必要文件
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}"
    exit 1
fi

if [ ! -f "${MODEL_CHECKPOINT}" ]; then
    echo "错误: 模型检查点不存在: ${MODEL_CHECKPOINT}"
    echo "提示: 请确保已下载预训练模型到 pretrained_diffusion/ 目录"
    exit 1
fi

if [ ! -f "${PICKLED_DATA}" ]; then
    echo "错误: 数据文件不存在: ${PICKLED_DATA}"
    exit 1
fi

if [ ! -d "${REAL_IMAGES_DIR}" ]; then
    echo "错误: 真实图像目录不存在: ${REAL_IMAGES_DIR}"
    exit 1
fi

echo "✓ 依赖检查通过"

# ============ Step 1: 生成场景并渲染 ============
echo ""
echo "[Step 1/4] 生成场景并渲染图像..."
echo "这可能需要一些时间，具体取决于生成数量..."

mkdir -p "${GENERATED_IMAGES_DIR}"

xvfb-run -a python generate_diffusion.py \
    "${CONFIG_FILE}" \
    "${GENERATED_IMAGES_DIR}" \
    "${PICKLED_DATA}" \
    --weight_file "${MODEL_CHECKPOINT}" \
    --n_sequences ${NUM_SEQUENCES} \
    --render_top2down \
    --without_screen \
    --no_texture \
    --without_floor \
    --clip_denoised \
    --retrive_objfeats \
    --path_to_3d_future_models_dir "${THREED_FUTURE_MODELS_DIR}"

if [ $? -ne 0 ]; then
    echo "错误: 场景生成失败"
    exit 1
fi

# 检查生成的图像数量
GENERATED_COUNT=$(find "${GENERATED_IMAGES_DIR}" -name "*.png" | wc -l)
echo "✓ 成功生成 ${GENERATED_COUNT} 张渲染图像"

if [ ${GENERATED_COUNT} -eq 0 ]; then
    echo "错误: 没有生成任何图像"
    exit 1
fi

# ============ Step 2: 计算 FID 和 KID 分数 ============
echo ""
echo "[Step 2/4] 计算 FID 和 KID 分数..."

python compute_fid_scores.py \
    "${REAL_IMAGES_DIR}" \
    "${GENERATED_IMAGES_DIR}" \
    "${SPLITS_CSV}" \
    > "${OUTPUT_DIR}/fid_kid_results.txt"

if [ $? -ne 0 ]; then
    echo "警告: FID/KID 计算失败，但继续评估流程"
else
    echo "✓ FID/KID 计算完成"
    echo ""
    echo "--- FID/KID 结果 ---"
    cat "${OUTPUT_DIR}/fid_kid_results.txt"
    echo "结果已保存到: ${OUTPUT_DIR}/fid_kid_results.txt"
fi

# ============ Step 3: 计算 Precision 和 Recall ============
echo ""
echo "[Step 3/4] 计算 Precision 和 Recall..."

python improved_precision_recall.py \
    "${REAL_IMAGES_DIR}" \
    "${GENERATED_IMAGES_DIR}" \
    "${SPLITS_CSV}" \
    --batch_size ${BATCH_SIZE} \
    --num_samples ${NUM_SAMPLES} \
    > "${OUTPUT_DIR}/precision_recall_results.txt"

if [ $? -ne 0 ]; then
    echo "警告: Precision/Recall 计算失败"
else
    echo "✓ Precision/Recall 计算完成"
    echo ""
    echo "--- Precision/Recall 结果 ---"
    cat "${OUTPUT_DIR}/precision_recall_results.txt"
    echo "结果已保存到: ${OUTPUT_DIR}/precision_recall_results.txt"
fi

# ============ Step 4: 生成评估报告 ============
echo ""
echo "[Step 4/4] 生成评估报告..."

REPORT_FILE="${OUTPUT_DIR}/evaluation_report.txt"

cat > "${REPORT_FILE}" << EOF
====================================
DiffuScene 评估报告
====================================
生成时间: $(date)
房间类型: ${ROOM_TYPE}
配置文件: ${CONFIG_FILE}
模型检查点: ${MODEL_CHECKPOINT}
生成场景数: ${NUM_SEQUENCES}
生成图像数: ${GENERATED_COUNT}

====================================
FID 和 KID 分数
====================================
EOF

if [ -f "${OUTPUT_DIR}/fid_kid_results.txt" ]; then
    cat "${OUTPUT_DIR}/fid_kid_results.txt" >> "${REPORT_FILE}"
else
    echo "未计算" >> "${REPORT_FILE}"
fi

cat >> "${REPORT_FILE}" << EOF

====================================
Precision 和 Recall
====================================
EOF

if [ -f "${OUTPUT_DIR}/precision_recall_results.txt" ]; then
    cat "${OUTPUT_DIR}/precision_recall_results.txt" >> "${REPORT_FILE}"
else
    echo "未计算" >> "${REPORT_FILE}"
fi

echo "✓ 评估报告已生成"

# ============ 完成 ============
echo ""
echo "======================================"
echo "评估完成！"
echo "======================================"
echo "输出目录: ${OUTPUT_DIR}"
echo "- 生成的图像: ${GENERATED_IMAGES_DIR}"
echo "- FID/KID 结果: ${OUTPUT_DIR}/fid_kid_results.txt"
echo "- Precision/Recall 结果: ${OUTPUT_DIR}/precision_recall_results.txt"
echo "- 完整报告: ${REPORT_FILE}"
echo ""
echo "查看完整报告:"
echo "  cat ${REPORT_FILE}"
echo "======================================"
