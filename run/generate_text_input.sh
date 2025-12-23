#!/bin/bash
# Script for generating scenes from custom text input
# Usage examples are provided below

cd ./scripts
export HF_ENDPOINT="https://hf-mirror.com"

exp_dir="../pretrained"
pretrained_model_dir="../pretrained_diffusion"

# Choose room type: bedrooms, diningrooms, or livingrooms
ROOM_TYPE="diningrooms"  # Change this to "diningrooms" or "livingrooms" as needed

# Configuration based on room type
if [ "$ROOM_TYPE" == "bedrooms" ]; then
    config="../config/text/diffusion_bedrooms_instancond_lat32_v_bert.yaml"
    exp_name="bedrooms_bert"
    weight_file=$pretrained_model_dir/$exp_name/model_32000
    threed_future='../3d_front_processed/threed_future_model_bedroom.pkl'
elif [ "$ROOM_TYPE" == "diningrooms" ]; then
    config="../config/text/diffusion_diningrooms_instancond_lat32_v_bert.yaml"
    exp_name="diningrooms_bert"
    weight_file=$pretrained_model_dir/$exp_name/model_148000
    threed_future='../3d_front_processed/threed_future_model_diningroom.pkl'
elif [ "$ROOM_TYPE" == "livingrooms" ]; then
    config="../config/text/diffusion_livingrooms_instancond_lat32_v_bert.yaml"
    exp_name="livingrooms_bert"
    weight_file=$pretrained_model_dir/$exp_name/model_118000
    threed_future='../3d_front_processed/threed_future_model_livingroom.pkl'
else
    echo "Invalid ROOM_TYPE. Please set to 'bedrooms', 'diningrooms', or 'livingrooms'"
    exit 1
fi

output_dir=$exp_dir/$exp_name/text_input_generation

# =============================================================================
# Example 1: Command-line text input
# =============================================================================
# Generate scenes from a single text description provided via command line
# Uncomment to use:

# xvfb-run -a python generate_from_text_input.py $config $output_dir/command_line_test $threed_future \
#     --weight_file $weight_file \
#     --enable_text_input \
#     --text "a bedroom with a large bed, two nightstands, and a wardrobe" \
#     --without_screen \
#     --n_sequences 5 \
#     --render_top2down \
#     --save_mesh \
#     --no_texture \
#     --without_floor \
#     --clip_denoised \
#     --retrive_objfeats \
#     --save_records \
#     --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model

# =============================================================================
# Example 2: Single file input
# =============================================================================
# Generate scenes from text description in a single file
# Uncomment to use:

# xvfb-run -a python generate_from_text_input.py $config $output_dir/single_file_test $threed_future \
#     --weight_file $weight_file \
#     --enable_text_input \
#     --text_file ../demo/sample_text_input.txt \
#     --without_screen \
#     --n_sequences 5 \
#     --render_top2down \
#     --save_mesh \
#     --no_texture \
#     --without_floor \
#     --clip_denoised \
#     --retrive_objfeats \
#     --save_records \
#     --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model

# =============================================================================
# Example 3: Batch directory input (RECOMMENDED FOR MULTIPLE TEXTS)
# =============================================================================
# Generate scenes from all .txt files in a directory
# This is the most efficient way to process multiple text descriptions
# Note: --n_sequences controls how many times to repeat generation for EACH text input
# For example: 3 text files × 3 repetitions = 9 total scenes generated
# Uncomment to use:

xvfb-run -a python generate_from_text_input.py $config $output_dir/batch_generation $threed_future \
    --weight_file $weight_file \
    --enable_text_input \
    --text_dir ../demo/text_input/$ROOM_TYPE/ \
    --without_screen \
    --n_sequences 3 \
    --render_top2down \
    --save_mesh \
    --no_texture \
    --without_floor \
    --clip_denoised \
    --retrive_objfeats \
    --save_records \
    --path_to_3d_future_models_dir ../dataset/3D-FUTURE-model

echo "Generation complete! Check output at: $output_dir"
echo "Each text input was repeated 3 times (controlled by --n_sequences)"
