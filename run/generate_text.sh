#!/bin/bash
# Please update the path to your own environment in config.yaml and following arguments befrore running the script
cd ./scripts
export HF_ENDPOINT="https://hf-mirror.com"

exp_dir="../pretrained"
pretrained_model_dir="../pretrained_diffusion"

####'bedrooms'
config="../config/text/diffusion_bedrooms_instancond_lat32_v_bert.yaml"
exp_name="bedrooms_bert"
weight_file=$pretrained_model_dir/$exp_name/model_32000 
threed_future='../3d_front_processed/threed_future_model_bedroom.pkl'

xvfb-run -a python  generate_diffusion.py $config  $exp_dir/$exp_name/gen_top2down_notexture_nofloor $threed_future  --weight_file $weight_file \
    --without_screen  --n_sequences 150 --render_top2down --save_mesh --no_texture --without_floor  --clip_denoised --retrive_objfeats \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model

####'diningrooms'
config="../config/text/diffusion_diningrooms_instancond_lat32_v_bert.yaml"
exp_name="diningrooms_bert"
weight_file=$pretrained_model_dir/$exp_name/model_148000
threed_future='../3d_front_processed/threed_future_model_diningroom.pkl'

xvfb-run -a python  generate_diffusion.py $config  $exp_dir/$exp_name/gen_top2down_notexture_nofloor $threed_future  --weight_file $weight_file \
    --without_screen  --n_sequences 150 --render_top2down --save_mesh --no_texture --without_floor  --clip_denoised --retrive_objfeats \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model


####'livingrooms'
config="../config/text/diffusion_livingrooms_instancond_lat32_v_bert.yaml"
exp_name="livingrooms_bert"
weight_file=$pretrained_model_dir/$exp_name/model_118000
threed_future='../3d_front_processed/threed_future_model_livingroom.pkl'

xvfb-run -a python  generate_diffusion.py $config  $exp_dir/$exp_name/gen_top2down_notexture_nofloor $threed_future  --weight_file $weight_file \
    --without_screen  --n_sequences 150 --render_top2down --save_mesh --no_texture --without_floor  --clip_denoised --retrive_objfeats \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model