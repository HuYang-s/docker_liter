#!/usr/bin/env python3
"""
Organize geotechnical papers into topical folders, standardize filenames,
and generate manifests and a topic overview.

Idempotent: safe to run multiple times.
"""

from __future__ import annotations

import csv
import os
import re
from dataclasses import dataclass
from typing import Dict, Iterable, List, Tuple


BASE_DIR = "/workspace/papers_by_topic"

# Canonical categories (folder names)
CATEGORIES: List[str] = [
    "ai_ml",
    "liquefaction",
    "tailings",
    "slope",
    "landslide",
    "grain_distribution",
    "clay_rheology",
    "dem",
    "hydrology_geophysics",
    "review_general",
    "other",
]


def ensure_directories() -> None:
    for category in CATEGORIES:
        os.makedirs(os.path.join(BASE_DIR, category), exist_ok=True)


def slugify_filename(original_name: str) -> str:
    """
    Standardize filename:
    - Lowercase ASCII letters only; preserve non-ASCII (e.g., Chinese)
    - Replace whitespace/underscores with hyphens
    - Remove/replace path-like or illegal characters with hyphens
    - Collapse repeated hyphens and trim hyphens
    - Lowercase file extension
    """
    name, ext = os.path.splitext(original_name)

    def lower_ascii_only(text: str) -> str:
        lowered_chars: List[str] = []
        for ch in text:
            if ord(ch) < 128:
                lowered_chars.append(ch.lower())
            else:
                lowered_chars.append(ch)
        return "".join(lowered_chars)

    name = lower_ascii_only(name)
    name = re.sub(r"[\s_]+", "-", name)
    name = re.sub(r"[\\/:*?\"<>|]+", "-", name)
    name = re.sub(r"-+", "-", name).strip("-")
    return f"{name}{ext.lower()}"


AI_PATTERNS = [
    r"artificial\s*intelligence",
    r"machine\s*learning",
    r"deep\s*learning",
    r"neural(\s*network)?",
    r"generative\s*adversarial",
    r"\bgan\b",
    r"bayes(ian)?",
    r"random\s*forest",
    r"xgboost",
    r"\bsvm\b",
    r"data[-_\s]?driven",
    r"schema\s*gan",
]

AI_PATTERNS_ZH = [
    r"人工智能",
    r"机器学习",
    r"深度学习",
    r"神经网络",
    r"生成对抗网络",
]


def _normalize_for_matching(text: str) -> str:
    # Treat hyphens/underscores as spaces for keyword matching
    lowered = text.lower().replace("-", " ").replace("_", " ")
    lowered = re.sub(r"\s+", " ", lowered).strip()
    return lowered


def is_ai_ml(title: str) -> bool:
    lowered = _normalize_for_matching(title)
    if any(re.search(p, lowered) for p in AI_PATTERNS):
        return True
    if any(re.search(p, title) for p in AI_PATTERNS_ZH):
        return True
    return False


def classify_non_ai(title: str) -> str:
    """
    Classify non-AI papers using bilingual keyword rules.
    Priority order matters.
    """
    lowered = _normalize_for_matching(title)

    # Reviews
    if re.search(r"\breview\b|meta[- ]?analysis|state\s*-?\s*of\s*-?\s*the", lowered) or re.search(
        r"综述", title
    ):
        return "review_general"

    # Liquefaction (dominant over tailings)
    if re.search(r"liquefaction|undrain|nor\s*sand|casm", lowered) or re.search(r"液化", title):
        return "liquefaction"

    # Tailings
    if re.search(r"tailings?|tailing\b", lowered) or re.search(r"尾矿", title):
        return "tailings"

    # Landslides / debris flows / pyroclastic
    if re.search(r"landslide|debris\s*flow|pyroclastic|entrainment", lowered) or re.search(
        r"滑坡|泥石流|火山碎屑", title
    ):
        return "landslide"

    # Slope (generic)
    if re.search(r"\bslope(\s*(stability|movement|process))?\b", lowered) or re.search(r"边坡", title):
        return "slope"

    # Grain/distribution
    if re.search(r"\bgrain\b|grading|granulometry|distribution", lowered) or re.search(r"颗粒|级配", title):
        return "grain_distribution"

    # Clay/rheology/consolidation/viscous
    if re.search(r"\bclay\b|silts?|peat|viscoplastic|rheolog|consolidation|compression|viscous", lowered) or re.search(
        r"黏土|粘土|粉土|固结|压缩", title
    ):
        return "clay_rheology"

    # DEM
    if re.search(r"\bdem\b|discrete\s*element", lowered) or re.search(r"离散元", title):
        return "dem"

    # Hydro/geo/seismic
    if re.search(
        r"wave|seiche|hydrodynamic|hydromechan|suction|stiffness|shear\s*wave|velocity|earthquake|infiltration|rainfall",
        lowered,
    ) or re.search(r"基质吸力|剪切波|地震|渗流|入渗|降雨", title):
        return "hydrology_geophysics"

    return "other"


@dataclass
class Paper:
    abs_path: str
    rel_path: str
    title: str  # filename only
    category: str  # folder name


def enumerate_pdfs(base_dir: str) -> List[Paper]:
    papers: List[Paper] = []
    base_dir = os.path.abspath(base_dir)
    for root, _, files in os.walk(base_dir):
        for fn in files:
            if not fn.lower().endswith(".pdf"):
                continue
            abs_path = os.path.join(root, fn)
            rel_path = os.path.relpath(abs_path, base_dir)
            category = rel_path.split(os.sep, 1)[0] if os.sep in rel_path else ""
            papers.append(Paper(abs_path=abs_path, rel_path=rel_path, title=fn, category=category))
    return papers


def move_with_unique_name(src: str, dst_dir: str, new_name: str) -> str:
    os.makedirs(dst_dir, exist_ok=True)
    base, ext = os.path.splitext(new_name)
    candidate = os.path.join(dst_dir, f"{base}{ext}")
    i = 2
    while os.path.exists(candidate):
        candidate = os.path.join(dst_dir, f"{base}-{i}{ext}")
        i += 1
    if os.path.abspath(src) != os.path.abspath(candidate):
        os.rename(src, candidate)
    return candidate


def organize() -> Tuple[List[Paper], Dict[str, int]]:
    ensure_directories()

    # First pass: collect files to avoid walking mutated tree during moves
    papers = enumerate_pdfs(BASE_DIR)

    # Second pass: decide target category and standardized name; then move
    updated: List[Paper] = []
    for p in papers:
        title_for_rules = p.title
        if is_ai_ml(title_for_rules):
            new_category = "ai_ml"
        else:
            new_category = classify_non_ai(title_for_rules)

        new_filename = slugify_filename(p.title)
        dst_dir = os.path.join(BASE_DIR, new_category)
        new_abs = move_with_unique_name(p.abs_path, dst_dir, new_filename)
        new_rel = os.path.relpath(new_abs, BASE_DIR)
        updated.append(
            Paper(abs_path=new_abs, rel_path=new_rel, title=os.path.basename(new_abs), category=new_category)
        )

    # Counts per category
    counts: Dict[str, int] = {c: 0 for c in CATEGORIES}
    for p in updated:
        counts[p.category] = counts.get(p.category, 0) + 1

    return updated, counts


def write_manifest_v3(papers: Iterable[Paper]) -> None:
    manifest_path = "/workspace/papers_manifest_v3.csv"
    with open(manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["category", "filename", "rel_path"])
        for p in sorted(papers, key=lambda x: (x.category, x.title)):
            writer.writerow([p.category, p.title, p.rel_path])


def write_counts_v3(counts: Dict[str, int]) -> None:
    counts_path = "/workspace/papers_by_topic_counts_v3.csv"
    with open(counts_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Category", "Count"])
        for cat in sorted(counts.keys()):
            writer.writerow([cat, counts[cat]])


def write_topics_overview_md(papers: Iterable[Paper]) -> None:
    md_path = "/workspace/topics_overview.md"
    by_cat: Dict[str, List[str]] = {}
    for p in papers:
        by_cat.setdefault(p.category, []).append(p.title)

    for titles in by_cat.values():
        titles.sort()

    with open(md_path, "w", encoding="utf-8") as f:
        f.write("## Papers by Topic\n\n")
        for cat in sorted(by_cat.keys()):
            f.write(f"### {cat}\n\n")
            for t in by_cat[cat]:
                f.write(f"- {t}\n")
            f.write("\n")


def main() -> None:
    papers, counts = organize()
    write_manifest_v3(papers)
    write_counts_v3(counts)
    write_topics_overview_md(papers)


if __name__ == "__main__":
    main()

