#!/bin/bash
# 测试脚本：使用文本条件生成优化过程视频
# 该脚本用于测试基于文本描述的场景生成中物体布局变化的视频生成功能
# Please update the path to your own environment in config.yaml and following arguments before running the script

cd ./scripts
export HF_ENDPOINT="https://hf-mirror.com"

exp_dir="../pretrained"
pretrained_model_dir="../pretrained_diffusion"

####'bedrooms' - 测试文本条件生成的视频
echo "========================================="
echo "Testing progressive video generation for bedrooms (text-conditioned)"
echo "========================================="
config="../config/text/diffusion_bedrooms_instancond_lat32_v_bert.yaml"
exp_name="bedrooms_bert"
weight_file=$pretrained_model_dir/$exp_name/model_32000 
threed_future='../3d_front_processed/threed_future_model_bedroom.pkl'

# 只生成3个场景用于测试，使用8个中间步骤，6 FPS
xvfb-run -a python generate_diffusion.py $config $exp_dir/$exp_name/test_progressive_video $threed_future \
    --weight_file $weight_file \
    --without_screen \
    --n_sequences 3 \
    --render_top2down \
    --save_mesh \
    --no_texture \
    --without_floor \
    --clip_denoised \
    --retrive_objfeats \
    --save_progressive_video \
    --video_num_steps 8 \
    --video_fps 6 \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model

echo ""
echo "========================================="
echo "Bedrooms (text-conditioned) test completed!"
echo "Check output in: $exp_dir/$exp_name/test_progressive_video/progressive_video/"
echo "  - frames/: Individual frame images"
echo "  - object_info/: JSON files with object information for each frame"
echo "  - videos/: Generated MP4 videos"
echo "========================================="
echo ""

# 可选：测试其他房间类型，取消下面的注释

# ####'diningrooms' - 测试文本条件的餐厅场景
# echo "========================================="
# echo "Testing progressive video generation for diningrooms (text-conditioned)"
# echo "========================================="
# config="../config/text/diffusion_diningrooms_instancond_lat32_v_bert.yaml"
# exp_name="diningrooms_bert"
# weight_file=$pretrained_model_dir/$exp_name/model_148000
# threed_future='../3d_front_processed/threed_future_model_diningroom.pkl'
# 
# xvfb-run -a python generate_diffusion.py $config $exp_dir/$exp_name/test_progressive_video $threed_future \
#     --weight_file $weight_file \
#     --without_screen \
#     --n_sequences 2 \
#     --render_top2down \
#     --save_mesh \
#     --no_texture \
#     --without_floor \
#     --clip_denoised \
#     --retrive_objfeats \
#     --save_progressive_video \
#     --video_num_steps 8 \
#     --video_fps 6 \
#     --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model
# 
# echo "Diningrooms (text-conditioned) test completed!"
# echo ""

echo "========================================="
echo "All text-conditioned tests completed!"
echo "========================================="
