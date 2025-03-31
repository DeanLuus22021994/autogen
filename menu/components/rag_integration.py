"""
Retrieval-Augmented Generation Integration Component.

This module provides functionality to run examples that demonstrate
how to integrate external knowledge with LLM agents through retrieval.
"""

import os
import argparse
from utils import run_command, debug_args


@debug_args
def rag_integration(args: argparse.Namespace) -> int:
    """
    Run the Retrieval-Augmented Generation (RAG) integration example.

    This sample demonstrates how to integrate retrieval systems with agents
    to provide more knowledgeable responses based on external documents.

    Key features:
    - Document chunking and embedding
    - Vector-based similarity search
    - Knowledge integration into agent conversations
    - Contextual response generation
    """
    # Auto-recompile check - this module will be recompiled on each run if valid
    print(f"[DEBUG] Running module: {__name__}")
    print(f"[DEBUG] Module path: {os.path.abspath(__file__)}")

    # Create vector store directory if it doesn't exist
    if not os.path.exists(args.vector_store_dir):
        os.makedirs(args.vector_store_dir, exist_ok=True)

    cmd = [
        "python", "-m", "python.samples.agentchat.retrievechat",
        "--model", args.model,
        "--embedding-model", args.embedding_model,
        "--temperature", str(args.temperature),
        "--max-tokens", str(args.max_tokens),
        "--retrieval-top-k", str(args.retrieval_top_k),
        "--retrieval-chunk-size", str(args.retrieval_chunk_size),
        "--retrieval-chunk-overlap", str(args.retrieval_chunk_overlap),
        "--vector-store-dir", args.vector_store_dir,
        "--cache-seed", str(args.cache_seed),
        "--cache-dir", args.cache_dir,
        "--verbose", str(args.verbose).lower()
    ]

    # Add document path if provided
    if hasattr(args, 'document_path') and args.document_path:
        cmd.extend(["--document-path", args.document_path])

    # Add query if provided
    if hasattr(args, 'query') and args.query:
        cmd.extend(["--query", args.query])

    return run_command(cmd)


def register_parser(subparsers):
    """Register the RAG integration parser"""
    parser = subparsers.add_parser(
        "rag", help="Run RAG integration example")

    # Add arguments
    parser.add_argument(
        "--model", default="gpt-4-turbo", help="Model to use")
    parser.add_argument(
        "--embedding-model", default="text-embedding-ada-002", help="Embedding model")
    parser.add_argument(
        "--temperature", type=float, default=0.1, help="Temperature for generation")
    parser.add_argument(
        "--max-tokens", type=int, default=2000, help="Max tokens to generate")
    parser.add_argument(
        "--retrieval-top-k", type=int, default=5, help="Number of chunks to retrieve")
    parser.add_argument(
        "--retrieval-chunk-size", type=int, default=1000, help="Size of text chunks")
    parser.add_argument(
        "--retrieval-chunk-overlap", type=int, default=100, help="Overlap between chunks")
    parser.add_argument(
        "--vector-store-dir", default="./vector_store", help="Directory for vector store")
    parser.add_argument(
        "--document-path", default=None, help="Path to document for indexing")
    parser.add_argument(
        "--query", default=None, help="Query to run against the indexed documents")
    parser.add_argument(
        "--cache-seed", type=int, default=42, help="Cache seed for reproducibility")
    parser.add_argument(
        "--cache-dir", default=".cache", help="Directory for caching")
    parser.add_argument(
        "--verbose", type=bool, default=True, help="Enable verbose output")

    # Set the function to execute
    parser.set_defaults(func=rag_integration)

    return parser
