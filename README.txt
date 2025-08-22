# InferCNV pipeline version
### Note: currently only work on katmai in DingLab (using absolute path and existing conda environment)

### 2025-08-21 Simon 
### To use:
# copy /Run folder into desire project path on katmai
# modify the path in "run_inferCNV_batch.sh"
# modify the sample_table.tsv 
# run bash run_inferCNV_batch.sh will start the run


### This is inferCNV pipeline adopted from Clara's version:
/diskmnt/Projects/GBM_sc_analysis/cliu/Brain_tumor_evolution/Analysis/Processing/3_case_processing/3.2_sn_InferCNV_case.R

### Currently use conda build by clara as well here:
conda activate /diskmnt/Users2/cliu/software/miniconda3/envs/r43-base