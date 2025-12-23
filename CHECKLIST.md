# 视频生成功能 - 使用检查清单

## ✅ 安装前检查

- [ ] 已安装 DiffuScene 的所有原始依赖
- [ ] 已下载预训练模型到 `pretrained_diffusion/` 目录
- [ ] 已下载 3D-FRONT 数据集
- [ ] 已下载 3D-FUTURE 模型到 `dataset/3D-FUTURE-model/`

## ✅ 安装视频生成依赖

```bash
# 二选一即可
pip install opencv-python  # 推荐
# 或
pip install imageio        # 备选
```

- [ ] 已安装 opencv-python 或 imageio

## ✅ 验证安装

```bash
cd /home/ubuntu/myvdb/DiffuScene
./verify_progressive_video.sh
```

- [ ] 验证脚本显示 "所有检查通过"
- [ ] 没有红色错误信息

## ✅ 运行快速测试（推荐新手）

```bash
cd /home/ubuntu/myvdb/DiffuScene/run
./simple_example.sh
```

**预期结果：**
- [ ] 脚本无错误完成
- [ ] 生成了 `../outputs/simple_video_demo/progressive_video/` 目录
- [ ] `videos/` 文件夹中有 .mp4 文件
- [ ] `frames/` 文件夹中有多个 .png 文件
- [ ] `object_info/` 文件夹中有 .json 文件

## ✅ 检查输出

```bash
# 查看视频文件
ls -lh ../outputs/simple_video_demo/progressive_video/videos/

# 查看第一个JSON文件
cat ../outputs/simple_video_demo/progressive_video/object_info/*.json | head -30

# 统计生成的帧数
ls ../outputs/simple_video_demo/progressive_video/frames/*.png | wc -l
```

**预期结果：**
- [ ] 视频文件大小 > 0（通常 1-5 MB）
- [ ] JSON 文件包含物体信息（class_label, translation, size 等）
- [ ] 帧数量 = video_num_steps + 1（默认是6帧）

## ✅ 运行完整测试

```bash
cd /home/ubuntu/myvdb/DiffuScene/run

# 测试1：无条件生成（3个场景，10个步骤）
./generate_progressive_video_test.sh
```

**预期时间：** 约 10-20 分钟（取决于GPU）

- [ ] 脚本无错误完成
- [ ] 生成了3个场景的视频
- [ ] 输出在 `../pretrained/bedrooms_uncond/test_progressive_video/`

```bash
# 测试2：文本条件生成（需要BERT模型）
./generate_progressive_video_text_test.sh
```

- [ ] 脚本无错误完成
- [ ] 生成了3个基于文本的场景视频
- [ ] 输出在 `../pretrained/bedrooms_bert/test_progressive_video/`

## ✅ 在自己的项目中使用

### 修改现有脚本

编辑任何 `run/generate*.sh` 文件，添加三行：

```bash
xvfb-run -a python generate_diffusion.py ... \
    --save_progressive_video \      # 添加这行
    --video_num_steps 10 \          # 添加这行
    --video_fps 5                   # 添加这行
```

- [ ] 已修改脚本
- [ ] 测试运行成功

### 直接使用Python命令

```bash
cd scripts
xvfb-run -a python generate_diffusion.py \
    [config] [output_dir] [dataset] \
    --weight_file [weight] \
    --save_progressive_video \
    --video_num_steps 10 \
    --video_fps 5 \
    [其他参数...]
```

- [ ] 命令运行成功
- [ ] 生成了预期的输出

## ✅ 常见问题排查

### 问题1：ImportError: No module named 'cv2'
```bash
pip install opencv-python
```
- [ ] 已解决

### 问题2：生成速度太慢
**解决方案：**
- 减少 `--video_num_steps`（如改为5）
- 减少 `--n_sequences`（如改为2）
- [ ] 已优化参数

### 问题3：CUDA out of memory
**解决方案：**
- 减少 `--video_num_steps`
- 关闭其他GPU程序
- [ ] 已解决

### 问题4：视频播放有问题
**解决方案：**
- 使用 VLC Media Player 打开
- 检查文件大小是否 > 0
- 重新安装 opencv-python
- [ ] 已解决

### 问题5：找不到权重文件
**解决方案：**
- 检查 `pretrained_diffusion/` 目录
- 下载对应的预训练模型
- 更新脚本中的 weight_file 路径
- [ ] 已解决

## ✅ 性能优化建议

### 快速测试配置
```bash
--n_sequences 2 \
--video_num_steps 5 \
--video_fps 5
```
- [ ] 用于快速验证功能

### 标准配置
```bash
--n_sequences 10 \
--video_num_steps 10 \
--video_fps 5
```
- [ ] 用于正常使用

### 高质量配置
```bash
--n_sequences 50 \
--video_num_steps 20 \
--video_fps 8
```
- [ ] 用于最终结果展示

## ✅ 文档参考

完成检查后，参考以下文档深入了解：

1. **[NEW_FEATURE_README.md](NEW_FEATURE_README.md)** - 功能概览
2. **[视频功能快速上手.md](视频功能快速上手.md)** - 中文快速指南
3. **[PROGRESSIVE_VIDEO_GUIDE.md](PROGRESSIVE_VIDEO_GUIDE.md)** - 完整英文文档
4. **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - 技术实现细节

- [ ] 已阅读相关文档

## 🎉 完成！

如果所有检查项都已完成，恭喜您已成功设置并使用视频生成功能！

**开始创作您的场景生成视频吧！** 🎬✨

---

**需要帮助？** 查看 [PROGRESSIVE_VIDEO_GUIDE.md](PROGRESSIVE_VIDEO_GUIDE.md) 的故障排除部分
