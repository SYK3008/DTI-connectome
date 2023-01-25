#!/bin/bash

echo "PARCELLATION TRANSFER pipeline started at: $(date)"


module load FSL
module load MRtrix3 


SUB=$1
T1_brain=$2
MNI_PARC=$3
TT5_FSL=$4
WARPFILED=$5
T1_TO_B0_MAT=$6
OUT_DIR=$7
NOCLEANUP=$8

parc_basename=$(basename ${MNI_PARC%.nii.gz})

mkdir $OUT_DIR/temp_parcellations 
cd $OUT_DIR/temp_parcellations

echo "_______________________________________"
echo "Applying warpfield to register FSL's MNI152 parcellation to subject's space T1"
applywarp -i ${MNI_PARC} -o ${parc_basename}_subspace.nii.gz -r ${T1_brain} -w ${WARPFILED} --postmat=${T1_TO_B0_MAT} --interp=nn
 
echo "_______________________________________"
echo "Creating a GM + subcortical areas 3D volume from 5tt file"
mrconvert ${TT5_FSL} -coord 3 0,1 - | mrmath - sum gm_sgm_5tt.nii.gz -axis 3 -force

echo "_______________________________________"
echo "Thresholding (0.5) and binarizing extracted 5tt 3D volume"
fslmaths gm_sgm_5tt.nii.gz -thr 0.5 -bin gm_sgm_mask.nii.gz
 
echo "_______________________________________"
echo "Multiplying binary mask and registered parcellation"
fslmaths ${parc_basename}_subspace.nii.gz -kernel sphere 2 -dilD -mul gm_sgm_mask.nii.gz -kernel sphere 1 -dilD ${parc_basename}_subspace_masked.nii.gz -odt int

echo "_______________________________________"
echo "Moving final parcellation"
mv ${parc_basename}_subspace_masked.nii.gz ${OUT_DIR}/${SUB}_$(basename ${MNI_PARC})

if [[ ! -z $NOCLEANUP ]]
then
    echo "Cleaning up temporary directory : ${OUT_DIR}/temp_parcellations"
    rm -r ${OUT_DIR}/temp_parcellations
fi

echo "PARCELLATION TRANSFER pipeline ended at: $(date)"









