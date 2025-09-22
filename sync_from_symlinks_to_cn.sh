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

find_source_for_link() {
    local lnk="$1"
    local name
    name=$(basename "$lnk")
    local t
    t=$(readlink -f "$lnk" 2>/dev/null || true)
    if [ -n "${t:-}" ] && [ -e "$t" ]; then
        echo "$t"; return 0
    fi
    # Fallback: search in CNBASE first (already moved earlier)
    local found
    found=$(find "$CNBASE" -type f -iname "$name" -print -quit 2>/dev/null || true)
    if [ -n "${found:-}" ]; then
        echo "$found"; return 0
    fi
    # Fallback: search in BASE by name
    found=$(find "$BASE" -type f -iname "$name" -print -quit 2>/dev/null || true)
    if [ -n "${found:-}" ]; then
        echo "$found"; return 0
    fi
    return 1
}

# Ensure CN category directories exist
for cat in ai_ml liquefaction tailings slope landslide grain_distribution clay_rheology dem hydrology_geophysics review_general other; do
    mkdir -p "$CNBASE/$(cn_name "$cat")"
done

# Iterate symlinks and move files (from BASE or CNBASE fallback) to Chinese directories
shopt -s nullglob
for catdir in "$VIEW"/*; do
    [ -d "$catdir" ] || continue
    engcat=$(basename "$catdir")
    cncat=$(cn_name "$engcat")
    for lnk in "$catdir"/*.pdf; do
        [ -L "$lnk" ] || continue
        src=$(find_source_for_link "$lnk" || true)
        [ -n "${src:-}" ] || continue
        # Skip if already in correct cncat directory
        if [[ "$src" == "$CNBASE/$cncat"/* ]]; then
            continue
        fi
        move_safe "$src" "$CNBASE/$cncat"
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

