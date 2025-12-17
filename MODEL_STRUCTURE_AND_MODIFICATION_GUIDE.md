# DiffuScene 代码结构与“模型在哪里/改哪里”指南

本文面向需要快速定位 DiffuScene（场景布局扩散模型）核心代码的人：
- 模型（Diffusion / UNet / 条件分支）具体在哪些文件
- 训练与生成入口在哪些脚本
- 如果要改模型（结构/扩散过程/条件/数据表示）应该改哪些文件与配置字段

---

## 1. 项目中和“模型”直接相关的目录

建议从这几块看：

- `scripts/`
  - 训练/推理入口脚本（命令行参数 + 读 YAML 配置 + 构建 dataset + `build_network()`）

- `scene_synthesis/`
  - 真实的 Python 包（训练/生成脚本 import 的代码都在这里）
  - `scene_synthesis/networks/`：模型网络与扩散实现（本项目“模型主体”）
  - `scene_synthesis/datasets/`：数据集、编码/装饰器（决定输入字段、维度、是否 text、是否 diffusion）

- `config/`
  - 训练/推理使用的 YAML 配置
  - 子目录：`uncond/`、`text/`、`rearrange/`

- `run/`
  - 一键 shell 脚本，指定某个 config 直接跑训练/生成

---

## 2. 模型在什么位置？（调用链一图流）

训练和生成基本都是同一条链路：

1) `scripts/train_diffusion.py` / `scripts/generate_diffusion.py`

2) `scene_synthesis.networks.build_network(...)`

3) `scene_synthesis/networks/diffusion_scene_layout_ddpm.py: DiffusionSceneLayout_DDPM`

4) 其内部组合：
- 去噪网络：`scene_synthesis/networks/denoise_net.py: Unet1D`
- 扩散过程与采样：`scene_synthesis/networks/diffusion_ddpm.py: DiffusionPoint`（内部封装 `GaussianDiffusion`）

### 2.1 `build_network`：模型选择与权重加载入口

文件：`scene_synthesis/networks/__init__.py`

关键点：
- `config["network"]["type"]` 决定用哪种网络。
- 当前代码只实现了：`diffusion_scene_layout_ddpm` → 构建 `DiffusionSceneLayout_DDPM(...)`。
- 如果 `--weight_file` 传入，则这里会 `torch.load(...)` + `load_state_dict(...)` 加载权重。

### 2.2 顶层模型封装：`DiffusionSceneLayout_DDPM`

文件：`scene_synthesis/networks/diffusion_scene_layout_ddpm.py`

它做了三件事：
1) 构造条件（condition / condition_cross）
- `room_mask_condition`: 用 room mask + feature extractor 得到条件向量
- `text_condition`: 用文本得到 cross-attention 条件（支持 BERT / GloVe / CLIP）
- `instance_condition`: 为每个序列位置提供 instance embedding（可 learnable 或 MLP）
- `room_partial_condition` / `room_arrange_condition`: completion / rearrange 条件

2) 构造去噪网络（denoise net）
- `config["net_type"] == "unet1d"` → `Unet1D(**config["net_kwargs"])`

3) 构造扩散过程
- `self.diffusion = DiffusionPoint(denoise_net=denoise_net, config=config, **config["diffusion_kwargs"])`
- `get_loss()` 会准备 `room_layout_target`（由 translations/sizes/angles/class_labels/objfeats 等拼接）并调用
  `self.diffusion.get_loss_iter(..., condition=..., condition_cross=...)`
- `sample()/generate_layout()/complete_scene()/arrange_scene()` 走 `DiffusionPoint` 的不同 sampling 分支

### 2.3 去噪网络：`Unet1D`

文件：`scene_synthesis/networks/denoise_net.py`

关键点：
- 输入是形如 `(B, N, point_dim)` 的“点序列/对象序列”，内部会转置为 `(B, C, N)` 做 1D 卷积。
- 通过 `net_kwargs` 控制结构与维度：
  - `dim`, `dim_mults`：UNet 宽度/多尺度
  - `channels`: 输入通道（通常应与 point_dim 对齐）
  - `seperate_all`: 是否把 bbox/class/objectness/objfeats 分开编码再融合
  - `text_condition`, `text_dim`: 是否启用 cross-attention（文本条件）
  - `instanclass_dim`, `context_dim`: 条件拼接维度（与上层 condition 的构造强相关）

### 2.4 扩散过程：`DiffusionPoint` / `GaussianDiffusion`

文件：`scene_synthesis/networks/diffusion_ddpm.py`

- `DiffusionPoint`：封装模型（denoise net）+ `GaussianDiffusion`，提供训练 loss 与 sampling API
  - `get_loss_iter(...)`
  - `gen_samples(...)` / `gen_sample_traj(...)`
  - `complete_samples(...)`（completion）
  - `arrange_samples(...)`（rearrange）

- `GaussianDiffusion`：真正的 DDPM/高斯扩散实现
  - beta schedule: `get_betas(schedule_type, beta_start, beta_end, time_num)`
  - loss、预测类型：`loss_type`, `model_mean_type`（如 `eps`/`x0`/`v`）等

---

## 3. 训练 / 推理入口在哪？

### 3.1 训练入口

文件：`scripts/train_diffusion.py`

做的事情：
- 读 YAML：`load_config(args.config_file)`
- 构建训练/验证数据：`scene_synthesis.datasets.get_encoded_dataset(...)`
- 构建模型：`build_network(train_dataset.feature_size, train_dataset.n_classes, config, args.weight_file, device)`
- optimizer：`optimizer_factory(config["training"], filter(lambda p: p.requires_grad, network.parameters()))`
- 断点续训：`training_utils.load_checkpoints(network, optimizer, experiment_directory, args, device)`
  - 会加载 `experiment_directory/model_XXXXX` 与 `opt_XXXXX`

### 3.2 生成入口

文件：`scripts/generate_diffusion.py`

要点：
- 同样通过 `build_network(..., weight_file=args.weight_file)` 加载模型权重
- 使用 `get_dataset_raw_and_encoded(...)` 取 raw 与 encoded dataset
- 为“evaluation”会对 `config["data"]["encoding_type"]` 做一些字符串替换/追加（例如 text → textfix、追加 `_no_prm`）

### 3.3 一键脚本（推荐作为入口阅读）

文件：
- `run/train.sh`：无条件（uncond）训练，指向 `config/uncond/*.yaml`
- `run/train_text.sh`：文本条件训练，指向 `config/text/*.yaml`
- `run/train_rearrange.sh`：rearrange 训练，指向 `config/rearrange/*.yaml`

---

## 4. 配置（config）里哪些字段决定“模型形态”？

以 `config/uncond/diffusion_bedrooms_instancond_lat32_v.yaml` 为例，最关键的是 `network:` 这一段：

- `network.type`
  - 目前必须是：`diffusion_scene_layout_ddpm`（对应 `build_network()` 分支）

- `network.net_type`
  - 目前必须是：`unet1d`（对应 `DiffusionSceneLayout_DDPM` 里构建 denoise net）

- `network.diffusion_kwargs`
  - 控制扩散 schedule、timesteps、loss、预测类型（`model_mean_type`）等

- `network.net_kwargs`
  - 直接传给 `Unet1D(...)`，决定网络结构/维度/是否 text cross-attn

- 条件相关开关（在 `DiffusionSceneLayout_DDPM` 使用）：
  - `room_mask_condition: true/false`
  - `text_condition: true/false`（text config 会打开）
  - `room_arrange_condition: true/false`（rearrange config 会打开）
  - `room_partial_condition: true/false`（completion 类任务会打开）
  - `instance_condition`, `learnable_embedding`, `instance_emb_dim`

---

## 5. 如果要修改模型，需要改哪些文件？（按目标分类）

下面按“你想改什么”来给最小改动路径。

### 5.1 改去噪网络结构（UNet1D）

你想做的：改层数/宽度/注意力/输入输出 heads/是否 separate 编码。

需要动的地方：
- 核心代码：`scene_synthesis/networks/denoise_net.py`
  - 类：`Unet1D`
- 配置同步：`config/**/diffusion_*.yaml` 的 `network.net_kwargs`
  - 常见要一起改：`dim`, `dim_mults`, `seperate_all`, `merge_bbox`, `text_condition`, `text_dim`, `instanclass_dim`, `channels`

注意：
- 改了 `channels` / 输出维度后，旧 checkpoint 一般无法直接加载（`load_state_dict` 会 shape mismatch）。

### 5.2 改扩散过程（beta schedule / loss / sampling）

你想做的：换 beta schedule、改 loss、改 `model_mean_type`、改 sampling 逻辑。

需要动的地方：
- 核心代码：`scene_synthesis/networks/diffusion_ddpm.py`
  - `get_betas(...)`：beta schedule
  - `GaussianDiffusion`：loss、预测与反向采样
  - `DiffusionPoint`：对外暴露的 sampling API（gen/complete/arrange）

配置同步：`config/**/diffusion_*.yaml` 的 `network.diffusion_kwargs`
- `schedule_type`, `beta_start`, `beta_end`, `time_num`
- `loss_type`
- `model_mean_type`: `eps` / `x0` / `v`

### 5.3 改条件分支（room mask / instance / text / rearrange）

你想做的：
- 改“条件向量”的构造方式
- 引入/替换文本 encoder（目前支持 BERT / GloVe / CLIP）
- 改 cross-attention 输入

需要动的地方：
- 核心代码：`scene_synthesis/networks/diffusion_scene_layout_ddpm.py`
  - `DiffusionSceneLayout_DDPM.__init__`：条件模块定义
  - `get_loss(...)` / `sample(...)`：条件如何拼接为 `condition` / `condition_cross`

配置同步：`config/**/diffusion_*.yaml` 的 `network.*`
- `room_mask_condition`, `text_condition`, `text_embed_dim`
- `room_arrange_condition`, `arrange_emb_dim`
- `room_partial_condition`, `partial_num_points`, `partial_emb_dim`
- `instance_condition`, `learnable_embedding`, `instance_emb_dim`

并且要同步 `Unet1D`：
- `net_kwargs.text_condition`, `net_kwargs.text_dim`
- `net_kwargs.instanclass_dim`（等于上层拼出来的 condition 维度）

### 5.4 改“输入数据表示/字段/维度”（非常常见）

你想做的：
- 输入里包含哪些字段（是否包含 objfeats、是否把 angle 改为 sin/cos、是否包含 text）
- diffusion 的“target 拼接顺序与维度”

需要动的地方：
- 核心代码：`scene_synthesis/datasets/threed_front_dataset.py`
  - `dataset_encoding_factory(name, dataset, ...)`：根据 `encoding_type` 字符串决定装饰器链
  - 常见装饰器：
    - `Add_Text`（`name` 包含 `text`/`textfix`）
    - `Scale_CosinAngle_ObjfeatsNorm`（`name` 包含 `cosin_angle`/`objfeatsnorm`）
    - `Permutation(...)` + `Diffusion(...)`（`name` 包含 `diffusion`）

配置同步：`config/**/diffusion_*.yaml` 的 `data.encoding_type`
- 例如：`cached_diffusion_text_cosin_angle_objfeatsnorm_lat32_wocm`

注意：
- `DiffusionSceneLayout_DDPM.get_loss()` 里会按 `point_dim` 判断如何拼 `room_layout_target`，
  所以你改了字段/维度，通常需要同时改：
  - config: `network.point_dim`、`network.class_dim`、`network.angle_dim`、`network.objfeat_dim` 等
  - config: `network.net_kwargs.channels`（通常应与 `point_dim` 一致）
  - 以及 dataset encoding 里到底输出了哪些 key（例如 `objfeats` vs `objfeats_32`）

---

## 6. 最容易踩坑的地方（建议先看）

- checkpoint 不兼容：
  - 只要改了 `point_dim` / `channels` / `class_dim` / `objfeat_dim` / UNet 宽度层数，旧权重多半不能直接 `load_state_dict`。

- `encoding_type` 与模型维度必须一致：
  - dataset 输出哪些字段、角度是否 cos/sin、objfeats 是 32 还是 64，都会影响最终 `room_layout_target` 维度。

- text 条件是 cross-attention：
  - `DiffusionSceneLayout_DDPM` 里 `condition_cross` 可能是 `(B, L_text, D)`（BERT）或 `(B, D)`（CLIP），
    这会影响 `Unet1D` 的 cross-attn 模块期望输入形状；改 text 分支时要一起核对。

---

## 7. 快速定位清单（TL;DR）

- “扩散模型主类在哪里？”
  - `scene_synthesis/networks/diffusion_scene_layout_ddpm.py: DiffusionSceneLayout_DDPM`

- “UNet 去噪网络在哪里？”
  - `scene_synthesis/networks/denoise_net.py: Unet1D`

- “扩散过程/采样在哪里？”
  - `scene_synthesis/networks/diffusion_ddpm.py: DiffusionPoint / GaussianDiffusion`

- “训练入口在哪里？”
  - `scripts/train_diffusion.py`

- “生成入口在哪里？”
  - `scripts/generate_diffusion.py`

- “配置如何选模型？”
  - `scene_synthesis/networks/__init__.py: build_network()` + `config/**/diffusion_*.yaml`

- “数据编码（encoding_type）在哪里决定？”
  - `scene_synthesis/datasets/__init__.py` → `scene_synthesis/datasets/threed_front_dataset.py: dataset_encoding_factory()`
