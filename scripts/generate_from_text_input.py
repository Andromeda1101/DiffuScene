# 
# Text-conditioned scene generation script with flexible input options
# Supports: command-line input, single file input, and batch directory input
#

"""Script for generating scenes from text descriptions with various input methods."""
import argparse
import os
import logging
import sys
import json
from datetime import datetime
from pathlib import Path
import glob

import numpy as np
import torch

from training_utils import load_config
from utils import floor_plan_from_scene, export_scene, get_textured_objects_in_scene

from scene_synthesis.datasets import filter_function, get_dataset_raw_and_encoded
from scene_synthesis.datasets.threed_front import ThreedFront
from scene_synthesis.datasets.threed_future_dataset import ThreedFutureDataset
from scene_synthesis.networks import build_network
from scene_synthesis.utils import get_textured_objects, get_textured_objects_based_on_objfeats
from scene_synthesis.stats_logger import AverageAggregator

from simple_3dviz import Scene
from simple_3dviz.behaviours.keyboard import SnapshotOnKey, SortTriangles
from simple_3dviz.behaviours.misc import LightToCamera
from simple_3dviz.behaviours.movements import CameraTrajectory
from simple_3dviz.behaviours.trajectory import Circle
from simple_3dviz.behaviours.io import SaveFrames, SaveGif
from simple_3dviz.utils import render
import matplotlib.pyplot as plt
from pyrr import Matrix44
from utils import render as render_top2down
from utils import merge_meshes
import trimesh
import open3d as o3d
from utils import merge_meshes, computer_intersection, computer_symmetry
from utils import save_object_info_json, create_video_from_frames
from utils import save_progressive_data_json


def read_text_from_file(file_path):
    """Read text description from a file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            text = f.read().strip()
        return text
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
        return None


def read_texts_from_directory(dir_path):
    """Read all .txt files from a directory."""
    texts = []
    txt_files = sorted(glob.glob(os.path.join(dir_path, "*.txt")))
    
    if not txt_files:
        print(f"Warning: No .txt files found in directory {dir_path}")
        return []
    
    for txt_file in txt_files:
        text = read_text_from_file(txt_file)
        if text:
            texts.append({
                'text': text,
                'source_file': txt_file,
                'filename': os.path.basename(txt_file)
            })
    
    print(f"Loaded {len(texts)} text descriptions from {dir_path}")
    return texts


def save_generation_record(output_dir, record_data):
    """Save input-output records for analysis."""
    record_file = os.path.join(output_dir, "generation_records.jsonl")
    
    # Append record to JSONL file
    with open(record_file, 'a', encoding='utf-8') as f:
        json.dump(record_data, f, ensure_ascii=False)
        f.write('\n')
    
    print(f"Record saved to {record_file}")


def main(argv):
    parser = argparse.ArgumentParser(
        description="Generate scenes from text descriptions with flexible input options"
    )

    parser.add_argument(
        "config_file",
        help="Path to the file that contains the experiment configuration"
    )
    parser.add_argument(
        "output_directory",
        help="Path to the output directory"
    )
    parser.add_argument(
        "path_to_pickled_3d_futute_models",
        help="Path to the 3D-FUTURE model meshes"
    )
    
    # Text input options (mutually exclusive group)
    text_group = parser.add_mutually_exclusive_group(required=False)
    text_group.add_argument(
        "--text",
        type=str,
        help="Text description for scene generation (command-line input)"
    )
    text_group.add_argument(
        "--text_file",
        type=str,
        help="Path to a text file containing the description"
    )
    text_group.add_argument(
        "--text_dir",
        type=str,
        help="Path to a directory containing multiple .txt files for batch generation"
    )
    
    # Feature toggle
    parser.add_argument(
        "--enable_text_input",
        action="store_true",
        help="Enable custom text input functionality (command-line, file, or directory)"
    )
    
    # Standard parameters
    parser.add_argument(
        "--path_to_3d_future_models_dir",
        default="../dataset/3D-FUTURE-model",
        help="Directory containing 3D-FUTURE models"
    )
    parser.add_argument(
        "--path_to_floor_plan_textures",
        default="../demo/floor_plan_texture_images",
        help="Path to floor texture images"
    )
    parser.add_argument(
        "--weight_file",
        default=None,
        help="Path to a pretrained model"
    )
    parser.add_argument(
        "--n_sequences",
        default=10,
        type=int,
        help="The number of repetitions to generate for each text input (i.e., how many times to generate scenes from the same text)"
    )
    parser.add_argument(
        "--background",
        type=lambda x: list(map(float, x.split(","))),
        default="1,1,1,1",
        help="Set the background of the scene"
    )
    parser.add_argument(
        "--window_size",
        type=lambda x: tuple(map(int, x.split(","))),
        default="512,512",
        help="Define the size of the scene and the window"
    )
    parser.add_argument(
        "--without_screen",
        action="store_true",
        help="Perform no screen rendering"
    )
    parser.add_argument(
        "--scene_id",
        default=None,
        help="The scene id to be used for floor plan (optional)"
    )
    parser.add_argument(
        "--render_top2down",
        action="store_true",
        help="Perform top2down orthographic rendering"
    )
    parser.add_argument(
        "--without_floor",
        action="store_true",
        help="Remove the floor plane"
    )
    parser.add_argument(
        "--no_texture",
        action="store_true",
        help="Remove the texture"
    )
    parser.add_argument(
        "--save_mesh",
        action="store_true",
        help="Save mesh files"
    )
    parser.add_argument(
        "--mesh_format",
        type=str,
        default=".ply",
        help="Mesh format"
    )
    parser.add_argument(
        "--clip_denoised",
        action="store_true",
        help="Clip denoised values"
    )
    parser.add_argument(
        "--retrive_objfeats",
        action="store_true",
        help="Retrieve most similar object features"
    )
    parser.add_argument(
        "--save_records",
        action="store_true",
        default=True,
        help="Save input-output records for analysis"
    )
    
    args = parser.parse_args(argv)

    # Disable trimesh's logger
    logging.getLogger("trimesh").setLevel(logging.ERROR)

    if torch.cuda.is_available():
        device = torch.device("cuda:0")
    else:
        device = torch.device("cpu")
    print("Running code on", device)

    # Check if output directory exists and if it doesn't create it
    if not os.path.exists(args.output_directory):
        os.makedirs(args.output_directory)

    # Prepare text inputs
    text_inputs = []
    
    if args.enable_text_input:
        if args.text:
            # Command-line text input
            text_inputs.append({
                'text': args.text,
                'source': 'command_line',
                'filename': 'command_line_input'
            })
            print(f"Using command-line text input: {args.text}")
            
        elif args.text_file:
            # Single file input
            text = read_text_from_file(args.text_file)
            if text:
                text_inputs.append({
                    'text': text,
                    'source': 'file',
                    'source_file': args.text_file,
                    'filename': os.path.basename(args.text_file)
                })
                print(f"Loaded text from file: {args.text_file}")
            else:
                print(f"Error: Could not read text from {args.text_file}")
                return
                
        elif args.text_dir:
            # Directory batch input
            text_inputs = read_texts_from_directory(args.text_dir)
            if not text_inputs:
                print(f"Error: No valid text files found in {args.text_dir}")
                return
            # Update source field
            for item in text_inputs:
                item['source'] = 'directory'
        else:
            print("Warning: --enable_text_input is set but no text input provided.")
            print("Please provide --text, --text_file, or --text_dir")
            return
    else:
        # Use default dataset descriptions (original behavior)
        print("Text input feature disabled. Using dataset descriptions.")
        text_inputs = None

    # Load configuration
    config = load_config(args.config_file)

    # Make it for evaluation
    if 'text' in config["data"]["encoding_type"]:
        if 'textfix' not in config["data"]["encoding_type"]:
            config["data"]["encoding_type"] = config["data"]["encoding_type"].replace('text', 'textfix')

    if "no_prm" not in config["data"]["encoding_type"]:
        print('NO PERM AUG in test')
        config["data"]["encoding_type"] = config["data"]["encoding_type"] + "_no_prm"
    print('encoding type:', config["data"]["encoding_type"])

    # Load dataset
    raw_dataset, train_dataset = get_dataset_raw_and_encoded(
        config["data"],
        filter_fn=filter_function(
            config["data"],
            split=config["training"].get("splits", ["train", "val"])
        ),
        split=config["training"].get("splits", ["train", "val"])
    )

    # Build the dataset of 3D models
    objects_dataset = ThreedFutureDataset.from_pickled_dataset(
        args.path_to_pickled_3d_futute_models
    )
    
    # Override model base paths
    if hasattr(objects_dataset, "objects"):
        base_dir = args.path_to_3d_future_models_dir
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), base_dir)) if not os.path.isabs(base_dir) else base_dir
        for oi in objects_dataset.objects:
            setattr(oi, "path_to_models", base_dir)
    print("Loaded {} 3D-FUTURE models".format(len(objects_dataset)))

    # Load test dataset
    raw_dataset, dataset = get_dataset_raw_and_encoded(
        config["data"],
        filter_fn=filter_function(
            config["data"],
            split=config["validation"].get("splits", ["test"])
        ),
        split=config["validation"].get("splits", ["test"])
    )
    print("Loaded {} scenes with {} object types:".format(
        len(dataset), dataset.n_object_types)
    )
    
    # Build network
    network, _, _ = build_network(
        dataset.feature_size, dataset.n_classes,
        config, args.weight_file, device=device
    )
    network.eval()

    # Create scene for top-down rendering
    if args.render_top2down:
        if args.without_floor:
            scene_top2down = Scene(size=(256, 256), background=[1,1,1,1])
        else:
            scene_top2down = Scene(size=(256, 256), background=[0,0,0,1])
        scene_top2down.up_vector = (0,0,-1)
        scene_top2down.camera_target = (0, 0, 0)
        scene_top2down.camera_position = (0,4,0)
        scene_top2down.light = (0,4,0)
        scene_top2down.camera_matrix = Matrix44.orthogonal_projection(
            left=-3.1, right=3.1,
            bottom=3.1, top=-3.1,
            near=0.1, far=6
        )

    classes = np.array(dataset.class_labels)
    print('class labels:', classes, len(classes))

    # Process scene ID if provided
    given_scene_id = None
    if args.scene_id:
        for i, di in enumerate(raw_dataset):
            if str(di.scene_id) == args.scene_id:
                given_scene_id = i

    # Generation loop
    if text_inputs is not None:
        # Custom text input mode
        total_generations = 0
        
        for text_idx, text_input in enumerate(text_inputs):
            text_description = text_input['text']
            print(f"\n{'='*80}")
            print(f"Processing text input {text_idx + 1}/{len(text_inputs)}")
            print(f"Source: {text_input['source']}")
            if 'source_file' in text_input:
                print(f"File: {text_input['source_file']}")
            print(f"Text: {text_description}")
            print(f"{'='*80}\n")
            
            # Create subdirectory for this text input
            text_output_dir = os.path.join(
                args.output_directory,
                text_input['filename'].replace('.txt', '')
            )
            os.makedirs(text_output_dir, exist_ok=True)
            
            # Save the input text
            input_text_file = os.path.join(text_output_dir, "input_text.txt")
            with open(input_text_file, 'w', encoding='utf-8') as f:
                f.write(text_description)
            
            generation_start_time = datetime.now()
            
            for seq_i in range(args.n_sequences):
                # Select scene for floor plan
                scene_idx = given_scene_id or np.random.choice(len(dataset))
                current_scene = raw_dataset[scene_idx]
                
                print(f"  Repetition {seq_i + 1}/{args.n_sequences} for text input {text_idx + 1}")
                print(f"    Using floor plan from scene {current_scene.scene_id}")
                
                # Get floor plan
                floor_plan, tr_floor, room_mask = floor_plan_from_scene(
                    current_scene, args.path_to_floor_plan_textures, no_texture=args.no_texture
                )
                
                # Generate layout with custom text
                bbox_params = network.generate_layout(
                    room_mask=room_mask.to(device),
                    num_points=config["network"]["sample_num_points"],
                    point_dim=config["network"]["point_dim"],
                    text=text_description,  # Use custom text
                    device=device,
                    clip_denoised=args.clip_denoised,
                    batch_seeds=torch.arange(total_generations, total_generations+1),
                )
                
                boxes = dataset.post_process(bbox_params)
                bbox_params_t = torch.cat([
                    boxes["class_labels"],
                    boxes["translations"],
                    boxes["sizes"],
                    boxes["angles"]
                ], dim=-1).cpu().numpy()
                print(f'    Generated bbox: {bbox_params_t.shape}')
                
                # Get textured objects
                if args.retrive_objfeats:
                    objfeats = boxes["objfeats"].cpu().numpy()
                    renderables, trimesh_meshes, model_jids = get_textured_objects_based_on_objfeats(
                        bbox_params_t, objects_dataset, classes, diffusion=True,
                        no_texture=args.no_texture, query_objfeats=objfeats
                    )
                else:
                    renderables, trimesh_meshes, model_jids = get_textured_objects(
                        bbox_params_t, objects_dataset, classes, diffusion=True,
                        no_texture=args.no_texture
                    )
                
                if not args.without_floor:
                    renderables += floor_plan
                    trimesh_meshes += tr_floor
                
                # Render top-down view
                if args.render_top2down:
                    image_filename = f"seq_{seq_i:03d}_{current_scene.scene_id}.png"
                    path_to_image = os.path.join(text_output_dir, image_filename)
                    render_top2down(
                        scene_top2down,
                        renderables,
                        color=None,
                        mode="shading",
                        frame_path=path_to_image,
                    )
                    print(f"    Saved image: {image_filename}")
                
                # Save mesh
                if args.save_mesh and trimesh_meshes is not None:
                    mesh_filename = f"seq_{seq_i:03d}_{current_scene.scene_id}{args.mesh_format}"
                    path_to_mesh = os.path.join(text_output_dir, mesh_filename)
                    whole_scene_mesh = merge_meshes(trimesh_meshes)
                    o3d.io.write_triangle_mesh(path_to_mesh, whole_scene_mesh)
                    print(f"    Saved mesh: {mesh_filename}")
                
                # Save generation record
                if args.save_records:
                    record_data = {
                        'timestamp': generation_start_time.isoformat(),
                        'text_index': text_idx,
                        'sequence_index': seq_i,
                        'total_generation_index': total_generations,
                        'input_text': text_description,
                        'text_source': text_input['source'],
                        'text_filename': text_input['filename'],
                        'scene_id': str(current_scene.scene_id),
                        'floor_plan_scene_idx': scene_idx,
                        'num_objects': int(bbox_params_t.shape[1] if len(bbox_params_t.shape) == 3 else bbox_params_t.shape[0]),
                        'output_image': image_filename if args.render_top2down else None,
                        'output_mesh': mesh_filename if args.save_mesh else None,
                        'output_directory': text_output_dir,
                        'config_file': args.config_file,
                        'weight_file': args.weight_file,
                    }
                    
                    if 'source_file' in text_input:
                        record_data['text_source_file'] = text_input['source_file']
                    
                    save_generation_record(args.output_directory, record_data)
                
                total_generations += 1
            
            generation_end_time = datetime.now()
            duration = (generation_end_time - generation_start_time).total_seconds()
            
            # Save summary for this text input
            summary_file = os.path.join(text_output_dir, "generation_summary.json")
            summary_data = {
                'text_input': text_description,
                'text_source': text_input['source'],
                'num_repetitions': args.n_sequences,
                'generation_time_seconds': duration,
                'output_directory': text_output_dir,
                'config_file': args.config_file,
                'weight_file': args.weight_file,
                'timestamp': generation_start_time.isoformat(),
            }
            if 'source_file' in text_input:
                summary_data['text_source_file'] = text_input['source_file']
                
            with open(summary_file, 'w', encoding='utf-8') as f:
                json.dump(summary_data, f, indent=2, ensure_ascii=False)
            
            print(f"\nCompleted {args.n_sequences} repetitions for text input {text_idx + 1}")
            print(f"Time taken: {duration:.2f} seconds")
            print(f"Output saved to: {text_output_dir}\n")
        
        print(f"\n{'='*80}")
        print(f"All generations completed!")
        print(f"Total text inputs processed: {len(text_inputs)}")
        print(f"Total scenes generated: {total_generations} ({len(text_inputs)} texts × {args.n_sequences} repetitions)")
        print(f"Results saved to: {args.output_directory}")
        print(f"{'='*80}\n")
        
    else:
        # Original mode: use dataset descriptions
        print("Using original dataset-based generation mode")
        for i in range(args.n_sequences):
            scene_idx = given_scene_id or np.random.choice(len(dataset))
            current_scene = raw_dataset[scene_idx]
            samples = dataset[scene_idx]
            
            print(f"{i + 1}/{args.n_sequences}: Using scene {current_scene.scene_id}")
            
            floor_plan, tr_floor, room_mask = floor_plan_from_scene(
                current_scene, args.path_to_floor_plan_textures, no_texture=args.no_texture
            )
            
            bbox_params = network.generate_layout(
                room_mask=room_mask.to(device),
                num_points=config["network"]["sample_num_points"],
                point_dim=config["network"]["point_dim"],
                text=samples['description'] if 'description' in samples.keys() else None,
                device=device,
                clip_denoised=args.clip_denoised,
                batch_seeds=torch.arange(i, i+1),
            )
            
            boxes = dataset.post_process(bbox_params)
            bbox_params_t = torch.cat([
                boxes["class_labels"],
                boxes["translations"],
                boxes["sizes"],
                boxes["angles"]
            ], dim=-1).cpu().numpy()
            
            if args.retrive_objfeats:
                objfeats = boxes["objfeats"].cpu().numpy()
                renderables, trimesh_meshes, model_jids = get_textured_objects_based_on_objfeats(
                    bbox_params_t, objects_dataset, classes, diffusion=True,
                    no_texture=args.no_texture, query_objfeats=objfeats
                )
            else:
                renderables, trimesh_meshes, model_jids = get_textured_objects(
                    bbox_params_t, objects_dataset, classes, diffusion=True,
                    no_texture=args.no_texture
                )
            
            if not args.without_floor:
                renderables += floor_plan
                trimesh_meshes += tr_floor
            
            if args.render_top2down:
                path_to_image = f"{args.output_directory}/{current_scene.scene_id}_{scene_idx}_{i:03d}.png"
                render_top2down(
                    scene_top2down,
                    renderables,
                    color=None,
                    mode="shading",
                    frame_path=path_to_image,
                )
            
            if args.save_mesh and trimesh_meshes is not None:
                path_to_objs = os.path.join(args.output_directory, "scene_mesh")
                os.makedirs(path_to_objs, exist_ok=True)
                filename = f"{current_scene.scene_id}_{scene_idx}_{i:03d}"
                path_to_scene = os.path.join(path_to_objs, filename + args.mesh_format)
                whole_scene_mesh = merge_meshes(trimesh_meshes)
                o3d.io.write_triangle_mesh(path_to_scene, whole_scene_mesh)


if __name__ == "__main__":
    main(sys.argv[1:])
