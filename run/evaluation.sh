#!/bin/bash
# 完整的评估流程脚本
# 用途: 生成场景并计算评估指标 (FID, KID, Precision, Recall)
# Please update the path to your own environment before running the script

set -e  # 遇到错误时退出

cd ./scripts

# ============ 通用配置参数 ============
PRETRAINED_MODEL_DIR="../pretrained_diffusion"
THREED_FUTURE_MODELS_DIR="../dataset/3D-FUTURE-model"
EXP_DIR="../pretrained"

# 生成参数
NUM_SEQUENCES=100  # 生成场景数量，建议至少100个以获得可靠的评估结果

# 评估参数
NUM_SAMPLES=5000  # 用于precision/recall计算的样本数
BATCH_SIZE=50

echo "======================================"
echo "DiffuScene 评估流程"
echo "======================================"
echo "将依次评估: bedrooms, diningrooms, livingrooms"
echo "生成数量: ${NUM_SEQUENCES}"
echo "======================================"

# ============ Step 0: 依赖检查 ============
echo ""
echo "[Step 0] 检查依赖..."

# 检查cleanfid
if ! python -c "from cleanfid import fid" 2>/dev/null; then
    echo "错误: cleanfid 未正确安装"
    echo "正在尝试安装 cleanfid..."
    pip install cleanfid
fi

echo "✓ 依赖检查通过"

# ============ 评估 Bedrooms ============
echo ""
echo "======================================"
echo "开始评估: Bedrooms"
echo "======================================"

CONFIG_FILE="../config/uncond/diffusion_bedrooms_instancond_lat32_v.yaml"
EXP_NAME="bedrooms_uncond"
MODEL_CHECKPOINT="${PRETRAINED_MODEL_DIR}/${EXP_NAME}/model_30000"
PICKLED_DATA="../3d_front_processed/threed_future_model_bedroom.pkl"
SPLITS_CSV="../config/bedroom_threed_front_splits.csv"
REAL_IMAGES_DIR="../3d_front_processed/bedrooms_objfeats_32_64"
OUTPUT_DIR="$EXP_DIR/$EXP_NAME/"
G_DIR="$EXP_DIR/$EXP_NAME/gen_top2down_notexture_nofloor"

# 检查必要文件
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}"
    exit 1
fi

if [ ! -f "${MODEL_CHECKPOINT}" ]; then
    echo "错误: 模型检查点不存在: ${MODEL_CHECKPOINT}"
    exit 1
fi

echo "[Bedrooms Step 1/3] 生成场景并渲染图像..."
mkdir -p "${G_DIR}"

xvfb-run -a python generate_diffusion.py \
    $CONFIG_FILE \
    $G_DIR \
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

GENERATED_COUNT=$(find "${G_DIR}" -name "*.png" | wc -l)
echo "✓ 成功生成 ${GENERATED_COUNT} 张渲染图像"

echo "[Bedrooms Step 2/3] 计算 FID 和 KID 分数..."
python compute_fid_scores.py \
    "${REAL_IMAGES_DIR}" \
    "${G_DIR}" \
    "${SPLITS_CSV}" \
    > "${OUTPUT_DIR}/fid_kid_results.txt"

echo "[Bedrooms Step 3/3] 计算 Precision 和 Recall..."
python improved_precision_recall.py \
    "${REAL_IMAGES_DIR}" \
    "${G_DIR}" \
    "${SPLITS_CSV}" \
    --batch_size ${BATCH_SIZE} \
    --num_samples ${NUM_SAMPLES} \
    > "${OUTPUT_DIR}/precision_recall_results.txt"

# 生成报告
REPORT_FILE="${OUTPUT_DIR}/evaluation_report.txt"
cat > "${REPORT_FILE}" << EOF
====================================
DiffuScene 评估报告 - Bedrooms
====================================
生成时间: $(date)
实验名称: ${EXP_NAME}
配置文件: ${CONFIG_FILE}
模型检查点: ${MODEL_CHECKPOINT}
生成场景数: ${NUM_SEQUENCES}
生成图像数: ${GENERATED_COUNT}

====================================
FID 和 KID 分数
====================================
EOF
cat "${OUTPUT_DIR}/fid_kid_results.txt" >> "${REPORT_FILE}"
cat >> "${REPORT_FILE}" << EOF

====================================
Precision 和 Recall
====================================
EOF
cat "${OUTPUT_DIR}/precision_recall_results.txt" >> "${REPORT_FILE}"

echo "✓ Bedrooms 评估完成: ${OUTPUT_DIR}"

# ============ 评估 Diningrooms ============
echo ""
echo "======================================"
echo "开始评估: Diningrooms"
echo "======================================"

CONFIG_FILE="../config/uncond/diffusion_diningrooms_instancond_lat32_v.yaml"
EXP_NAME="diningrooms_uncond"
MODEL_CHECKPOINT="${PRETRAINED_MODEL_DIR}/${EXP_NAME}/model_82000"
PICKLED_DATA="../3d_front_processed/threed_future_model_diningroom.pkl"
SPLITS_CSV="../config/diningroom_threed_front_splits.csv"
REAL_IMAGES_DIR="../3d_front_processed/diningrooms_objfeats_32_64"
OUTPUT_DIR="$EXP_DIR/$EXP_NAME/"
G_DIR="$EXP_DIR/$EXP_NAME/gen_top2down_notexture_nofloor"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}"
    exit 1
fi

if [ ! -f "${MODEL_CHECKPOINT}" ]; then
    echo "错误: 模型检查点不存在: ${MODEL_CHECKPOINT}"
    exit 1
fi

echo "[Diningrooms Step 1/3] 生成场景并渲染图像..."
mkdir -p "${G_DIR}"

xvfb-run -a python generate_diffusion.py \
    $CONFIG_FILE \
    $G_DIR \
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

GENERATED_COUNT=$(find "${G_DIR}" -name "*.png" | wc -l)
echo "✓ 成功生成 ${GENERATED_COUNT} 张渲染图像"

echo "[Diningrooms Step 2/3] 计算 FID 和 KID 分数..."
python compute_fid_scores.py \
    "${REAL_IMAGES_DIR}" \
    "${G_DIR}" \
    "${SPLITS_CSV}" \
    > "${OUTPUT_DIR}/fid_kid_results.txt"

echo "[Diningrooms Step 3/3] 计算 Precision 和 Recall..."
python improved_precision_recall.py \
    "${REAL_IMAGES_DIR}" \
    "${G_DIR}" \
    "${SPLITS_CSV}" \
    --batch_size ${BATCH_SIZE} \
    --num_samples ${NUM_SAMPLES} \
    > "${OUTPUT_DIR}/precision_recall_results.txt"

# 生成报告
REPORT_FILE="${OUTPUT_DIR}/evaluation_report.txt"
cat > "${REPORT_FILE}" << EOF
====================================
DiffuScene 评估报告 - Diningrooms
====================================
生成时间: $(date)
实验名称: ${EXP_NAME}
配置文件: ${CONFIG_FILE}
模型检查点: ${MODEL_CHECKPOINT}
生成场景数: ${NUM_SEQUENCES}
生成图像数: ${GENERATED_COUNT}

====================================
FID 和 KID 分数
====================================
EOF
cat "${OUTPUT_DIR}/fid_kid_results.txt" >> "${REPORT_FILE}"
cat >> "${REPORT_FILE}" << EOF

====================================
Precision 和 Recall
====================================
EOF
cat "${OUTPUT_DIR}/precision_recall_results.txt" >> "${REPORT_FILE}"

echo "✓ Diningrooms 评估完成: ${OUTPUT_DIR}"

# ============ 评估 Livingrooms ============
echo ""
echo "======================================"
echo "开始评估: Livingrooms"
echo "======================================"

CONFIG_FILE="../config/uncond/diffusion_livingrooms_instancond_lat32_v.yaml"
EXP_NAME="livingrooms_uncond"
MODEL_CHECKPOINT="${PRETRAINED_MODEL_DIR}/${EXP_NAME}/model_96000"
PICKLED_DATA="../3d_front_processed/threed_future_model_livingroom.pkl"
SPLITS_CSV="../config/livingroom_threed_front_splits.csv"
REAL_IMAGES_DIR="../3d_front_processed/livingrooms_objfeats_32_64"
OUTPUT_DIR="$EXP_DIR/$EXP_NAME/"
G_DIR="$EXP_DIR/$EXP_NAME/gen_top2down_notexture_nofloor"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}"
    exit 1
fi

if [ ! -f "${MODEL_CHECKPOINT}" ]; then
    echo "错误: 模型检查点不存在: ${MODEL_CHECKPOINT}"
    exit 1
fi

echo "[Livingrooms Step 1/3] 生成场景并渲染图像..."
mkdir -p "${G_DIR}"

xvfb-run -a python generate_diffusion.py \
    $CONFIG_FILE \
    $G_DIR \
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

GENERATED_COUNT=$(find "${G_DIR}" -name "*.png" | wc -l)
echo "✓ 成功生成 ${GENERATED_COUNT} 张渲染图像"

echo "[Livingrooms Step 2/3] 计算 FID 和 KID 分数..."
python compute_fid_scores.py \
    "${REAL_IMAGES_DIR}" \
    "${G_DIR}" \
    "${SPLITS_CSV}" \
    > "${OUTPUT_DIR}/fid_kid_results.txt"

echo "[Livingrooms Step 3/3] 计算 Precision 和 Recall..."
python improved_precision_recall.py \
    "${REAL_IMAGES_DIR}" \
    "${G_DIR}" \
    "${SPLITS_CSV}" \
    --batch_size ${BATCH_SIZE} \
    --num_samples ${NUM_SAMPLES} \
    > "${OUTPUT_DIR}/precision_recall_results.txt"

# 生成报告
REPORT_FILE="${OUTPUT_DIR}/evaluation_report.txt"
cat > "${REPORT_FILE}" << EOF
====================================
DiffuScene 评估报告 - Livingrooms
====================================
生成时间: $(date)
实验名称: ${EXP_NAME}
配置文件: ${CONFIG_FILE}
模型检查点: ${MODEL_CHECKPOINT}
生成场景数: ${NUM_SEQUENCES}
生成图像数: ${GENERATED_COUNT}

====================================
FID 和 KID 分数
====================================
EOF
cat "${OUTPUT_DIR}/fid_kid_results.txt" >> "${REPORT_FILE}"
cat >> "${REPORT_FILE}" << EOF

====================================
Precision 和 Recall
====================================
EOF
cat "${OUTPUT_DIR}/precision_recall_results.txt" >> "${REPORT_FILE}"

echo "✓ Livingrooms 评估完成: ${OUTPUT_DIR}"

# ============ 完成 ============
echo ""
echo "======================================"
echo "全部评估完成！"
echo "======================================"
echo "评估结果保存在 ../pretrained/*_uncond/ 目录下"
echo "======================================"
