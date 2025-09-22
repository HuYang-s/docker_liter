#!/usr/bin/env bash
set -euo pipefail

BASE="/workspace/papers_by_topic"
VIEW="/workspace/papers_by_topic_symlinks"

mkdir -p "$VIEW"
rm -rf "${VIEW:?}"/* || true

slugify_name() {
	# Lowercase ASCII; replace spaces/underscores with hyphens; remove path-like chars; collapse hyphens
	local s="$1"
	s=$(echo -n "$s" | tr '[:upper:]' '[:lower:]')
	s=$(echo -n "$s" | sed -E 's/[[:space:]]+/-/g; s/_+/-/g; s#[/\\:*?"<>|]+#-#g; s/-{2,}/-/g; s/^-+//; s/-+$//')
	if [ -z "$s" ]; then s="paper"; fi
	echo -n "$s"
}

classify_file() {
	local f="$1"
	# Extract ASCII strings; lowercase; collapse whitespace; limit size
	local txt
	txt=$(strings -a "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-200000 || true)
	# Fallback to filename if content extraction gives nothing
	if [ -z "$txt" ]; then
		txt=$(basename "$f" | tr '[:upper:]' '[:lower:]')
	fi
	# AI/ML
	if echo "$txt" | grep -qiE 'artificial intelligence|machine learning|deep learning|neural( network)?|generative adversarial|\bgan\b|bayes(ian)?|random forest|xgboost|\bsvm\b|data[-_ ]?driven|schema gan|人工智能|机器学习|深度学习|神经网络|生成对抗网络'; then
		echo ai_ml; return 0
	fi
	# Reviews
	if echo "$txt" | grep -qiE '\breview\b|meta[- ]?analysis|state of the|综述'; then
		echo review_general; return 0
	fi
	# Liquefaction
	if echo "$txt" | grep -qiE 'liquefaction|undrain|nor[[:space:]]*sand|casm|液化'; then
		echo liquefaction; return 0
	fi
	# Tailings
	if echo "$txt" | grep -qiE 'tailings?|尾矿'; then
		echo tailings; return 0
	fi
	# Landslides / debris flows / pyroclastic
	if echo "$txt" | grep -qiE 'landslide|debris[[:space:]]*flow|pyroclastic|entrainment|滑坡|泥石流|火山碎屑'; then
		echo landslide; return 0
	fi
	# Slope
	if echo "$txt" | grep -qiE '\bslope\b|slope stability|slope movement|边坡'; then
		echo slope; return 0
	fi
	# Grain/distribution
	if echo "$txt" | grep -qiE '\bgrain\b|grading|granulometry|distribution|颗粒|级配'; then
		echo grain_distribution; return 0
	fi
	# Clay/rheology/consolidation/viscous
	if echo "$txt" | grep -qiE '\bclay\b|silts?|peat|viscoplastic|rheolog|consolidation|compression|viscous|黏土|粘土|粉土|固结|压缩'; then
		echo clay_rheology; return 0
	fi
	# DEM
	if echo "$txt" | grep -qiE '\bdem\b|discrete[[:space:]]*element|离散元'; then
		echo dem; return 0
	fi
	# Hydro/geo/seismic
	if echo "$txt" | grep -qiE 'wave|seiche|hydrodynamic|hydromechan|suction|stiffness|shear[[:space:]]*wave|velocity|earthquake|infiltration|rainfall|基质吸力|剪切波|地震|渗流|入渗|降雨'; then
		echo hydrology_geophysics; return 0
	fi
	echo other
}

# Build symlink view
while IFS= read -r -d '' file; do
	cat=$(classify_file "$file")
	mkdir -p "$VIEW/$cat"
	name=$(basename "$file")
	link_target="$VIEW/$cat/$name"
	if [ -e "$link_target" ]; then
		# avoid name collision within view
		stem=${name%.pdf}
		idx=2
		while [ -e "$VIEW/$cat/${stem}-$idx.pdf" ]; do idx=$((idx+1)); done
		link_target="$VIEW/$cat/${stem}-$idx.pdf"
	fi
	ln -sfn "$file" "$link_target"
done < <(find "$BASE" -type f -iname '*.pdf' -print0)

# Summarize counts
COUNTS="/workspace/papers_by_topic_counts_v4_symlinks.csv"
printf 'Category,Count\n' > "$COUNTS"
for d in "$VIEW"/*; do
	[ -d "$d" ] || continue
	count=$(find "$d" -maxdepth 1 -type l | wc -l)
	printf '%s,%s\n' "$(basename "$d")" "$count" >> "$COUNTS"
done

echo "Symlink view built at: $VIEW"
echo "Counts CSV: $COUNTS"

# Build markdown overview
MD="/workspace/topics_overview_symlinks.md"
{
	echo "## Papers by Topic (Symlink View)"
	echo
	for d in "$VIEW"/*; do
		[ -d "$d" ] || continue
		catname=$(basename "$d")
		echo "### $catname"
		echo
		while IFS= read -r -d '' lnk; do
			base=$(basename "$lnk")
			tgt=$(readlink -f "$lnk")
			echo "- $base ($tgt)"
		done < <(find "$d" -maxdepth 1 -type l -print0 | sort -z)
		echo
	done
} > "$MD"
echo "Overview MD: $MD"

