#!/bin/bash

# Set project folder
ANALYSIS_ROOT="/diskmnt/Users2/simonmo/Tools/Seurat/InferCNV/TEST" # Change this
SAMPLE_TABLE="${ANALYSIS_ROOT}/Run/sample_table.tsv" # Change if needed
OUTPUT_ROOT="${ANALYSIS_ROOT}/output"
mkdir -p "$OUTPUT_ROOT"

# Set default paths
R_SCRIPT="/diskmnt/Users2/simonmo/Tools/Seurat/InferCNV/script/sn_inferCNV_generic.R"
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#R_SCRIPT="${SCRIPT_DIR}/sn_inferCNV_generic.R"

# Default global parameters
DEFAULT_LEIDEN_RESOLUTION=0.001
DEFAULT_NTHREADS=8
DEFAULT_PARALLEL_JOBS=4

# Function to display usage
show_usage() {
    echo "Usage: $0 <sample_table.tsv> [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  sample_table.tsv    TSV file with columns: sample_id, seurat_object, meta_path, assay, celltype_colname, ref_celltypes"
    echo ""
    echo "Options:"
    echo "  -o, --output-root DIR        Output root directory (default: $OUTPUT_ROOT)"
    echo "  -r, --leiden-resolution NUM  Leiden resolution for all samples (default: $DEFAULT_LEIDEN_RESOLUTION)"
    echo "  -n, --nthreads NUM           Number of threads per R job (default: $DEFAULT_NTHREADS)"
    echo "  -j, --jobs NUM               Number of parallel jobs (default: $DEFAULT_PARALLEL_JOBS)"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Note: Total CPU usage = nthreads × jobs. Adjust accordingly for your system."
}

# Parse command line arguments
# SAMPLE_TABLE=""
LEIDEN_RESOLUTION=$DEFAULT_LEIDEN_RESOLUTION
NTHREADS=$DEFAULT_NTHREADS
PARALLEL_JOBS=$DEFAULT_PARALLEL_JOBS

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output-root)
            OUTPUT_ROOT="$2"
            shift 2
            ;;
        -r|--leiden-resolution)
            LEIDEN_RESOLUTION="$2"
            shift 2
            ;;
        -n|--nthreads)
            NTHREADS="$2"
            shift 2
            ;;
        -j|--jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$SAMPLE_TABLE" ]; then
                SAMPLE_TABLE="$1"
            else
                echo "Unexpected argument: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if sample TSV file is provided
if [ -z "$SAMPLE_TABLE" ]; then
    echo "Error: Sample table file is required"
    show_usage
    exit 1
fi

# Check if files exist
if [ ! -f "$SAMPLE_TABLE" ]; then
    echo "Error: Sample table file $SAMPLE_TABLE not found"
    exit 1
fi

if [ ! -f "$R_SCRIPT" ]; then
    echo "Error: R script $R_SCRIPT not found"
    exit 1
fi

# Check if GNU parallel is available
if ! command -v parallel &> /dev/null; then
    echo "Error: GNU parallel is not installed. Please install it first."
    echo "On most systems: sudo apt-get install parallel (Ubuntu/Debian) or brew install parallel (macOS)"
    exit 1
fi

# Activate conda environment
source /diskmnt/Users2/cliu/software/miniconda3/etc/profile.d/conda.sh
conda activate /diskmnt/Users2/cliu/software/miniconda3/envs/r43-base

echo "Starting batch processing of inferCNV using GNU parallel..."
echo "Sample table: $SAMPLE_TABLE"
echo "Output root: $OUTPUT_ROOT"
echo "R script: $R_SCRIPT"
echo "Global parameters:"
echo "  Leiden resolution: $LEIDEN_RESOLUTION"
echo "  Number of threads per job: $NTHREADS"
echo "  Number of parallel jobs: $PARALLEL_JOBS"
echo "  Total CPU usage: $((NTHREADS * PARALLEL_JOBS)) threads"
echo ""

# Create output root directory
mkdir -p "$OUTPUT_ROOT"

# Function to process a single sample
process_sample() {
    local sample_id="$1"
    local seurat_object="$2" 
    local meta_path="$3"
    local assay="$4"
    local celltype_colname="$5"
    local ref_celltypes="$6"
    local leiden_resolution="$7"
    local nthreads="$8"
    local output_root="$9"
    local r_script="${10}"
    
    echo "[$(date)] Starting sample: $sample_id"
    
    # Create sample-specific output directory
    sample_output_dir="${output_root}/${sample_id}"
    mkdir -p "$sample_output_dir"
    
    # Build R command with all parameters
    cmd="Rscript '$r_script'"
    cmd="$cmd --sample_id '$sample_id'"
    cmd="$cmd --seurat_object '$seurat_object'"
    cmd="$cmd --output_dir '$sample_output_dir'"
    cmd="$cmd --assay '$assay'"
    cmd="$cmd --celltype_colname '$celltype_colname'"
    cmd="$cmd --ref_celltypes '$ref_celltypes'"
    cmd="$cmd --leiden_resolution $leiden_resolution"
    cmd="$cmd --nthreads $nthreads"
    
    # Add metadata path if provided and not empty/NA
    if [ -n "$meta_path" ] && [ "$meta_path" != "NA" ] && [ "$meta_path" != "" ]; then
        cmd="$cmd --meta_path '$meta_path'"
    fi
    
    echo "[$(date)] Running: $cmd"
    
    # Execute command and capture exit status
    if eval $cmd; then
        echo "[$(date)] ✓ Successfully processed $sample_id"
        return 0
    else
        echo "[$(date)] ✗ Failed to process $sample_id"
        return 1
    fi
}

# Export the function so parallel can use it
export -f process_sample

# Use GNU parallel to process samples
echo "Processing samples in parallel..."
tail -n +2 "$SAMPLE_TABLE" | parallel --colsep '\t' --jobs $PARALLEL_JOBS --joblog "${OUTPUT_ROOT}/parallel_job.log" \
    process_sample {1} {2} {3} {4} {5} {6} $LEIDEN_RESOLUTION $NTHREADS $OUTPUT_ROOT $R_SCRIPT

# Check parallel execution results
if [ $? -eq 0 ]; then
    echo ""
    echo "✓ All samples processed successfully!"
else
    echo ""
    echo "⚠ Some samples may have failed. Check the job log: ${OUTPUT_ROOT}/parallel_job.log"
fi

echo ""
echo "Batch processing completed!"
echo "Results saved in: $OUTPUT_ROOT"
echo "Job log saved in: ${OUTPUT_ROOT}/parallel_job.log"

# Display summary from job log
if [ -f "${OUTPUT_ROOT}/parallel_job.log" ]; then
    echo ""
    echo "Job Summary:"
    echo "============"
    awk 'NR>1 {
        if ($7 == 0) success++; else failed++; 
        total++
    } 
    END {
        print "Total jobs: " total
        print "Successful: " (success ? success : 0)
        print "Failed: " (failed ? failed : 0)
    }' "${OUTPUT_ROOT}/parallel_job.log"
fi
