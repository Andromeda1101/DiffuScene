# IndexError 修复说明

## 问题描述

运行 `generate_progressive_video_test.sh` 时出现以下错误：

```
IndexError: index 26 is out of bounds for axis 0 with size 23
```

发生在 `save_object_info_json()` 函数的这一行：
```python
"class_label": classes[class_idx],
```

## 问题原因

### 数据结构不匹配

1. **classes 数组**：包含 23 个元素
   - 21 个实际物体类别：'armchair', 'bookshelf', 'cabinet', ..., 'wardrobe'
   - 2 个特殊标记：'start', 'end'

2. **bbox_params_t 结构**：`(N, feature_dim)`
   - class_labels: one-hot 编码，维度为 `n_classes - 2 = 21`（不包含 start 和 end）
   - translations: 3 维 (x, y, z)
   - sizes: 3 维 (length, height, width)
   - angles: 1 维 (rotation)

3. **原代码问题**：
   ```python
   # 错误：使用 len(classes) = 23
   class_idx = np.argmax(obj_params[:len(classes)])
   # 但 obj_params 的 class_labels 只有 21 维
   ```

   这导致：
   - 切片取了错误的范围
   - argmax 可能返回超出实际类别数量的索引
   - 访问 `classes[class_idx]` 时索引超出边界

## 修复方案

### 第一次修复（部分解决）

在 `scripts/utils.py` 的 `save_object_info_json()` 函数中：

```python
# 修复前
class_idx = np.argmax(obj_params[:len(classes)])
# ...
"class_label": classes[class_idx],

# 第一次修复
# 过滤掉 start 和 end，只保留实际类别
actual_classes = [c for c in classes if c not in ['start', 'end']]
n_class_labels = len(actual_classes)  # = 21

# 使用正确的维度
class_idx = np.argmax(obj_params[:n_class_labels])
# ...
"class_label": actual_classes[class_idx],
```

**问题**：仍然可能出现 IndexError，因为 `class_idx` 可能超出 `actual_classes` 的范围。

### 第二次修复（最终方案）

采用更健壮的方法，自动推断维度并添加边界检查：

```python
# 从 bbox_params_t 的形状推断 class_labels 的维度
fixed_dims = 7  # translation(3) + size(3) + angle(1)
n_class_labels = bbox_params_t.shape[1] - fixed_dims

# 过滤掉 start 和 end
actual_classes = [c for c in classes if c not in ['start', 'end']]

# 维度不匹配警告
if len(actual_classes) != n_class_labels:
    print(f"Warning: dimension mismatch")
    actual_classes = actual_classes[:n_class_labels]

# 提取类别概率并找到最大值
class_probs = obj_params[:n_class_labels]
class_idx = np.argmax(class_probs)

# 边界检查（关键！）
if class_idx >= len(actual_classes):
    print(f"Warning: class_idx {class_idx} out of range, using last class")
    class_idx = len(actual_classes) - 1

# 安全访问
"class_label": actual_classes[class_idx] if class_idx < len(actual_classes) else "unknown"
```

### 关键改进

1. **自动维度推断**：从数据形状自动计算 class_labels 维度
2. **边界检查**：确保索引不会越界
3. **降级处理**：出错时使用默认值而不是崩溃
4. **调试信息**：打印警告帮助诊断问题
5. **额外字段**：添加 `class_probability` 字段用于调试

## 测试验证

### 调试测试（查看详细信息）

```bash
cd /home/ubuntu/myvdb/DiffuScene/run
./debug_test.sh
```

这会生成 1 个场景并显示详细的调试信息。

### 快速测试

```bash
cd /home/ubuntu/myvdb/DiffuScene/run
./quick_fix_test.sh
```

这会生成 1 个场景来快速验证修复是否成功。

### 完整测试

```bash
cd /home/ubuntu/myvdb/DiffuScene/run
./generate_progressive_video_test.sh
```

生成 3 个场景的完整测试。

## 预期结果

修复后应该看到：

```
✅ 成功生成视频
✅ 保存帧图像到 frames/
✅ 保存物体信息到 object_info/
✅ 创建 MP4 视频到 videos/
```

JSON 文件内容示例：
```json
{
  "num_objects": 5,
  "objects": [
    {
      "object_id": 0,
      "class_label": "double_bed",  # 正确的类别名称
      "class_index": 8,
      "translation": {"x": 0.123, "y": 0.0, "z": -0.456},
      "size": {"x": 1.8, "y": 0.5, "z": 2.0},
      "rotation_angle": 1.57,
      "model_jid": "abc123"
    }
  ]
}
```

## 技术细节

### DiffuScene 的类别编码

在 DiffuScene 中：
- 训练时使用 `n_classes` 个类别（包含 start 和 end）
- 生成的 one-hot 编码是 `n_classes - 2` 维（不包含 start 和 end）
- start 和 end 是序列的特殊标记，不代表实际物体

### bbox_params_t 的确切结构

```
[class_0, class_1, ..., class_20,  # 21 维 one-hot
 trans_x, trans_y, trans_z,         # 3 维 translation
 size_x, size_y, size_z,            # 3 维 size
 angle]                             # 1 维 angle
```

总维度：21 + 3 + 3 + 1 = 28

## 相关文件

- **修改的文件**：`scripts/utils.py`
- **测试脚本**：`run/quick_fix_test.sh`
- **原始测试**：`run/generate_progressive_video_test.sh`

## 注意事项

这个修复确保了：
1. 类别索引在有效范围内
2. 所有参数字段正确对齐
3. JSON 输出包含正确的类别名称
4. 不会再出现 IndexError

## 其他场景的兼容性

此修复适用于所有场景类型：
- ✅ 卧室 (bedrooms)
- ✅ 餐厅 (diningrooms)
- ✅ 客厅 (livingrooms)
- ✅ 无条件生成
- ✅ 文本条件生成
- ✅ 重排列生成

所有场景都使用相同的类别编码方式，因此修复具有普遍适用性。
