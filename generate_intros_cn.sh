#!/usr/bin/env bash
set -euo pipefail

CNBASE="/workspace/按主题分类"
OUT_MD="/workspace/paper_intros_cn.md"

cat_phrase() {
	case "$1" in
		人工智能) echo "机器学习/深度学习在岩土/地质问题中的应用" ;;
		液化) echo "砂土/尾矿材料液化机制、触发与评价" ;;
		尾矿) echo "尾矿坝材料与稳定性" ;;
		边坡) echo "边坡过程与稳定性" ;;
		滑坡) echo "滑坡/泥石流动力学" ;;
		颗粒与级配) echo "颗粒级配、粒径统计与分布特征" ;;
		黏土与流变) echo "黏土/粉土流变与本构、固结/压缩特性" ;;
		离散元) echo "离散元（DEM）建模与颗粒介质行为" ;;
		水文地球物理) echo "水力-地球物理响应（吸力、波、渗流等）" ;;
		综述) echo "领域综述与研究综合" ;;
		*) echo "通用岩土/地学问题" ;;
	 esac
}

# Prepare header
{
	echo "## 按主题的论文简介"
	echo
} > "$OUT_MD"

# Iterate Chinese categories
shopt -s nullglob
for d in "$CNBASE"/*; do
	[ -d "$d" ] || continue
	CAT=$(basename "$d")
	echo "### $CAT" >> "$OUT_MD"
	echo >> "$OUT_MD"
	for f in "$d"/*.pdf; do
		FN=$(basename "$f")
		# Extract ASCII text (limit lines for speed), with fallback to tail
		TXT_HEAD=$(strings -a "$f" 2>/dev/null | sed 's/\r$//' | head -n 800 || true)
		TXT_TAIL=$(strings -a "$f" 2>/dev/null | sed 's/\r$//' | tail -n 400 || true)
		TXT="$TXT_HEAD\n$TXT_TAIL"
		# Guess title: first reasonable line with many letters, avoid boilerplate
		TITLE=$(echo -e "$TXT" | awk 'length($0)>=10 && length($0)<=140 && $0 ~ /[A-Za-z]/ && $0 !~ /(doi|creative|commons|elsevier|license|rights|arxiv|sciencedirect|manuscript|preprint|download|www\.|http)/ {print $0}' | head -n 1)
		[ -z "${TITLE:-}" ] && TITLE="(未识别标题)"
		# Abstract snippet (up to 300 chars)
		ABS=$(echo -e "$TXT" | awk 'BEGIN{IGNORECASE=1} {print NR":"$0}' | awk -F: 'BEGIN{IGNORECASE=1} /abstract/{s=NR} s && NR<=s+6 {print $2}')
		ABS=$(echo "$ABS" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-300)
		[ -z "${ABS:-}" ] && ABS="(未检测到摘要片段，基于关键词进行简介)"
		# Year guess from first 200 lines
		YEAR=$(echo -e "$TXT" | head -n 200 | grep -o -E '19[5-9][0-9]|20[0-3][0-9]' | head -n 1 || true)
		[ -z "${YEAR:-}" ] && YEAR="(年份未知)"
		# Keyword counts
		KN_TXT=$(echo -e "$TXT" | tr '[:upper:]' '[:lower:]')
		declare -a KNAMES=(
			"liquefaction" "tailings" "slope" "landslide" "debris flow" "grain" "distribution" "granulometry" "clay" "rheolog" "viscoplastic" "dem" "discrete element" "machine learning" "deep learning" "neural" "gan" "bayes" "random forest" "xgboost" "svm" "suction" "stiffness" "shear wave" "velocity" "earthquake" "infiltration" "rainfall" "consolidation" "compression" "pyroclastic" "entrainment"
		)
		KRES=()
		for kw in "${KNAMES[@]}"; do
			c=$( { echo "$KN_TXT" | grep -o -i -E "${kw}" || true; } | wc -l | tr -d ' ')
			KRES+=("$c\t$kw")
		done
		TOP3=$(printf '%s\n' "${KRES[@]}" | sort -nr -k1,1 | head -n 3 | awk '{print $2}' | paste -sd ', ' -)
		[ -z "${TOP3:-}" ] && TOP3="(关键词不足)"
		PHRASE=$(cat_phrase "$CAT")
		# Write entry
		echo "- 文件：$FN" >> "$OUT_MD"
		echo "  - 推测标题：$TITLE" >> "$OUT_MD"
		echo "  - 类别：$CAT；可能年份：$YEAR；关键词：$TOP3" >> "$OUT_MD"
		echo "  - 简介：本文属于$CAT 方向，关注$PHRASE。基于检索到的关键词（$TOP3），推测研究主题与方法围绕上述要点展开。摘要片段：$ABS" >> "$OUT_MD"
		echo >> "$OUT_MD"
		unset KNAMES KRES KN_TXT
	done
	echo >> "$OUT_MD"
 done

 echo "生成完成：$OUT_MD"

