#!/bin/bash

SUB=$1
IN_DWI_PREP=$2
IN_BVEC=$3
IN_BVAL=$4

TRACKS_NUMBER=$5 
FMT_TRACKS_NUMBER=$(numfmt --to=si $TRACKS_NUMBER)

IN_DWI_MASK=$6
BRAIN=$7
OUT_DIR_TCK=$8


TRACKS=$9
SIFT=${10}
TT5_FSL=${11}
PARC_DIR=${12}
PARC_LIST=${13}
OUT_DIR_NET=${14}

DATA_DIR=${15}

SCRIPT_PATH=${16}

cd ${SCRIPT_PATH}


printf "\n ========== DECOMPRESSION ==========\n"


tmp_dir=${OUT_DIR_TCK}/rawdata/

mkdir -p ${tmp_dir}

echo $tmp_dir

eval unzip ${DATA_DIR}/dwi/${SUB}_20250_2_0.zip -d ${tmp_dir}
eval unzip ${DATA_DIR}/T1/${SUB}_20252_2_0.zip -d ${tmp_dir}

IN_DWI_PREP=${tmp_dir}/${IN_DWI_PREP}
IN_BVEC=${tmp_dir}/${IN_BVEC}
IN_BVAL=${tmp_dir}/${IN_BVAL}

IN_DWI_MASK=${tmp_dir}/${IN_DWI_MASK}
BRAIN=${tmp_dir}/${BRAIN}

WARPFIELD=${tmp_dir}/T1/transforms/T1_to_MNI_warp_coef.nii.gz
T1_TO_B0_MAT=${OUT_DIR_TCK}/${SUB}_anat2diff_fsl.mat

printf "\n ============================\n"


printf "\n ========== INPUTS ==========\n
    - subject : $SUB
    - dwi : $IN_DWI_PREP
    - bvec : $IN_BVEC
    - bval : $IN_BVAL
    - nb tracts : $TRACKS_NUMBER
    - dwi mask : $IN_DWI_MASK
    - T1 brain : $BRAIN
    - tarcts output dir : $OUT_DIR_TCK
    - tracts file : $TRACKS
    - sift file : $SIFT
    - 5tt file : $TT5_FSL
    - parcellations dir : $PARC_DIR
    - parcellation list : $PARC_LIST
    - MNI152 coregistration warpfield : $WARPFIELD 
    - networks output dir : $OUT_DIR_NET
\n ============================\n"



printf "\n ========== STARTING TRACTOGRAPHY CONSTRUCTION ==========\n"

bash ${SCRIPT_PATH}/slurm_pipeline_mrtrix_tractography.sh \
    $SUB \
    $IN_DWI_PREP \
    $IN_BVEC \
    $IN_BVAL \
    $TRACKS_NUMBER \
    $IN_DWI_MASK \
    $BRAIN \
    $OUT_DIR_TCK \

printf "\n ========== TRACTOGRAPHY FINISHED ==========\n"

printf "\n ========== STARTING CONNECTOME CONSTRUCTION ==========\n"

echo 

if ([ -f $TRACKS ] && [ -f $SIFT ] && [ -f $TT5_FSL ] && [ -f $BRAIN ] && [ -d $PARC_DIR ] && [ -f $WARPFIELD ] && [ -f $T1_TO_B0_MAT ])
    then
        bash ${SCRIPT_PATH}/slurm_pipeline_connectome_mrtrix_v2.sh \
        $SUB \
        $TRACKS \
        $SIFT \
        $TT5_FSL \
        $BRAIN \
        $PARC_DIR \
        "$PARC_LIST" \
        $WARPFIELD \
        $T1_TO_B0_MAT \
        $OUT_DIR_NET \
        1
    else
        echo "Some input files/directories don't exist"
        exit 1
    fi
printf "\n ========== CONNECTOME CONSTRUCTION FINISHED ==========\n"

rm -r $OUT_DIR_TCK