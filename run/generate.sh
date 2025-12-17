#!/bin/bash
# Please update the path to your own environment in config.yaml and following arguments befrore running the script
cd ./scripts

exp_dir="../pretrained"
pretrained_model_dir="../pretrained_diffusion"

####'bedrooms'
config="../config/uncond/diffusion_bedrooms_instancond_lat32_v.yaml"
exp_name="bedrooms_uncond"
weight_file="$pretrained_model_dir/$exp_name/model_30000"
threed_future='../3d_front_processed/threed_future_model_bedroom.pkl'

xvfb-run -a python  generate_diffusion.py $config  $exp_dir/$exp_name/gen_top2down_notexture_nofloor $threed_future  --weight_file $weight_file \
    --without_screen  --n_sequences 150 --render_top2down --save_mesh --no_texture --without_floor  --clip_denoised --retrive_objfeats \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model


###'diningrooms'
config="../config/uncond/diffusion_diningrooms_instancond_lat32_v.yaml"
exp_name="diningrooms_uncond"
weight_file="$pretrained_model_dir/$exp_name/model_82000"
threed_future='../3d_front_processed/threed_future_model_diningroom.pkl'

xvfb-run -a python  generate_diffusion.py $config  $exp_dir/$exp_name/gen_top2down_notexture_nofloor $threed_future  --weight_file $weight_file \
    --without_screen  --n_sequences 150 --render_top2down --save_mesh --no_texture --without_floor  --clip_denoised --retrive_objfeats \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model


####'livingrooms'
config="../config/uncond/diffusion_livingrooms_instancond_lat32_v.yaml"
exp_name="livingrooms_uncond"
weight_file="$pretrained_model_dir/$exp_name/model_96000"
threed_future='../3d_front_processed/threed_future_model_livingroom.pkl'

xvfb-run -a python  generate_diffusion.py $config  $exp_dir/$exp_name/gen_top2down_notexture_nofloor $threed_future  --weight_file $weight_file \
    --without_screen  --n_sequences 150 --render_top2down --save_mesh --no_texture --without_floor  --clip_denoised --retrive_objfeats \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model