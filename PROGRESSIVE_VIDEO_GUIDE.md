# 生成优化过程视频功能说明

## 功能概述

该功能可以生成场景优化过程中物体布局变化的视频，展示从初始噪声到最终场景的整个生成过程。同时会保存每个时间步的物体信息（类别、位置、尺寸、旋转角度等）到JSON文件中。

## 新增功能

### 1. 命令行参数

在 `generate_diffusion.py` 中新增了三个参数：

- `--save_progressive_video`: 激活视频生成功能（布尔标志）
- `--video_num_steps`: 采样的中间步骤数量（默认：10）
- `--video_fps`: 输出视频的帧率（默认：5 FPS）

### 2. 输出结构

启用该功能后，会在输出目录下创建 `progressive_video/` 文件夹，包含：

```
progressive_video/
├── frames/              # 每个时间步的渲染图像
│   ├── scene_id_scene000_step0000.png
│   ├── scene_id_scene000_step0001.png
│   └── ...
├── object_info/         # 每个时间步的物体信息JSON文件
│   ├── scene_id_scene000_step0000.json
│   ├── scene_id_scene000_step0001.json
│   └── ...
└── videos/              # 最终生成的MP4视频
    ├── scene_id_scene000_progressive.mp4
    └── ...
```

### 3. JSON物体信息格式

每个JSON文件包含该时间步所有物体的详细信息：

```json
{
  "num_objects": 5,
  "objects": [
    {
      "object_id": 0,
      "class_label": "bed",
      "class_index": 3,
      "translation": {
        "x": 0.123,
        "y": 0.0,
        "z": -0.456
      },
      "size": {
        "x": 1.8,
        "y": 0.5,
        "z": 2.0
      },
      "rotation_angle": 1.57,
      "model_jid": "abc123"
    },
    ...
  ]
}
```

## 使用方法

### 方法1：使用提供的测试脚本

我们提供了两个测试脚本：

#### 测试无条件生成：
```bash
cd /home/ubuntu/myvdb/DiffuScene/run
./generate_progressive_video_test.sh
```

#### 测试文本条件生成：
```bash
cd /home/ubuntu/myvdb/DiffuScene/run
./generate_progressive_video_text_test.sh
```

### 方法2：手动运行

```bash
cd scripts

# 卧室场景示例
xvfb-run -a python generate_diffusion.py \
    ../config/uncond/diffusion_bedrooms_instancond_lat32_v.yaml \
    ../output/test_progressive \
    ../3d_front_processed/threed_future_model_bedroom.pkl \
    --weight_file ../pretrained_diffusion/bedrooms_uncond/model_30000 \
    --without_screen \
    --n_sequences 5 \
    --render_top2down \
    --save_mesh \
    --no_texture \
    --without_floor \
    --clip_denoised \
    --retrive_objfeats \
    --save_progressive_video \
    --video_num_steps 10 \
    --video_fps 5 \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model
```

### 方法3：修改现有的shell脚本

在现有的 `generate.sh`, `generate_text.sh` 等脚本中添加参数：

```bash
xvfb-run -a python generate_diffusion.py $config $exp_dir/$exp_name/output $threed_future \
    --weight_file $weight_file \
    --without_screen \
    --n_sequences 150 \
    --render_top2down \
    --save_mesh \
    --no_texture \
    --without_floor \
    --clip_denoised \
    --retrive_objfeats \
    --save_progressive_video \        # 新增
    --video_num_steps 10 \            # 新增
    --video_fps 5 \                   # 新增
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model
```

## 参数说明

- **--video_num_steps**: 控制视频的长度和细节程度
  - 较小值（如5）：视频较短，只显示关键变化步骤
  - 较大值（如20）：视频较长，显示更详细的渐进过程
  - 推荐值：8-12

- **--video_fps**: 控制视频播放速度
  - 较小值（如3）：播放较慢，便于观察细节
  - 较大值（如10）：播放较快，快速浏览整个过程
  - 推荐值：5-8

## 依赖要求

该功能需要以下Python库之一来生成视频：

- **opencv-python** (推荐)
- **imageio** (备选)

安装命令：
```bash
pip install opencv-python
# 或
pip install imageio
```

如果两个都未安装，脚本仍会生成单独的帧图像和JSON文件，但不会创建MP4视频。

## 技术细节

### 实现原理

1. 使用 `generate_layout_progressive()` 方法代替常规的 `generate_layout()`
2. 该方法调用扩散模型的 `p_sample_loop_trajectory()`，按指定频率采样中间状态
3. 对每个采样的时间步：
   - 后处理获得物体参数
   - 检索对应的3D模型
   - 渲染为2D图像
   - 保存物体信息到JSON
4. 最后将所有帧合成为MP4视频

### 时间步采样

假设扩散模型总共1000步，`video_num_steps=10`：
- 采样频率 = 1000 / 10 = 100
- 采样时间步：900, 800, 700, ..., 100, 0
- 共11帧（包含最终结果）

### 性能考虑

- 生成视频比常规生成慢约 `video_num_steps` 倍
- 建议在测试时先用较小的 `n_sequences` 和 `video_num_steps`
- 每个场景的视频大小约1-5MB（取决于分辨率和帧数）

## 示例输出

运行测试脚本后，查看输出：

```bash
# 查看生成的视频
ls ../pretrained/bedrooms_uncond/test_progressive_video/progressive_video/videos/

# 查看物体信息
cat ../pretrained/bedrooms_uncond/test_progressive_video/progressive_video/object_info/scene_id_scene000_step0000.json
```

## 故障排除

### 问题1：视频生成失败
**解决方案**：检查是否安装了opencv-python或imageio
```bash
pip list | grep -E "opencv|imageio"
```

### 问题2：内存不足
**解决方案**：减少 `video_num_steps` 或 `n_sequences`

### 问题3：渲染图像全黑
**解决方案**：检查是否正确设置了 `--path_to_3d_future_models_dir`

### 问题4：生成速度太慢
**解决方案**：
- 减少 `video_num_steps`
- 使用 `--no_texture` 禁用纹理
- 使用 `--without_floor` 移除地板

## 应用场景

1. **研究分析**：观察扩散模型如何逐步生成场景布局
2. **演示展示**：制作动态展示视频
3. **调试优化**：分析生成过程中的问题
4. **论文可视化**：为论文或报告提供可视化素材

## 未来扩展

可能的改进方向：
- 支持3D视角的旋转视频
- 添加时间戳和统计信息叠加
- 支持GIF动画输出
- 并行处理多个场景的视频生成
