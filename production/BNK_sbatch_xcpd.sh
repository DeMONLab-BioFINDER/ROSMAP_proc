#!/bin/bash
#SBATCH --job-name=BNKs
#SBATCH --array=648
#SBATCH --exclude=sn20
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=24
#SBATCH --mem=120G
#SBATCH --output=BNKs_logs_xcpd/%x_%A_%a.out
#SBATCH --error=BNKs_logs_xcpd/%x_%A_%a.err

mkdir -p BNKs_logs_xcpd

# Script preambles:
ml purge
module load GCC/12.2.0
module load Anaconda3/2022.05
source /sw/easybuild_milan/software/Anaconda3/2022.05/bin/activate /scale/gr05/home/gabridele/.conda/envs/babs_2801
module load OpenMPI/4.1.4
module load ANTs/2.5.0
module --ignore_cache load "FreeSurfer/7.3.2-centos8_x86_64"

CSV="/scale/gr05/home/gabridele/Documents/BNK_v1-3/BNK_sub_ses.csv"

# If CSV has a header, add +1 to skip it
#LINE=$((SLURM_ARRAY_TASK_ID + 1))

LINE=$SLURM_ARRAY_TASK_ID
sub_ses=$(sed -n "${LINE}p" $CSV | cut -d',' -f1 | tr -d '\r')

echo "SLURM array task: $SLURM_ARRAY_TASK_ID"
echo "Now processing: $sub_ses"

bash BNK_xcpd.sh "$sub_ses"

echo "Finished processing: $sub_ses"
