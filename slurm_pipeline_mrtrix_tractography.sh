echo "TRACTOGRAPHY pipeline started at: $(date)"


module load FSL/6.0.3
module load ANTs/2.3.1
module load MRtrix3/3.0.3
module load python/3.9
module load FreeSurfer/7.1.1
module load C3D


SUB=$1
IN_DWI_PREP=$2
IN_BVEC=$3
IN_BVAL=$4

TRACKS_NUMBER=$5 
FMT_TRACKS_NUMBER=$(numfmt --to=si $TRACKS_NUMBER)

IN_DWI_MASK=$6
BRAIN=$7
OUT_DIR=$8



cd ${OUT_DIR}


mrconvert ${IN_DWI_PREP} ${SUB}_dwi_den_preproc.mif.gz -fslgrad ${IN_BVEC} ${IN_BVAL}

# # Performs bias field correction. Needs ANTs to be installed in order to use the "ants" option (use "fsl" otherwise)
dwibiascorrect ants ${SUB}_dwi_den_preproc.mif.gz ${SUB}_dwi_den_preproc_unbiased.mif.gz -mask ${IN_DWI_MASK} -bias bias.mif.gz -info

# Estimate multishell multitissue response
dwi2response dhollander ${SUB}_dwi_den_preproc_unbiased.mif.gz ${SUB}_wm.txt ${SUB}_gm.txt ${SUB}_csf.txt -mask ${IN_DWI_MASK} -voxels voxels.mif.gz


# Performs multishell-multitissue constrained spherical deconvolution, using the basis functions estimated above
dwi2fod msmt_csd ${SUB}_dwi_den_preproc_unbiased.mif.gz ${SUB}_wm.txt ${SUB}_wmfod.mif.gz ${SUB}_gm.txt ${SUB}_gmfod.mif.gz ${SUB}_csf.txt ${SUB}_csffod.mif.gz -mask ${IN_DWI_MASK}

# # Now normalize the FODs to enable comparison between subjects
mtnormalise ${SUB}_wmfod.mif.gz ${SUB}_wmfod_norm.mif.gz ${SUB}_csffod.mif.gz ${SUB}_csffod_norm.mif.gz ${SUB}_gmfod.mif.gz ${SUB}_gmfod_norm.mif.gz -mask ${IN_DWI_MASK}

# Extract and compute a mean b0 volume 
dwiextract ${SUB}_dwi_den_preproc_unbiased.mif.gz - -bzero | mrmath - mean ${SUB}_mean_b0_preproc_unbiased.nii.gz -axis 3

# Creates the b0 brain volume from the DWI mask and mean b0
fslmaths ${SUB}_mean_b0_preproc_unbiased.nii.gz -mul ${IN_DWI_MASK} ${SUB}_b0_dwi_brain_prep.nii.gz

# Resample the b0 to the T1W brain
mrgrid ${SUB}_b0_dwi_brain_prep.nii.gz regrid -template ${BRAIN} ${SUB}_dwi_brain_unbiased_rescaled.nii.gz

echo "Coregistering T1 brain to mean b0 brain."
flirt -in  ${BRAIN}  -ref ${SUB}_dwi_brain_unbiased_rescaled.nii.gz -dof 6 -omat ${SUB}_anat2diff_fsl.mat  -out ${SUB}_anat_coreg_to_bzero_6dof_rescaled.nii.gz  # test is to visualize the coregistration

# Create a seed region along the GM/WM boundary
5ttgen fsl  ${SUB}_anat_coreg_to_bzero_6dof_rescaled.nii.gz ${SUB}_5tt_coreg.mif.gz -premasked -nocrop
5tt2gmwmi ${SUB}_5tt_coreg.mif.gz ${SUB}_gmwmSeed_coreg.mif.gz

CUTOFF=0.1
echo "Number of Tracts$(numfmt --to=si $TRACKS_NUMBER) with cutoff $CUTOFF."
tckgen -algorithm IFOD2 -act ${SUB}_5tt_coreg.mif.gz -cutoff $CUTOFF -backtrack -seed_gmwmi ${SUB}_gmwmSeed_coreg.mif.gz -maxlength 250 -select $FMT_TRACKS_NUMBER ${SUB}_wmfod_norm.mif.gz ${SUB}_tracks_${FMT_TRACKS_NUMBER}_coreg_ifod2_msmtcsd_c-${CUTOFF}.tck

# Extract a subset of tracks (here, 200K) for ease of visualization
tckedit ${SUB}_tracks_${FMT_TRACKS_NUMBER}_coreg_ifod2_msmtcsd_c-${CUTOFF}.tck -number 200k ${SUB}_smallerTracks_200K_ifod2_msmtcsd_c-${CUTOFF}.tck 

# Performs SIFT2 algorithm to give a weight to each tract
tcksift2 -act ${SUB}_5tt_coreg.mif.gz -out_mu ${SUB}_sift_mu.txt -out_coeffs ${SUB}_sift_coeffs_ifod2_msmtcsd.txt ${SUB}_tracks_${FMT_TRACKS_NUMBER}_coreg_ifod2_msmtcsd_c-${CUTOFF}.tck ${SUB}_wmfod_norm.mif.gz ${SUB}_sift_${FMT_TRACKS_NUMBER}_coreg_ifod2_msmtcsd_c-${CUTOFF}.txt 

echo "TRACTOGRAPHY pipeline ended at: $(date)"