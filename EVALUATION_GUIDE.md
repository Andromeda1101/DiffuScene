# DiffuScene 评估流程使用指南

本指南说明如何使用评估脚本来评估DiffuScene生成的场景质量。

## 📋 评估指标

评估脚本会计算以下指标：

1. **FID (Fréchet Inception Distance)**: 衡量生成图像与真实图像分布的距离，越低越好
2. **KID (Kernel Inception Distance)**: 另一种分布距离度量，越低越好
3. **Precision**: 精确度，衡量生成图像的质量
4. **Recall**: 召回率，衡量生成图像的多样性
5. **F-score**: Precision和Recall的调和平均数

## 🚀 快速开始

### 方案1: 完整评估流程（推荐）

生成100个场景并进行完整评估（约需30-60分钟）：

```bash
./run_evaluation.sh
```

### 方案2: 快速测试评估

仅生成20个场景用于快速测试（约需5-10分钟）：

```bash
./run_quick_evaluation.sh
```

### 方案3: 评估已存在的图像

如果你已经生成了场景图像，可以直接评估：

```bash
./evaluate_existing_images.sh <图像目录> <房间类型>

# 示例
./evaluate_existing_images.sh outputs/my_generated_scenes bedrooms
```

## ⚙️ 自定义配置

### 修改评估参数

编辑 `run_evaluation.sh` 文件中的配置部分：

```bash
# 房间类型选择
ROOM_TYPE="bedrooms"  # 可选: bedrooms, diningrooms, livingrooms

# 生成数量（影响评估可靠性）
NUM_SEQUENCES=100     # 建议至少100个

# 评估采样数
NUM_SAMPLES=5000      # 用于precision/recall计算
BATCH_SIZE=50         # 批处理大小
```

### 不同房间类型的评估

**卧室 (Bedrooms):**
```bash
# 修改 run_evaluation.sh 中的配置
ROOM_TYPE="bedrooms"
CONFIG_FILE="config/text/diffusion_bedrooms_instancond_lat32_v_bert.yaml"
MODEL_CHECKPOINT="pretrained_diffusion/bedrooms_bert/model_32000"
PICKLED_DATA="3d_front_processed/threed_future_model_bedroom.pkl"
SPLITS_CSV="config/bedroom_threed_front_splits.csv"
```

**餐厅 (Dining Rooms):**
```bash
ROOM_TYPE="diningrooms"
CONFIG_FILE="config/text/diffusion_diningrooms_instancond_lat32_v_bert.yaml"
MODEL_CHECKPOINT="pretrained_diffusion/diningrooms_bert/model_32000"
PICKLED_DATA="3d_front_processed/threed_future_model_diningroom.pkl"
SPLITS_CSV="config/diningroom_threed_front_splits.csv"
```

**客厅 (Living Rooms):**
```bash
ROOM_TYPE="livingrooms"
CONFIG_FILE="config/text/diffusion_livingrooms_instancond_lat32_v_bert.yaml"
MODEL_CHECKPOINT="pretrained_diffusion/livingrooms_bert/model_32000"
PICKLED_DATA="3d_front_processed/threed_future_model_livingroom.pkl"
SPLITS_CSV="config/livingroom_threed_front_splits.csv"
```

## 📊 查看评估结果

### 输出目录结构

```
outputs/evaluation_bedrooms_YYYYMMDD_HHMMSS/
├── generated_images/          # 生成的场景渲染图像
│   ├── scene_001.png
│   ├── scene_002.png
│   └── ...
├── fid_kid_results.txt        # FID和KID分数
├── precision_recall_results.txt  # Precision和Recall结果
└── evaluation_report.txt      # 完整评估报告
```

### 查看完整报告

```bash
# 查看最新的评估报告
cat outputs/evaluation_*/evaluation_report.txt

# 或者指定具体的评估结果
cat outputs/evaluation_bedrooms_20231222_143000/evaluation_report.txt
```

### 示例输出

```
====================================
FID 和 KID 分数
====================================
number of synthesized images : 100
fid score: 45.23
kid score: 0.0234

====================================
Precision 和 Recall
====================================
number of synthesized images : 100
precision: 0.856
recall: 0.742
fscore: 0.795
```

## 🔧 故障排除

### 问题1: cleanfid 未安装

```bash
# 手动安装
pip install cleanfid
```

### 问题2: 模型检查点不存在

确保已下载预训练模型：
```bash
# 检查模型文件
ls -l pretrained_diffusion/bedrooms_bert/

# 如果不存在，需要下载预训练模型
```

### 问题3: CUDA内存不足

减少生成数量或批处理大小：
```bash
NUM_SEQUENCES=50  # 减少生成数量
BATCH_SIZE=25     # 减少批处理大小
```

### 问题4: 评估时间过长

使用快速测试模式：
```bash
./run_quick_evaluation.sh
```

## 📝 手动执行评估步骤

如果你想手动控制评估流程：

### 步骤1: 生成场景图像

```bash
python scripts/generate_diffusion.py \
    config/text/diffusion_bedrooms_instancond_lat32_v_bert.yaml \
    outputs/my_evaluation \
    3d_front_processed/threed_future_model_bedroom.pkl \
    --weight_file pretrained_diffusion/bedrooms_bert/model_32000 \
    --n_sequences 100 \
    --render_top2down \
    --without_screen \
    --background 1,1,1,1
```

### 步骤2: 计算FID和KID

```bash
python scripts/compute_fid_scores.py \
    3d_front_processed/bedrooms_objfeats_32_64 \
    outputs/my_evaluation \
    config/bedroom_threed_front_splits.csv
```

### 步骤3: 计算Precision和Recall

```bash
python scripts/improved_precision_recall.py \
    3d_front_processed/bedrooms_objfeats_32_64 \
    outputs/my_evaluation \
    config/bedroom_threed_front_splits.csv \
    --batch_size 50 \
    --num_samples 5000
```

## 📈 评估结果解读

### FID 分数
- **优秀**: < 30
- **良好**: 30-50
- **一般**: 50-100
- **较差**: > 100

### Precision 和 Recall
- **Precision (精确度)**: 0.0-1.0，越高表示生成质量越好
- **Recall (召回率)**: 0.0-1.0，越高表示生成多样性越好
- **F-score**: 综合指标，平衡质量和多样性

### 理想结果
- FID < 50
- Precision > 0.70
- Recall > 0.70
- F-score > 0.70

## 🔍 进阶用法

### 比较不同模型

```bash
# 评估模型A
./run_evaluation.sh  # 修改为使用 model_A

# 评估模型B
./run_evaluation.sh  # 修改为使用 model_B

# 比较结果
diff outputs/evaluation_*/evaluation_report.txt
```

### 批量评估多个检查点

创建循环脚本评估不同训练步数的检查点：

```bash
for step in 10000 20000 30000 40000; do
    MODEL_CHECKPOINT="pretrained_diffusion/bedrooms_bert/model_${step}"
    ./run_evaluation.sh
done
```

## 💡 提示

1. **生成数量**: 至少生成100个场景以获得可靠的评估结果
2. **GPU内存**: 确保有足够的GPU内存（建议至少8GB）
3. **存储空间**: 每个场景约需1-2MB存储空间
4. **评估时间**: 完整评估可能需要30-60分钟
5. **可重复性**: 设置随机种子以确保结果可重复

## 📞 需要帮助？

- 查看 README.md 了解更多项目信息
- 检查 scripts/ 目录中的评估脚本源码
- 参考原始论文中的评估方法

---

**注意**: 首次运行评估时，脚本会自动安装必要的依赖（如cleanfid）。
