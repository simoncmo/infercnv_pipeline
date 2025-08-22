### conda activate /diskmnt/Users2/cliu/software/miniconda3/envs/r43-base
### Simon 2025-08-21: Modified from Clara's version
### InferCNV on merged case-level snRNA sample
### 2025/07/25
### env: r43-base (Users2)

# ======= Read parameters for batch script ========
library(optparse)
option_list = list(
  make_option(c("-s", "--sample_id"),
        type="character",
        default=NULL,
        help="sample id",
        metavar="character"),
  make_option(c("-o", "--seurat_object"),
        type="character", 
        default=NULL,
        help="path to seurat object file",
        metavar="character"),
  make_option(c("-a", "--assay"),
		type="character",
		default="RNA",
		help="assay name in the seurat object (default: RNA)",
		metavar="character"),
  make_option(c("-c", "--celltype_colname"),
		type="character",
		default="cell_type",
		help="column name in metadata for cell types (default: cell_type)",
		metavar="character"),
  make_option(c("-r", "--ref_celltypes"),
		type="character",
		default=NULL,
		help="comma-separated list of reference cell types for CNV inference",
		metavar="character"),
  make_option(c("-m", "--meta_path"),
        type="character",
        default=NULL,
        help="optional path to metadata file",
        metavar="character"),
  make_option(c("-d", "--output_dir"),
        type="character",
        default=NULL,
        help="output directory path",
        metavar="character"),
  make_option(c("-l", "--leiden_resolution"),
		type="numeric",	
		default=0.001,
		help="resolution parameter for Leiden clustering (default: 0.001)",
		metavar="numeric"),
  make_option(c("-n", "--nthreads"),
		type="integer",
		default=1,
		help="number of threads to use (default: 1)",
		metavar="integer")
  )
opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser)
print(dput(opt))

# Validate required parameters
if (is.null(opt$sample_id) || is.null(opt$seurat_object) || is.null(opt$output_dir)) {
  print_help(opt_parser)
  stop("Missing required parameters: sample_id, seurat_object, and output_dir are required.")
}

sample_id = opt$sample_id
obj_path = opt$seurat_object
meta_path = opt$meta_path
output_dir = opt$output_dir


# ======= Packages =======
library(infercnv)
library(Seurat)
library(Signac)
library(reticulate)
library(tidyverse)
library(scales)
# use_python("/diskmnt/Users2/cliu/software/miniconda3/envs/r43-base/bin/python3.13", required = TRUE)
use_condaenv("/diskmnt/Users2/cliu/software/miniconda3/envs/r43-base", required = TRUE)
reticulate::py_config()
# ordered gene file
# ordered_gene_file = "/diskmnt/Projects/GBM_sc_analysis/cliu/Brain_tumor_evolution/Resource/gencode_v32_gene_name.txt"
ordered_gene_file = "/diskmnt/Users2/simonmo/Tools/Seurat/InferCNV/input/gencode_v32_gene_name.txt" # Copy from above
options(future.globals.maxSize = 1000 * 1024^3) # 1000 GB


# ======= Read seurat object ========
obj = readRDS(obj_path)

# Add metadata if provided
if (!is.null(meta_path) && file.exists(meta_path)) {
	sep_use = ifelse(str_detect(meta_path, "\\.csv$"), ",", "\t")
	meta_add = read.table(meta_path, header = TRUE, row.names = 1, sep = sep_use, stringsAsFactors = FALSE) %>%
		mutate(cell_type = .data[[opt$celltype_colname]]) %>% 
		select(cell_type)
	obj = AddMetaData(obj, meta_add[Cells(obj),,drop=F])
} else {
  print(paste0("[inferCNV] No metadata file provided or file does not exist: ", meta_path))
}

# Print cell type counts
print(obj@meta.data %>% count(cell_type) %>% arrange(desc(n)))

# Idents(obj) = "seurat_clusters"

# ======= Prepare for InferCNV =======
print(paste0("[inferCNV] Start running for sample: ", sample_id))
counts_matrix = GetAssayData(object = obj, assay=opt$assay, layer = "counts")

# Load Ordered gene list : gencode_v19_gene_pos.txt
gene_order_file = read.delim(file = ordered_gene_file, 
			     header=FALSE, stringsAsFactors = FALSE, sep="\t") %>%
	column_to_rownames("V1")

cell_type_file = data.frame(
	"cell_ID" = Cells(obj),
	"celltype" = paste0(obj@meta.data[,'cell_type'])) %>%
	column_to_rownames("cell_ID")

# Set reference cell types
if (!is.null(opt$ref_celltypes)) {
	ref_celltypes = strsplit(opt$ref_celltypes, ",")[[1]]
	ref_celltypes = intersect(ref_celltypes, cell_type_file$celltype)
	# Filter out cells less than 10 # to avoid empty reference groups
	cell_counts = table(cell_type_file$celltype)
	ref_celltypes = ref_celltypes[cell_counts[ref_celltypes] >= 10]
	if (length(ref_celltypes) == 0) {
		stop("No valid reference cell types found with at least 10 cells.")
	}
	# Print reference cell types
	message(paste0("[inferCNV] Reference cell types set to: ", paste(ref_celltypes, collapse=", ")))
} else {
	stop("Reference cell types must be provided via --ref_celltypes option.")
}

# ======= Run InferCNV =======
# Create InferCNV object
infercnv_obj = CreateInfercnvObject(raw_counts_matrix=counts_matrix,
									annotations_file=cell_type_file,
									delim="\t",
									gene_order_file=gene_order_file,
									ref_group_names=ref_celltypes)

# Run InferCNV analysis
infercnv_obj = infercnv::run(infercnv_obj,
							 cutoff=0.1,
							 out_dir=output_dir,
							 cluster_by_groups=TRUE,
							 denoise=TRUE,
							 HMM=TRUE,# cluster
                             plot_steps=FALSE,
                             mask_nonDE_genes = T,
                             resume_mode=F,
                             leiden_method = "simple",
                             leiden_function = "CPM",
                             leiden_resolution=opt$leiden_resolution, # 0.001,
                             num_threads = opt$nthreads, # 56
							 analysis_mode='subclusters')

print(paste0("[inferCNV] Completed analysis for sample: ", sample_id))

# ======= Save results =======
# Save the final infercnv object
saveRDS(infercnv_obj, file=str_interp("${output_dir}/infercnv_obj.rds"))

print(paste0("[inferCNV] Results saved to: ", output_dir))
