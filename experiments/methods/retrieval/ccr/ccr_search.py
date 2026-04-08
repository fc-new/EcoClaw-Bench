#!/usr/bin/env python
"""
ContextualCompressionRetriever CLI tool for Baseline.

Uses LangChain's ContextualCompressionRetriever to:
1. Retrieve relevant documents using FAISS + bge-large-zh-v1.5 embeddings (local model)
2. Compress/extract only the relevant portions using an LLM
3. Output compressed results as JSON

Supports two retrieval backends (auto-selected):
  - FAISS + local bge-large-zh-v1.5 embeddings (if model is available)
  - TF-IDF fallback (if embedding model is not available)

Usage:
    python ccr_search.py index --docs-dir <dir>     # Build index
    python ccr_search.py search "query" [-n 3]      # Search with compression

Environment variables:
    ECOCLAW_API_KEY / OPENAI_API_KEY  — API key for compression LLM
    ECOCLAW_BASE_URL / OPENAI_BASE_URL — Custom API endpoint for compression LLM
    CCR_INDEX_DIR — Where to store the index (default: ~/.baseline-state/ccr-index)
    CCR_COMPRESSOR_MODEL — Model for compression (default: gmn/gpt-5.4)
    CCR_EMBEDDING_MODEL — Local path to embedding model (default: auto-detect bge-large-zh-v1.5)
"""

import argparse
import json
import os
import pickle
import sys
from pathlib import Path

# Resolve API config from Baseline env vars
api_key = os.environ.get("ECOCLAW_API_KEY") or os.environ.get("OPENAI_API_KEY", "")
base_url = os.environ.get("ECOCLAW_BASE_URL") or os.environ.get("OPENAI_BASE_URL", "")
index_dir = os.environ.get("CCR_INDEX_DIR", os.path.expanduser("~/.baseline-state/ccr-index"))
compressor_model = os.environ.get("CCR_COMPRESSOR_MODEL", "gmn/gpt-5.4")

# Auto-detect local bge model path
_SCRIPT_DIR = Path(__file__).resolve().parent
_BENCH_ROOT = _SCRIPT_DIR.parent.parent  # Baseline-Bench root
_DEFAULT_MODEL_PATHS = [
    os.environ.get("CCR_EMBEDDING_MODEL", ""),
    str(_BENCH_ROOT / "local_models" / "Xorbits" / "bge-large-zh-v1___5"),
    str(_BENCH_ROOT / "local_models" / "Xorbits" / "bge-large-zh-v1.5"),
    os.path.expanduser("~/.cache/modelscope/Xorbits/bge-large-zh-v1___5"),
]

def _find_embedding_model() -> str | None:
    """Find the local bge embedding model path."""
    for p in _DEFAULT_MODEL_PATHS:
        if p and Path(p).exists() and (Path(p) / "config.json").exists():
            return p
    return None


def _get_embeddings():
    """Get HuggingFace local embeddings from bge-large-zh-v1.5."""
    from langchain_community.embeddings import HuggingFaceEmbeddings
    model_path = _find_embedding_model()
    if model_path is None:
        raise RuntimeError("bge-large-zh-v1.5 model not found. Run: python -c \"from modelscope import snapshot_download; snapshot_download('Xorbits/bge-large-zh-v1.5', cache_dir='./local_models')\"")
    print(f"Using embedding model: {model_path}", file=sys.stderr)
    return HuggingFaceEmbeddings(
        model_name=model_path,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )


def _has_faiss_index() -> bool:
    """Check if FAISS index exists."""
    return (Path(index_dir) / "index.faiss").exists()


def _has_tfidf_index() -> bool:
    """Check if TF-IDF index exists."""
    return (Path(index_dir) / "tfidf_vectorizer.pkl").exists()


def do_index(docs_dir: str) -> None:
    """Build index from markdown files in docs_dir.
    Uses FAISS if embedding model is available, otherwise falls back to TF-IDF.
    """
    from langchain_community.document_loaders import DirectoryLoader, TextLoader
    from langchain_text_splitters import RecursiveCharacterTextSplitter

    docs_path = Path(docs_dir)
    if not docs_path.exists():
        print(f"Error: directory {docs_dir} does not exist", file=sys.stderr)
        sys.exit(1)

    # Load all markdown files
    loader = DirectoryLoader(
        str(docs_path),
        glob="**/*.md",
        loader_cls=TextLoader,
        loader_kwargs={"encoding": "utf-8"},
    )
    documents = loader.load()

    if not documents:
        print(f"No .md files found in {docs_dir}", file=sys.stderr)
        sys.exit(1)

    # Split into chunks
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=800,
        chunk_overlap=100,
        separators=["\n## ", "\n### ", "\n\n", "\n", " "],
    )
    chunks = splitter.split_documents(documents)

    print(f"Loaded {len(documents)} documents, split into {len(chunks)} chunks", file=sys.stderr)
    os.makedirs(index_dir, exist_ok=True)

    # Try FAISS with local embeddings first
    embedding_model = _find_embedding_model()
    if embedding_model:
        try:
            from langchain_community.vectorstores import FAISS
            embeddings = _get_embeddings()
            vectorstore = FAISS.from_documents(chunks, embeddings)
            vectorstore.save_local(index_dir)
            print(f"FAISS index saved to {index_dir} ({len(chunks)} chunks)", file=sys.stderr)
            print(json.dumps({"status": "ok", "backend": "faiss", "chunks": len(chunks), "index_dir": index_dir}))
            return
        except Exception as e:
            print(f"FAISS indexing failed, falling back to TF-IDF: {e}", file=sys.stderr)

    # Fallback: TF-IDF
    from sklearn.feature_extraction.text import TfidfVectorizer

    texts = [chunk.page_content for chunk in chunks]
    metadatas = [chunk.metadata for chunk in chunks]

    vectorizer = TfidfVectorizer(
        max_features=5000,
        stop_words="english",
        ngram_range=(1, 2),
    )
    tfidf_matrix = vectorizer.fit_transform(texts)

    with open(os.path.join(index_dir, "tfidf_vectorizer.pkl"), "wb") as f:
        pickle.dump(vectorizer, f)
    with open(os.path.join(index_dir, "tfidf_matrix.pkl"), "wb") as f:
        pickle.dump(tfidf_matrix, f)
    with open(os.path.join(index_dir, "texts.pkl"), "wb") as f:
        pickle.dump(texts, f)
    with open(os.path.join(index_dir, "metadatas.pkl"), "wb") as f:
        pickle.dump(metadatas, f)

    print(f"TF-IDF index saved to {index_dir} ({len(chunks)} chunks)", file=sys.stderr)
    print(json.dumps({"status": "ok", "backend": "tfidf", "chunks": len(chunks), "index_dir": index_dir}))


def _faiss_retrieve(query: str, top_k: int = 6):
    """Retrieve documents using FAISS vector similarity."""
    from langchain_community.vectorstores import FAISS
    embeddings = _get_embeddings()
    vectorstore = FAISS.load_local(index_dir, embeddings, allow_dangerous_deserialization=True)
    docs_with_scores = vectorstore.similarity_search_with_score(query, k=top_k)
    results = []
    for doc, score in docs_with_scores:
        results.append({
            "content": doc.page_content,
            "metadata": doc.metadata,
            "score": float(1.0 / (1.0 + score)),  # Convert distance to similarity
        })
    return results


def _tfidf_retrieve(query: str, top_k: int = 6):
    """Retrieve documents using TF-IDF cosine similarity."""
    from sklearn.metrics.pairwise import cosine_similarity

    with open(os.path.join(index_dir, "tfidf_vectorizer.pkl"), "rb") as f:
        vectorizer = pickle.load(f)
    with open(os.path.join(index_dir, "tfidf_matrix.pkl"), "rb") as f:
        tfidf_matrix = pickle.load(f)
    with open(os.path.join(index_dir, "texts.pkl"), "rb") as f:
        texts = pickle.load(f)
    with open(os.path.join(index_dir, "metadatas.pkl"), "rb") as f:
        metadatas = pickle.load(f)

    query_vec = vectorizer.transform([query])
    scores = cosine_similarity(query_vec, tfidf_matrix).flatten()

    top_indices = scores.argsort()[-top_k:][::-1]
    results = []
    for idx in top_indices:
        if scores[idx] > 0.01:
            results.append({
                "content": texts[idx],
                "metadata": metadatas[idx],
                "score": float(scores[idx]),
            })
    return results


def do_search(query: str, top_n: int = 3, use_compression: bool = True) -> None:
    """Search the index with optional contextual compression."""
    if not Path(index_dir).exists():
        print(json.dumps({"error": "Index not found. Run 'ccr_search.py index' first."}))
        sys.exit(1)

    # Step 1: Retrieve using best available backend
    if _has_faiss_index():
        try:
            retrieved = _faiss_retrieve(query, top_k=top_n * 2)
        except Exception as e:
            print(f"FAISS retrieval failed, trying TF-IDF: {e}", file=sys.stderr)
            retrieved = _tfidf_retrieve(query, top_k=top_n * 2) if _has_tfidf_index() else []
    elif _has_tfidf_index():
        retrieved = _tfidf_retrieve(query, top_k=top_n * 2)
    else:
        print(json.dumps({"error": "No index found"}))
        sys.exit(1)

    if not retrieved:
        print(json.dumps([]))
        return

    if use_compression and api_key:
        # Step 2: LLM compression using ContextualCompressionRetriever pattern
        from langchain_openai import ChatOpenAI
        from langchain_classic.retrievers.document_compressors import LLMChainExtractor
        from langchain_core.documents import Document

        llm_kwargs = {"model": compressor_model, "temperature": 0}
        if api_key:
            llm_kwargs["api_key"] = api_key
        if base_url:
            llm_kwargs["base_url"] = base_url

        llm = ChatOpenAI(**llm_kwargs)
        compressor = LLMChainExtractor.from_llm(llm)

        docs = [
            Document(page_content=r["content"], metadata=r["metadata"])
            for r in retrieved
        ]

        try:
            compressed_docs = compressor.compress_documents(docs, query)
            output = []
            for i, doc in enumerate(compressed_docs[:top_n]):
                output.append({
                    "rank": i + 1,
                    "content": doc.page_content,
                    "source": doc.metadata.get("source", "unknown"),
                    "score": retrieved[i]["score"] if i < len(retrieved) else 0.5,
                })
            print(json.dumps(output, ensure_ascii=False))
            return
        except Exception as e:
            print(f"Compression failed, falling back to raw results: {e}", file=sys.stderr)

    # Fallback: return raw results without compression
    output = []
    for i, r in enumerate(retrieved[:top_n]):
        output.append({
            "rank": i + 1,
            "content": r["content"],
            "source": r["metadata"].get("source", "unknown"),
            "score": r["score"],
        })
    print(json.dumps(output, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description="CCR Search CLI for Baseline")
    subparsers = parser.add_subparsers(dest="command")

    # Index command
    idx_parser = subparsers.add_parser("index", help="Build TF-IDF index from docs")
    idx_parser.add_argument("--docs-dir", required=True, help="Directory with .md files")

    # Search command
    search_parser = subparsers.add_parser("search", help="Search with contextual compression")
    search_parser.add_argument("query", help="Search query")
    search_parser.add_argument("-n", "--top-n", type=int, default=3, help="Number of results")
    search_parser.add_argument(
        "--no-compress",
        action="store_true",
        help="Skip LLM compression (raw retrieval only)",
    )

    args = parser.parse_args()

    if args.command == "index":
        do_index(args.docs_dir)
    elif args.command == "search":
        do_search(args.query, args.top_n, use_compression=not args.no_compress)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()