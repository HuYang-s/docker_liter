#!/usr/bin/env bash
set -euo pipefail

BASE="/workspace/papers_by_topic"

classify_file() {
	local f="$1"
	local txt
	txt=$(strings -a "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-200000 || true)
	if [ -z "$txt" ]; then
		txt=$(basename "$f" | tr '[:upper:]' '[:lower:]')
	fi
	if echo "$txt" | grep -qiE 'artificial intelligence|machine learning|deep learning|neural( network)?|generative adversarial|\bgan\b|bayes(ian)?|random forest|xgboost|\bsvm\b|data[-_ ]?driven|schema gan|人工智能|机器学习|深度学习|神经网络|生成对抗网络'; then
		echo ai_ml; return 0
	fi
	if echo "$txt" | grep -qiE '\breview\b|meta[- ]?analysis|state of the|综述'; then echo review_general; return 0; fi
	if echo "$txt" | grep -qiE 'liquefaction|undrain|nor[[:space:]]*sand|casm|液化'; then echo liquefaction; return 0; fi
	if echo "$txt" | grep -qiE 'tailings?|尾矿'; then echo tailings; return 0; fi
	if echo "$txt" | grep -qiE 'landslide|debris[[:space:]]*flow|pyroclastic|entrainment|滑坡|泥石流|火山碎屑'; then echo landslide; return 0; fi
	if echo "$txt" | grep -qiE '\bslope\b|slope stability|slope movement|边坡'; then echo slope; return 0; fi
	if echo "$txt" | grep -qiE '\bgrain\b|grading|granulometry|distribution|颗粒|级配'; then echo grain_distribution; return 0; fi
	if echo "$txt" | grep -qiE '\bclay\b|silts?|peat|viscoplastic|rheolog|consolidation|compression|viscous|黏土|粘土|粉土|固结|压缩'; then echo clay_rheology; return 0; fi
	if echo "$txt" | grep -qiE '\bdem\b|discrete[[:space:]]*element|离散元'; then echo dem; return 0; fi
	if echo "$txt" | grep -qiE 'wave|seiche|hydrodynamic|hydromechan|suction|stiffness|shear[[:space:]]*wave|velocity|earthquake|infiltration|rainfall|基质吸力|剪切波|地震|渗流|入渗|降雨'; then echo hydrology_geophysics; return 0; fi
	echo other
}

move_safe() {
	local src="$1"; shift
	local dst_dir="$1"; shift
	mkdir -p "$dst_dir"
	local base
	base=$(basename "$src")
	local tgt="$dst_dir/$base"
	if [ -e "$tgt" ]; then
		local stem ext i
		stem=${base%.pdf}
		ext=.pdf
		i=2
		while [ -e "$dst_dir/${stem}-r${i}${ext}" ]; do i=$((i+1)); done
		tgt="$dst_dir/${stem}-r${i}${ext}"
	fi
	mv -n -- "$src" "$tgt"
}

# Reclassify current 'other' only
shopt -s nullglob
for f in "$BASE/other"/*.pdf; do
	cat=$(classify_file "$f")
	[ "$cat" = other ] && continue
	move_safe "$f" "$BASE/$cat"
done

# Recompute counts
COUNTS="/workspace/papers_by_topic_counts_v5.csv"
printf 'Category,Count\n' > "$COUNTS"
for d in "$BASE"/*; do [ -d "$d" ] || continue; c=$(find "$d" -maxdepth 1 -type f -iname '*.pdf' | wc -l); printf '%s,%s\n' "$(basename "$d")" "$c" >> "$COUNTS"; done
echo "Updated counts at $COUNTS"

# Overview
MD="/workspace/topics_overview_v5.md"
{
	echo "## Papers by Topic (Real Folders)"
	echo
	for d in "$BASE"/*; do
		[ -d "$d" ] || continue
		catname=$(basename "$d")
		echo "### $catname"
		echo
		find "$d" -maxdepth 1 -type f -iname '*.pdf' -printf '- %f\n' | sort
		echo
	done
} > "$MD"
echo "Overview MD: $MD"

