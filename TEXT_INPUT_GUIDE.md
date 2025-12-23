# 文本输入场景生成功能使用指南

## 功能概述

本功能允许用户通过多种方式输入文本描述来生成3D室内场景，支持：
- **命令行输入**：直接在命令行参数中提供文本描述
- **单文件输入**：从单个.txt文件读取文本描述
- **批量目录输入**：从目录中读取所有.txt文件进行批量生成

所有输入和输出都会被自动保存，便于后续分析。

## 安装要求

确保已安装所有依赖包：
```bash
pip install -r requirements.txt
```

## 快速开始

### 1. 命令行文本输入

最简单的方式，直接在命令中指定文本：

```bash
cd run
bash generate_text_input.sh
```

在脚本中修改Example 1部分，取消注释：

```bash
xvfb-run -a python generate_from_text_input.py $config $output_dir/command_line_test $threed_future \
    --weight_file $weight_file \
    --enable_text_input \
    --text "a bedroom with a large bed, two nightstands, and a wardrobe" \
    --without_screen \
    --n_sequences 5 \
    --render_top2down \
    --save_mesh \
    --no_texture \
    --without_floor \
    --clip_denoised \
    --retrive_objfeats \
    --save_records \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model
```

### 2. 单文件输入

从文件读取文本描述：

1. 创建文本文件（例如：`demo/my_room.txt`）：
```
a cozy bedroom with a queen-size bed, two nightstands, and a reading chair
```

2. 修改脚本中的Example 2，取消注释并指定文件路径：
```bash
xvfb-run -a python generate_from_text_input.py $config $output_dir/single_file_test $threed_future \
    --weight_file $weight_file \
    --enable_text_input \
    --text_file ../demo/my_room.txt \
    --without_screen \
    --n_sequences 5 \
    --render_top2down \
    --save_mesh \
    --clip_denoised \
    --retrive_objfeats \
    --save_records \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model
```

### 3. 批量目录输入（推荐）

这是处理多个文本描述的最高效方式：

1. 在`demo/text_inputs/`目录下创建多个.txt文件：
```bash
demo/text_inputs/
├── bedroom_01.txt
├── bedroom_02.txt
├── livingroom_01.txt
└── diningroom_01.txt
```

2. 使用默认配置运行（Example 3已默认启用）：
```bash
cd run
bash generate_text_input.sh
```

## 参数说明

### 必需参数

- `config_file`: 配置文件路径（例如：`config/text/diffusion_bedrooms_instancond_lat32_v_bert.yaml`）
- `output_directory`: 输出目录路径
- `path_to_pickled_3d_futute_models`: 3D模型pickle文件路径

### 文本输入参数（互斥，三选一）

- `--text TEXT`: 命令行直接输入文本描述
- `--text_file FILE`: 单个文本文件路径
- `--text_dir DIR`: 包含多个.txt文件的目录路径

### 功能开关

- `--enable_text_input`: **必需**，启用自定义文本输入功能
- `--save_records`: 保存输入输出记录（默认启用）

### 生成参数

- `--n_sequences N`: 每个文本生成的场景数量（默认：10）
- `--render_top2down`: 渲染俯视图
- `--save_mesh`: 保存3D网格文件
- `--no_texture`: 不使用纹理
- `--without_floor`: 不包含地板
- `--clip_denoised`: 裁剪去噪值
- `--retrive_objfeats`: 基于物体特征检索最相似的模型
- `--mesh_format FORMAT`: 网格文件格式（默认：.ply）

### 场景参数

- `--scene_id ID`: 指定用于条件生成的场景ID（可选）
- `--weight_file FILE`: 预训练模型权重文件路径
- `--path_to_3d_future_models_dir DIR`: 3D-FUTURE模型目录

## 输出结构

生成的输出会按以下结构组织：

```
output_directory/
├── generation_records.jsonl          # 所有生成记录（JSON Lines格式）
├── text_0000_bedroom_01/             # 第一个文本的输出
│   ├── input_text.txt                # 输入文本副本
│   ├── generation_summary.json       # 生成摘要
│   ├── seq_000_scene_id.png          # 渲染图像
│   ├── seq_000_scene_id.ply          # 3D网格文件
│   ├── seq_001_scene_id.png
│   ├── seq_001_scene_id.ply
│   └── ...
├── text_0001_bedroom_02/             # 第二个文本的输出
│   └── ...
└── text_0002_livingroom_01/          # 第三个文本的输出
    └── ...
```

### 输出文件说明

1. **generation_records.jsonl**: 包含所有生成的详细记录，每行一个JSON对象，包括：
   - 时间戳
   - 输入文本
   - 文本来源
   - 场景ID
   - 物体数量
   - 输出文件路径
   - 配置参数

2. **input_text.txt**: 保存的输入文本描述副本

3. **generation_summary.json**: 该文本输入的生成摘要，包括：
   - 输入文本
   - 生成数量
   - 生成时间
   - 配置信息

4. **seq_XXX_scene_id.png**: 渲染的俯视图图像

5. **seq_XXX_scene_id.ply**: 3D场景网格文件

## 房间类型配置

在`run/generate_text_input.sh`中修改`ROOM_TYPE`变量来选择房间类型：

```bash
ROOM_TYPE="bedrooms"      # 卧室
# ROOM_TYPE="diningrooms"  # 餐厅
# ROOM_TYPE="livingrooms"  # 客厅
```

每种房间类型使用对应的配置文件和预训练模型：
- **bedrooms**: `config/text/diffusion_bedrooms_instancond_lat32_v_bert.yaml`
- **diningrooms**: `config/text/diffusion_diningrooms_instancond_lat32_v_bert.yaml`
- **livingrooms**: `config/text/diffusion_livingrooms_instancond_lat32_v_bert.yaml`

## 使用示例

### 示例1：生成多个卧室场景

```bash
# 1. 创建文本描述文件
echo "a minimalist bedroom with a double bed and a nightstand" > demo/text_inputs/minimal_bedroom.txt
echo "a luxurious bedroom with a king-size bed, two nightstands, and a wardrobe" > demo/text_inputs/luxury_bedroom.txt

# 2. 设置房间类型为bedrooms
# 编辑 run/generate_text_input.sh，设置 ROOM_TYPE="bedrooms"

# 3. 运行生成
cd run
bash generate_text_input.sh
```

### 示例2：生成客厅场景

```bash
# 1. 创建文本描述
echo "a modern living room with a sofa, coffee table, and TV stand" > demo/text_inputs/modern_living.txt

# 2. 设置房间类型为livingrooms
# 编辑 run/generate_text_input.sh，设置 ROOM_TYPE="livingrooms"

# 3. 运行生成
cd run
bash generate_text_input.sh
```

### 示例3：使用命令行快速测试

```bash
cd scripts

python generate_from_text_input.py \
    ../config/text/diffusion_bedrooms_instancond_lat32_v_bert.yaml \
    ../outputs/test_generation \
    ../3d_front_processed/threed_future_model_bedroom.pkl \
    --weight_file ../pretrained_diffusion/bedrooms_bert/model_32000 \
    --enable_text_input \
    --text "a simple bedroom with a bed and a desk" \
    --n_sequences 3 \
    --render_top2down \
    --save_mesh \
    --clip_denoised \
    --retrive_objfeats \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model
```

## 数据分析

生成完成后，可以使用`generation_records.jsonl`文件进行分析：

```python
import json
import pandas as pd

# 读取所有记录
records = []
with open('output_directory/generation_records.jsonl', 'r') as f:
    for line in f:
        records.append(json.loads(line))

# 转换为DataFrame进行分析
df = pd.DataFrame(records)

# 分析示例
print(f"总生成数量: {len(df)}")
print(f"平均物体数量: {df['num_objects'].mean():.2f}")
print(f"文本来源统计:\n{df['text_source'].value_counts()}")

# 按文本分组统计
text_stats = df.groupby('input_text').agg({
    'sequence_index': 'count',
    'num_objects': 'mean'
}).rename(columns={'sequence_index': 'count', 'num_objects': 'avg_objects'})
print(text_stats)
```

## 注意事项

1. **文本描述建议**：
   - 使用清晰、具体的物体描述（如"a bed", "two nightstands"）
   - 包含布局信息（如"centered", "by the window"）
   - 适合房间类型（卧室、客厅、餐厅）

2. **性能考虑**：
   - 批量目录输入比多次单独运行更高效
   - 使用`--n_sequences`控制每个文本的生成数量
   - GPU加速可显著提升生成速度

3. **文件格式**：
   - 文本文件必须是UTF-8编码
   - 文件扩展名必须是`.txt`
   - 避免文件名中使用特殊字符

4. **输出管理**：
   - 定期清理输出目录以节省空间
   - 使用有意义的输出目录名称
   - 保留`generation_records.jsonl`用于追踪

## 故障排除

### 问题：找不到文本文件
**解决方案**：检查文件路径是否正确，确保文件存在且扩展名为`.txt`

### 问题：生成质量不佳
**解决方案**：
- 确保使用正确的房间类型配置
- 检查文本描述是否与房间类型匹配
- 尝试调整`--clip_denoised`和`--retrive_objfeats`参数

### 问题：显存不足
**解决方案**：
- 减少`--n_sequences`数量
- 使用较小的batch size
- 关闭不必要的选项（如`--save_mesh`）

### 问题：无法读取目录中的文件
**解决方案**：
- 确保目录路径正确
- 检查目录中是否有`.txt`文件
- 确认文件权限允许读取

## 高级用法

### 自定义生成参数

可以通过修改脚本或直接调用Python脚本来自定义更多参数：

```bash
python generate_from_text_input.py \
    $config $output_dir $threed_future \
    --weight_file $weight_file \
    --enable_text_input \
    --text_dir ../demo/text_inputs \
    --n_sequences 10 \
    --render_top2down \
    --save_mesh \
    --mesh_format .obj \
    --clip_denoised \
    --retrive_objfeats \
    --scene_id <specific_scene_id> \
    --background 0.8,0.8,0.8,1 \
    --window_size 1024,1024
```

### 集成到自动化流程

```bash
#!/bin/bash
# 自动化批量生成流程

TEXT_DIR="../demo/text_inputs"
OUTPUT_BASE="../outputs/batch_$(date +%Y%m%d_%H%M%S)"

# 为每种房间类型生成场景
for ROOM_TYPE in bedrooms livingrooms diningrooms; do
    echo "Processing $ROOM_TYPE..."
    
    # 设置配置
    # ... (根据ROOM_TYPE设置config和weight_file)
    
    # 运行生成
    python generate_from_text_input.py \
        $config "$OUTPUT_BASE/$ROOM_TYPE" $threed_future \
        --weight_file $weight_file \
        --enable_text_input \
        --text_dir $TEXT_DIR \
        --n_sequences 5 \
        --render_top2down \
        --save_mesh \
        --clip_denoised \
        --retrive_objfeats
done

echo "All generations completed!"
```

## 相关文档

- [README.md](../README.md) - 项目主文档
- [快速上手指南.md](../快速上手指南.md) - 项目快速开始
- [WANDB_GUIDE.md](../WANDB_GUIDE.md) - W&B集成指南
- [PROGRESSIVE_VIDEO_GUIDE.md](../PROGRESSIVE_VIDEO_GUIDE.md) - 渐进视频生成指南

## 更新日志

### v1.0.0 (2024)
- 初始版本
- 支持命令行、单文件、批量目录输入
- 自动保存输入输出记录
- 完整的配置选项和文档

## 贡献

如有问题或建议，请提交Issue或Pull Request。

## 许可证

本项目遵循与DiffuScene主项目相同的许可证。
