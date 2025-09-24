#!/bin/bash
# dorado-workflow.sh
#
# A wrapper script for running Oxford Nanopore Dorado basecalling, demultiplexing,
# and converting demultiplexed BAMs into cleanly named gzipped FASTQs.
#
# Requirements:
#   - dorado binary (>=1.1.1)
#   - samtools
#   - gzip
#
# Usage:
#   ./ dorado-workflow.sh <dorado_bin> <input_pod5_dir> <output_bam> [kit_name]
#
# Example:
#   ./ dorado-workflow.sh ./dorado-1.1.1-linux-x64/bin/dorado ./pod5 reads.bam SQK-LSK114
#
# Notes:
#   - Default kit = SQK-RBK114-96 if not provided
#   - Output FASTQs will be in ./results/fastq
#   - Renamed format: barcodeXX.fastq.gz

set -euo pipefail

############################################
# Arguments
############################################
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <dorado_bin> <input_pod5_dir> <output_bam> [kit_name]"
  exit 1
fi

DORADO_BIN="$1"       # path to dorado binary
INPUT_DIR="$2"        # pod5 input directory
OUTPUT_BAM="$3"       # output bam from basecalling
KIT_NAME="${4:-SQK-RBK114-96}"  # kit name (default if not supplied)

############################################
# Step 1. Basecalling
############################################
echo "🚀 Step 1: Basecalling with Dorado..."
echo "   Using kit: $KIT_NAME"

"$DORADO_BIN" basecaller sup "$INPUT_DIR" \
  -x cuda:all \
  --kit-name "$KIT_NAME" \
  > "$OUTPUT_BAM"

echo "✅ Basecalling complete → $OUTPUT_BAM"

############################################
# Step 2. Demultiplexing
############################################
DEMUX_DIR="./demux_bams"
mkdir -p "$DEMUX_DIR"

echo "🚀 Step 2: Demultiplexing..."
"$DORADO_BIN" demux "$OUTPUT_BAM" \
  --no-classify \
  --output-dir "$DEMUX_DIR"

echo "✅ Demultiplexing complete → $DEMUX_DIR"

############################################
# Step 3. BAM → gzipped FASTQ
############################################
FASTQ_DIR="./results/fastq"
mkdir -p "$FASTQ_DIR"

echo "🚀 Step 3: Converting BAMs to FASTQs..."
for bam in "$DEMUX_DIR"/*.bam; do
  [ -e "$bam" ] || { echo "⚠️ No demultiplexed BAM files found!"; exit 1; }

  # Extract the barcode index from the filename
  barcode=$(basename "$bam" | sed -E 's/.*_(barcode[0-9]+)/\1/')

  outfq="${FASTQ_DIR}/${barcode}.fastq.gz"

  echo "  → $bam → $outfq"
  samtools fastq "$bam" | gzip > "$outfq"
done

echo "✅ All FASTQs generated in $FASTQ_DIR"
ls -lh