#!/usr/bin/env python3
import csv
import os
import re
from collections import defaultdict

MANIFEST_V2 = "/workspace/papers_manifest_v2.csv"
OUT_MD = "/workspace/paper_intros_from_manifest_cn.md"

cat_cn = {
    "ai_ml": "人工智能",
    "liquefaction": "液化",
    "tailings": "尾矿",
    "slope": "边坡",
    "landslide": "滑坡",
    "grain_distribution": "颗粒与级配",
    "clay_rheology": "黏土与流变",
    "dem": "离散元",
    "hydrology_geophysics": "水文地球物理",
    "review_general": "综述",
    "modeling_ml": "建模",
    "other": "其他",
}

def cat_phrase(cn: str) -> str:
    return {
        "人工智能": "机器学习/深度学习在岩土/地质问题中的应用",
        "液化": "砂土/尾矿材料液化机制、触发与评价",
        "尾矿": "尾矿坝材料与稳定性",
        "边坡": "边坡过程与稳定性",
        "滑坡": "滑坡/泥石流动力学",
        "颗粒与级配": "颗粒级配、粒径统计与分布特征",
        "黏土与流变": "黏土/粉土流变与本构、固结/压缩特性",
        "离散元": "离散元（DEM）建模与颗粒介质行为",
        "水文地球物理": "水力-地球物理响应（吸力、波、渗流等）",
        "综述": "领域综述与研究综合",
    }.get(cn, "通用岩土/地学问题")

kw_list = [
    (r"liquefaction", "液化"),
    (r"tailings?", "尾矿"),
    (r"\bslope\b|slope stability|slope movement", "边坡"),
    (r"landslide|debris\s*flow", "滑坡/泥石流"),
    (r"\bgrain\b|grading|granulometry|distribution", "颗粒/级配"),
    (r"\bclay\b|silt|viscoplastic|rheolog|consolidation|compression", "黏土/本构/固结"),
    (r"\bdem\b|discrete\s*element", "离散元"),
    (r"machine\s*learning|deep\s*learning|neural|gan|bayes|random\s*forest|xgboost|svm", "机器学习/深度学习"),
    (r"suction|stiffness|shear\s*wave|velocity|earthquake|infiltration|rainfall", "吸力/波/地震/渗流"),
    (r"pyroclastic|entrainment", "火山碎屑/夹带"),
]

def detect_keywords(title: str) -> list[str]:
    t = title.lower()
    seen = []
    for pat, label in kw_list:
        if re.search(pat, t):
            seen.append(label)
    # de-duplicate while preserving order
    out = []
    for s in seen:
        if s not in out:
            out.append(s)
    return out[:4]

def guess_year(title: str) -> str:
    m = re.search(r"(19[5-9][0-9]|20[0-3][0-9])", title)
    return m.group(1) if m else "年份未知"

def main() -> None:
    by_cat: dict[str, list[tuple[str, str]]] = defaultdict(list)
    if not os.path.exists(MANIFEST_V2):
        raise SystemExit(f"Manifest not found: {MANIFEST_V2}")

    with open(MANIFEST_V2, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            cat = row.get('category', '').strip()
            filename = row.get('filename', '').strip()
            if not filename:
                continue
            cn = cat_cn.get(cat, '其他')
            # Normalize title for display
            title = filename.replace('_', ' ').strip()
            by_cat[cn].append((title, cn))

    lines: list[str] = []
    lines.append("## 按主题的论文简介（基于清单生成）\n")

    for cn_cat in sorted(by_cat.keys()):
        lines.append(f"### {cn_cat}\n")
        for title, cn in by_cat[cn_cat]:
            kws = detect_keywords(title)
            kw_str = ", ".join(kws) if kws else "(关键词不足)"
            year = guess_year(title)
            phrase = cat_phrase(cn)
            lines.append(f"- 标题：{title}")
            lines.append(f"  - 类别：{cn}；可能年份：{year}；关键词：{kw_str}")
            lines.append(f"  - 简介：本文属于{cn} 方向，关注{phrase}。根据题名与关键词推测，研究主题与方法围绕上述要点展开。\n")

    with open(OUT_MD, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

    print(f"生成完成：{OUT_MD}")

if __name__ == "__main__":
    main()

