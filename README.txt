# InferCNV pipeline version
### Note: currently only work on katmai in DingLab (using absolute path and existing conda environment)

### 2025-08-21 Simon 
### To use:
# copy /Run folder into desire project path on katmai
# modify the path in "run_inferCNV_batch.sh"
# modify the sample_table.tsv 
# run bash run_inferCNV_batch.sh will start the run

===========================================
## Quick Start
===========================================

1. Copy the /Run folder to your project directory
2. Edit ANALYSIS_ROOT path in run_inferCNV_batch.sh
3. Prepare your sample_table.tsv with required columns
4. Run: bash run_inferCNV_batch.sh

===========================================
## Sample Table Format (sample_table.tsv)
===========================================

Required columns (tab-separated):
- sample_id         : Unique identifier for each sample
- seurat_object     : Full path to Seurat RDS file
- meta_path         : Path to metadata CSV file (use "NA" if not needed)
- assay             : Assay name in Seurat object (e.g., "RNA", "SCT")
- celltype_colname  : Column name in metadata containing cell types
- ref_celltypes     : Comma-separated list of reference cell types for CNV inference

Example:
sample_id	seurat_object	meta_path	assay	celltype_colname	ref_celltypes
C1245129	/path/to/sample.rds.gz	/path/to/meta.csv.gz	RNA	cell_type	Astrocyte,Oligodendrocyte,Microglia
C1245130	/path/to/sample2.rds.gz	NA	RNA	cell_type	Astrocyte,Microglia

===========================================
## Bash Script Parameters
===========================================

Usage: ./run_inferCNV_batch.sh [OPTIONS]

Global Parameters (apply to all samples):
-r, --leiden-resolution NUM    Leiden clustering resolution (default: 0.001)
-n, --nthreads NUM            Threads per R job (default: 8)
-j, --jobs NUM                Number of parallel jobs (default: 4)
-o, --output-root DIR         Output root directory (default: set in script)
-h, --help                    Show help message

Resource Management:
Total CPU usage = nthreads × jobs
Example: 8 threads × 4 jobs = 32 total threads

Usage Examples:
# Default settings (4 parallel jobs, 8 threads each = 32 total threads)
bash run_inferCNV_batch.sh

# High parallelism (8 parallel jobs, 4 threads each = 32 total threads)
bash run_inferCNV_batch.sh --jobs 8 --nthreads 4

# Conservative settings (2 parallel jobs, 16 threads each = 32 total threads)  
bash run_inferCNV_batch.sh --jobs 2 --nthreads 16

# Custom resolution and output
bash run_inferCNV_batch.sh --leiden-resolution 0.01 --output-root /custom/path

===========================================
## R Script Parameters
===========================================

Sample-specific parameters (from TSV):
--sample_id           Sample identifier
--seurat_object       Path to Seurat RDS file  
--output_dir          Output directory for this sample
--assay              Assay name (RNA, SCT, etc.)
--celltype_colname   Cell type column name
--ref_celltypes      Reference cell types (comma-separated)
--meta_path          Optional metadata file path

Global parameters (from bash script):
--leiden_resolution   Leiden clustering resolution (numeric)
--nthreads           Number of threads for InferCNV

===========================================
## Output Structure
===========================================

OUTPUT_ROOT/
├── sample1/
│   ├── infercnv_obj.rds           # Final InferCNV object
│   ├── infercnv.png               # Main heatmap
│   ├── infercnv.observations.txt  # CNV matrix
│   └── ... (other InferCNV outputs)
├── sample2/
│   └── ...
└── parallel_job.log               # GNU parallel job log

===========================================
## Important Notes
===========================================

Reference Cell Types:
- Must exist in your Seurat object metadata
- Common types: Astrocyte, Oligodendrocyte, Microglia, Endothelial, Neuron
- Exclude malignant/tumor cell types from reference

Cell Type Column:
- Must exist in Seurat object metadata
- Can be different per sample (specified in TSV)
- If using external metadata, first column should contain cell barcodes

Dependencies:
- GNU parallel (check with: parallel --version)
- R environment: /diskmnt/Users2/cliu/software/miniconda3/envs/r43-base
- Required R packages: infercnv, Seurat, tidyverse, optparse

Troubleshooting:
- Check parallel_job.log for failed jobs
- Ensure all file paths in TSV are accessible
- Verify cell type names match metadata exactly
- Monitor CPU/memory usage during parallel execution

### This is inferCNV pipeline adopted from Clara's version:
/diskmnt/Projects/GBM_sc_analysis/cliu/Brain_tumor_evolution/Analysis/Processing/3_case_processing/3.2_sn_InferCNV_case.R

### Currently use conda build by clara as well here:
conda activate /diskmnt/Users2/cliu/software/miniconda3/envs/r43-base