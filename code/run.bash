#!/bin/bash

echo "./run.bash "$@
echo "Starting process.."
echo ""

# user parameters
SUBMIT=false # whether to launch the jobs or just print the commands
SLURM=false # whether to submit slurm jobs or raw cmd
SLURM_SCRIPT="fmriprep-slurm.bash" # slurm script name
SING_IMG="fmriprep-lts-20.2.1.sif" # fmriprep version
ACCOUNT= # slurm account name
MAIL_USER= # mail for job status
# paths
SCRIPT_DIR=$(readlink -e $(dirname $0))
PROJECT_DIR=$SCRIPT_DIR/../
OPENNEURO=$PROJECT_DIR/inputs/openneuro/
FMRIPREP_CONTAINER=$PROJECT_DIR/envs/singularity-images/$SING_IMG

# argument parser
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --submit)
    SUBMIT=true
    shift # past argument
    ;;
    --slurm)
    SLURM=true
    shift # past argument
    ;;
    --slurm-script)
    SLURM_SCRIPT="$2"
    shift # past argument
    shift # past value
    ;;
    --fmriprep-version)
    SING_IMG="fmriprep-lts-$2.sif" # fmriprep version
    FMRIPREP_CONTAINER=$PROJECT_DIR/envs/singularity-images/$SING_IMG
    shift # past argument
    shift # past value
    ;;
    -a|--account)
    ACCOUNT="$2"
    shift # past argument
    shift # past value
    ;;
    -m|--mail)
    MAIL_USER="$2"
    shift # past argument
    shift # past value
    ;;
esac
done

# read all dataset keys
DATASET_KEYS=($(singularity exec -B $PROJECT_DIR:/WORK $FMRIPREP_CONTAINER \
  python3 -c """
import os
import json
with open(os.path.join(\"/WORK\", \"code\", \"fmriprep-cmd.json\")) as f: data = json.load(f)
list_keys = \" \".join(data.keys())
print(list_keys)
  """
  ))

# Loop through all datasets
for DATASET in ${DATASET_KEYS[@]}
do
    # read all participant keys
    export SINGULARITYENV_DATASET=$DATASET
    PARTICIPANT_KEYS=($(singularity exec -B $PROJECT_DIR:/WORK $FMRIPREP_CONTAINER \
      python3 -c """
import os
import json
with open(os.path.join(\"/WORK\", \"code\", \"fmriprep-cmd.json\")) as f: data = json.load(f)
list_keys = \" \".join(data[os.environ.get(\"DATASET\")].keys())
print(list_keys)
      """
      ))

    # loop through all participants
    for PARTICIPANT in ${PARTICIPANT_KEYS[@]}
    do
        # slurm cmd
        if [ "$SLURM" = true ] ; then
            mkdir -p /scratch/$USER/.slurm
            read -r -d '' CMD <<- EOM
                sbatch
                --account=$ACCOUNT
                --job-name=fmriprep_${DATASET}-${PARTICIPANT}_%A_%a.job
                --mail-user=$MAIL_USER
                --output=/scratch/%u/.slurm/fmriprep_${DATASET}-${PARTICIPANT}_%A_%a.out
                --error=/scratch/%u/.slurm/fmriprep_${DATASET}-${PARTICIPANT}_%A_%a.err
                ${PROJECT_DIR}/code/slurm/${SLURM_SCRIPT} ${DATASET} ${PARTICIPANT} ${SING_IMG}
EOM
        # raw cmd
        else
            read -r -d '' CMD <<- EOM
                raw singularity command
EOM
        fi
        # print command
        if [ "$SUBMIT" = true ] ; then
            $CMD
        # execute command
        else
            echo $CMD
            echo ""
        fi
    done
done
