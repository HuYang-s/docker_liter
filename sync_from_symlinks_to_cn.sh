#!/usr/bin/env bash
set -euo pipefail

VIEW="/workspace/papers_by_topic_symlinks"
BASE="/workspace/papers_by_topic"
CNBASE="/workspace/按主题分类"

mkdir -p "$CNBASE"

cn_name() {
	# Map English category -> Chinese folder name
	case "$1" in
		ai_ml) echo "人工智能" ;;
		liquefaction) echo "液化" ;;
		tailings) echo "尾矿" ;;
		slope) echo "边坡" ;;
		landslide) echo "滑坡" ;;
		grain_distribution) echo "颗粒与级配" ;;
		clay_rheology) echo "黏土与流变" ;;
		dem) echo "离散元" ;;
		hydrology_geophysics) echo "水文地球物理" ;;
		review_general) echo "综述" ;;
		modeling_ml) echo "建模" ;;
		*) echo "其他" ;;
	 esac
}

move_safe() {
	local src="$1"; shift
	local dstdir="$1"; shift
	mkdir -p "$dstdir"
	local name base ext i tgt
	name=$(basename "$src")
	base=${name%.pdf}
	ext=.pdf
	tgt="$dstdir/$name"
	if [ -e "$tgt" ]; then
		i=2
		while [ -e "$dstdir/${base}-m${i}${ext}" ]; do i=$((i+1)); done
		tgt="$dstdir/${base}-m${i}${ext}"
	fi
	mv -n -- "$src" "$tgt"
}

# Iterate symlinks and move actual files to Chinese directories
shopt -s nullglob
for catdir in "$VIEW"/*; do
	[ -d "$catdir" ] || continue
	engcat=$(basename "$catdir")
	cncat=$(cn_name "$engcat")
	for lnk in "$catdir"/*.pdf; do
		[ -L "$lnk" ] || continue
		target=$(readlink -f "$lnk" || true)
		[ -n "${target:-}" ] || continue
		# Only move if the target exists and is still under the original BASE
		if [ -e "$target" ] && [[ "$target" == "$BASE"/* ]]; then
			move_safe "$target" "$CNBASE/$cncat"
		fi
	 done
done

# Generate Chinese manifest and counts
CN_MANIFEST="/workspace/papers_manifest_cn.csv"
printf '分类,文件名,相对路径\n' > "$CN_MANIFEST"
find "$CNBASE" -type f -iname '*.pdf' -printf '%P\n' | awk -F/ '{print $1","$NF","$0}' >> "$CN_MANIFEST"

CN_COUNTS="/workspace/papers_by_topic_counts_cn.csv"
printf '分类,数量\n' > "$CN_COUNTS"
for d in "$CNBASE"/*; do
	[ -d "$d" ] || continue
	cnt=$(find "$d" -maxdepth 1 -type f -iname '*.pdf' | wc -l)
	printf '%s,%s\n' "$(basename "$d")" "$cnt" >> "$CN_COUNTS"
done

echo "同步完成：$CNBASE"
echo "清单：$CN_MANIFEST"
echo "计数：$CN_COUNTS"

