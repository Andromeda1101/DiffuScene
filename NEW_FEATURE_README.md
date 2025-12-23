# 新功能：场景生成优化过程视频

## 📹 功能简介

现在可以生成场景优化过程的视频，展示扩散模型如何从随机噪声逐步生成最终的室内场景布局！

## 🚀 快速开始

### 最简单的方式（推荐）

```bash
cd run
./simple_example.sh
```

这会生成1个卧室场景的优化视频，包括：
- ✅ MP4格式视频文件
- ✅ 每个时间步的PNG图像
- ✅ 每个时间步的物体信息JSON

### 运行完整测试

```bash
# 测试无条件生成
cd run
./generate_progressive_video_test.sh

# 测试文本条件生成
./generate_progressive_video_text_test.sh
```

## 📁 输出文件

```
output_directory/progressive_video/
├── videos/        # 🎬 MP4视频（主要输出）
├── frames/        # 🖼️ 每帧的PNG图像
└── object_info/   # 📄 物体详细信息JSON
```

## 🔧 在自己的脚本中使用

只需添加3个参数：

```bash
python generate_diffusion.py ... \
    --save_progressive_video \      # 启用视频功能
    --video_num_steps 10 \          # 采样10个步骤
    --video_fps 5                   # 5帧每秒
```

## 📚 详细文档

- **快速上手**：[视频功能快速上手.md](视频功能快速上手.md) （中文）
- **完整指南**：[PROGRESSIVE_VIDEO_GUIDE.md](PROGRESSIVE_VIDEO_GUIDE.md) （英文）
- **实现细节**：[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)

## ✅ 验证安装

```bash
./verify_progressive_video.sh
```

## 💡 使用场景

- 📊 **研究分析**：观察生成过程，理解模型行为
- 🎓 **教学演示**：可视化扩散模型原理
- 📝 **论文展示**：制作动态演示材料
- 🐛 **调试优化**：发现和分析问题

## 📦 依赖安装

```bash
pip install opencv-python  # 用于视频生成
```

## ⚙️ 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--save_progressive_video` | False | 启用视频生成 |
| `--video_num_steps` | 10 | 采样的中间步骤数（5-20推荐）|
| `--video_fps` | 5 | 视频帧率（3-10推荐）|

## 📊 示例输出

生成的JSON文件格式：
```json
{
  "num_objects": 5,
  "objects": [
    {
      "object_id": 0,
      "class_label": "bed",
      "translation": {"x": 0.123, "y": 0.0, "z": -0.456},
      "size": {"x": 1.8, "y": 0.5, "z": 2.0},
      "rotation_angle": 1.57,
      "model_jid": "abc123"
    }
  ]
}
```

## 🎯 性能提示

- **快速测试**：使用 `--n_sequences 2 --video_num_steps 5`
- **高质量**：使用 `--video_num_steps 15-20`
- **节省空间**：使用 `--no_texture --without_floor`

## 🆘 遇到问题？

1. **视频生成失败** → 安装 opencv-python
2. **生成太慢** → 减少 video_num_steps 和 n_sequences
3. **内存不足** → 减少 video_num_steps
4. **其他问题** → 查看 [PROGRESSIVE_VIDEO_GUIDE.md](PROGRESSIVE_VIDEO_GUIDE.md) 的故障排除部分

## 📝 更新内容

- ✅ 新增 `save_object_info_json()` 工具函数
- ✅ 新增 `create_video_from_frames()` 工具函数  
- ✅ 修改 `generate_diffusion.py` 支持渐进式生成
- ✅ 创建测试脚本和文档
- ✅ 向后兼容，不影响现有功能

---

**开始使用**: `cd run && ./simple_example.sh` 🎬
