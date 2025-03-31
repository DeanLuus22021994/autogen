"""
DALL·E Image Generation Component.

This module provides functionality to generate images using OpenAI's DALL·E
models through the AutoGen framework.
"""

import os
import argparse
from menu.utils import run_command, debug_args


@debug_args
def dalle_image_generation(args: argparse.Namespace) -> int:
    """
    Run the DALL·E image generation example.

    This sample demonstrates how to use AutoGen to generate images using OpenAI's DALL·E
    models with various customization options.

    Key features:
    - Text-to-image generation
    - Image size and quality options
    - Multiple image generation per prompt
    - Local image saving capability
    - Support for image revision and variations
    """
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Create output directory if it doesn't exist
    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir, exist_ok=True)

    cmd = [
        "python", "-m", "python.samples.tools.dalle_generation",
        "--model", args.model,
        "--prompt", args.prompt,
        "--size", args.size,
        "--quality", args.quality,
        "--n", str(args.n),
        "--output_dir", args.output_dir
    ]

    # Add style if provided
    if args.style and args.style != "vivid":
        cmd.extend(["--style", args.style])

    # Add revision options if specified
    if args.revision_prompt:
        cmd.extend(["--revision", "--revision_prompt", args.revision_prompt])

    return run_command(cmd)


def register_parser(subparsers):
    """Register the DALL·E image generation parser."""
    parser = subparsers.add_parser(
        "dalle", help="Generate images using DALL·E")

    # Required arguments
    parser.add_argument(
        "--prompt", required=True, help="Text prompt for image generation")

    # Optional arguments
    parser.add_argument(
        "--model", default="dall-e-3", choices=["dall-e-2", "dall-e-3"],
        help="DALL·E model version")
    parser.add_argument(
        "--size", default="1024x1024",
        choices=["256x256", "512x512", "1024x1024", "1792x1024", "1024x1792"],
        help="Image size (width x height)")
    parser.add_argument(
        "--quality", default="standard", choices=["standard", "hd"],
        help="Image quality (standard or hd, dall-e-3 only)")
    parser.add_argument(
        "--style", default="vivid", choices=["vivid", "natural"],
        help="Image style (vivid or natural, dall-e-3 only)")
    parser.add_argument(
        "--n", type=int, default=1, choices=range(1, 11),
        help="Number of images to generate (1-10, dall-e-2 only)")
    parser.add_argument(
        "--output_dir", default="./dalle_images",
        help="Directory to save generated images")
    parser.add_argument(
        "--revision_prompt", default="",
        help="Text prompt for revising an existing image")

    # Set the function to execute
    parser.set_defaults(func=dalle_image_generation)

    return parser
