#!/bin/bash

#SBATCH --array=1-5
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=8000M
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

DATASET=$1
PARTICIPANT=$2
SING_IMG=$3

INPUT_DIR=${SCRATCH}/fmriprep-lts
OUTPUT_DIR=${INPUT_DIR}/outputs/ieee/fmriprep_${DATASET}_${SLURM_ARRAY_TASK_ID}
export SINGULARITYENV_FS_LICENSE=${HOME}/.freesurfer.txt
export SINGULARITYENV_TEMPLATEFLOW_HOME=/templateflow

module load singularity/3.6

#copying input dataset into local scratch space
rsync -rltv --info=progress2 ${INPUT_DIR} ${SLURM_TMPDIR}

singularity run --cleanenv -B ${SLURM_TMPDIR}/fmriprep-lts:/WORK -B ${HOME}/.cache/templateflow:/templateflow -B /etc/pki:/etc/pki/ \
    ${SLURM_TMPDIR}/fmriprep-lts/envs/${SING_IMG} \
    -w /WORK/fmriprep_work \
    --output-spaces MNI152NLin2009cAsym MNI152NLin6Asym \
    --notrack --write-graph --resource-monitor \
    --omp-nthreads 8 --nprocs 16 --mem_mb 65536 \
    --participant-label ${PARTICIPANT} --random-seed 0 --skull-strip-fixed-seed \
    /WORK/inputs/openneuro/${DATASET} /WORK/inputs/openneuro/${DATASET}/derivatives/fmriprep participant
fmriprep_exitcode=$?

if [ $fmriprep_exitcode -ne 0 ] ; then
    cp -r ${SLURM_TMPDIR}/fmriprep-lts/fmriprep_work ${SCRATCH}/fmriprep_${DATASET}-${PARTICIPANT}_${SLURM_ARRAY_TASK_ID}.workdir
fi 
if [ $fmriprep_exitcode -eq 0 ] ; then
    mkdir -p ${OUTPUT_DIR}
    cp -r ${SLURM_TMPDIR}/fmriprep-lts/inputs/openneuro/${DATASET}/derivatives/fmriprep/* ${OUTPUT_DIR}
    rm -r ${SLURM_TMPDIR}/fmriprep-lts/inputs/openneuro/${DATASET}/derivatives/fmriprep/*
    cp ${SLURM_TMPDIR}/fmriprep-lts/fmriprep_work/fmriprep_wf/resource_monitor.json ${OUTPUT_DIR}
fi
rm -r ${SLURM_TMPDIR}/fmriprep-lts/fmriprep_work

exit $fmriprep_exitcode 
