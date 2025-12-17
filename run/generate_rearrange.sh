#!/bin/bash
# Please update the path to your own environment in config.yaml and following arguments befrore running the script

cd ./scripts

exp_dir="../pretrained"
pretrained_model_dir="../pretrained_diffusion"

####'bedrooms'
config="../config/rearrange/diffusion_bedrooms_instancond_lat32_v_rearrange.yaml"
exp_name="bedrooms_rearrange"
weight_file=$pretrained_model_dir/$exp_name/model_17000
threed_future='../3d_front_processed/threed_future_model_bedroom.pkl'

xvfb-run -a python  completion_rearrange.py $config  $exp_dir/$exp_name/gen_top2down_notexture_nofloor $threed_future  --weight_file $weight_file \
    --without_screen  --n_sequences 150 --render_top2down --no_texture --without_floor  --save_mesh --clip_denoised --retrive_objfeats --arrange_objects  --compute_intersec \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model

####'livingrooms'
config="../config/rearrange/diffusion_livingrooms_instancond_lat32_v_rearrange.yaml"
exp_name="livingrooms_rearrange"
weight_file=$pretrained_model_dir/$exp_name/model_81000
threed_future='../3d_front_processed/threed_future_model_livingroom.pkl'

xvfb-run -a python  completion_rearrange.py $config  $exp_dir/$exp_name/gen_top2down_notexture_nofloor $threed_future  --weight_file $weight_file \
    --without_screen  --n_sequences 150 --render_top2down --no_texture --without_floor  --save_mesh --clip_denoised --retrive_objfeats --arrange_objects  --compute_intersec \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model