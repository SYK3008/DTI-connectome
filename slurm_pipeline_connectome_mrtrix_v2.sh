#!/bin/bash

echo "CONNECTOME pipeline started at: $(date)"


module load python/3.9
module load FSL
module load MRtrix3/3.0.2

SUB=$1
TRACKS=$2
SIFT=$3
TT5_FSL=$4
BRAIN=$5
PARC_DIR=$6
PARC_LIST=$7
WARPFIELD=$8
T1_TO_B0_MAT=$9
OUT_DIR=${10}
CLEANUP=${11}

SCRIPT_PATH=$(dirname $(realpath $0))
warp_mni152fsl_to_t1=${SCRIPT_PATH}/warp_mni152fsl_to_t1.sh
transfer_parcellation=${SCRIPT_PATH}/transfer_parcellation_v2.sh

cd $OUT_DIR
echo "Going moving to ${OUR_DIR}"

echo "Inverting UKB warp from T1->MNI to MNI->T1."
printf "Base warpfield : ${WARPFIELD}
T1 brain : ${BRAIN}
Output warpfield : ${SUB}_MNI152_to_T1_warpfield.nii.gz"

invwarp -w ${WARPFIELD} -r ${BRAIN} -o ${SUB}_MNI152_to_T1_warpfield.nii.gz -v
echo "Done..."

for PARC in $PARC_LIST; do
    echo "====================================================="
    echo "Current parcellation : $PARC"
    PARC=$PARC_DIR/$PARC
    parc_basename=$(basename ${PARC%.nii.gz})
    # echo $parc_basename
    coreg_parcellation=${SUB}_${parc_basename}_coreg.nii.gz
    # echo $coreg_parcellation

    eval bash ${transfer_parcellation} $SUB $BRAIN $PARC $TT5_FSL $PWD/${SUB}_MNI152_to_T1_warpfield.nii.gz ${T1_TO_B0_MAT} $PWD 1 # 1 means no cleanup at the end

    cd $OUT_DIR
    tck2connectome -symmetric -zero_diagonal -assignment_radial_search 3 -tck_weights_in \
        ${SIFT} \
        ${TRACKS} \
        ${SUB}_$(basename ${PARC}) \
        ${SUB}_connectome_${parc_basename}.csv \
        -out_assignment ${SUB}_tck-assignment_${parc_basename}.csv \
        -force
        
done

if [[ $CLEANUP == 1 ]]; then
    rm -r $OUT_DIR/temp_parcellations
fi

echo "CONNECTOME pipeline ended at: $(date)"



