#!bin/bash 
module load python/3.9

# SCRIPT_PATH=$(cd $(dirname “${BASH_SOURCE:-$0}”) && pwd) # Not sure what this is for - get the home directory?

## Get all the subjects id that are both in the DWI and T1W folders
#sub_list=$(python $SCRIPT_PATH/construct_sub_list.py $input_dir/dwi/ $input_dir/T1)
#echo $sub_list 
## Uncomment following line if you want to run on specific subjects and replace the base ID.
# sub_list="1007409"

# This is the only bit that uses Python in the pipeline - could be removed to reduce dependencies?
# Arguably we can just feed a list of IDs - array jobs will fail if images not available

# Best to start from the bulk file, which is used to download the dwi images
# Split it into sub files of 500 rows
split -l 500 $input_dir/dwi/ukb42624_dwi.bulk $input_dir/dwi/ukb42624_dwi.bulk.batch -da 2

# srun -p normal -N 1 -c 1 --mem=5G --time=0-03:00:00 --pty bash



# Path to your script directory
SCRIPT_PATH="path/to/the/pipeline/directory"
cd ${SCRIPT_PATH}

# PIPELINE INPUTS 
# Where UKB data is located
input_dir="path/to/the/input/UKB/directory"

# Relative filepath of required data for each subject (only modify if you encounter a problem)
dwi_sub_dir=dMRI/dMRI/data_ud.nii.gz
bvec_sub_dir=dMRI/dMRI/bvecs
bval_sub_dir=dMRI/dMRI/bvals
dwi_mask_sub_dir=dMRI/dMRI.bedpostX/nodif_brain_mask.nii.gz
brain_sub_dir=T1/T1_brain.nii.gz
dwi_brain=dMRI/dMRI.bedpostX/nodif_brain.nii.gz

# OUTPUT DIRECTORIES
mrtrix_dir="path/to/the/output/directory"
# making log dir
mkdir -p ${mrtrix_dir}/logs

# Number of tracts
number_tracks=1000000
hu_nb_tracks=$(numfmt --to=si $number_tracks)


# PARCELLATION DIRECTORIES
parc_dir=${SCRIPT_PATH}/parcellations/
parc_list="aal_rmap_s1dild.nii.gz         gordon333dil_rmap_s1dild.nii.gz      lausanne2008_scale33_s1dild.nii.gz   schaefer100-yeo17_rmap_s1dild.nii.gz  schaefer600-yeo17_rmap_s1dild.nii.gz
aicha_rmap_s1dild.nii.gz       hcp-mmp-b_rmap_s1dild.nii.gz         lausanne2008_scale500_s1dild.nii.gz  schaefer200-yeo17_rmap_s1dild.nii.gz  schaefer800-yeo17_rmap_s1dild.nii.gz
arslan_rmap_s1dild.nii.gz      ica_rmap_s1dild.nii.gz               lausanne2008_scale60_s1dild.nii.gz   schaefer300-yeo17_rmap_s1dild.nii.gz  shen268cort_rmap_s1dild.nii.gz
baldassano_rmap_s1dild.nii.gz  lausanne2008_scale125_s1dild.nii.gz  nspn500_rmap_s1dild.nii.gz           schaefer400-yeo17_rmap_s1dild.nii.gz  shen_rmap_s1dild.nii.gz
fan_rmap_s1dild.nii.gz         lausanne2008_scale250_s1dild.nii.gz  power_rmap_s1dild.nii.gz             schaefer500-yeo17_rmap_s1dild.nii.gz  yeo17dil_rmap_s1dild.nii.gz"

# BATCH
batch=00

${SCRIPT_PATH}/qsubshcom "
sub_bulk=\$(sed -n \"\${TASK_ID}{p;q}\" $input_dir/dwi/ukb42624_dwi.bulk.batch$batch) |;
sub=\$(echo \${sub_bulk} | cut  -d \" \" -f 1) |;
echo \${TASK_ID} |;
echo \${sub} |;
mkdir -p ${mrtrix_dir}/\${sub}/mrtrix |;
connectome_outdir=${mrtrix_dir}/\${sub}/connectome_${hu_nb_tracks} |;
mkdir -p \${connectome_outdir} |;
tck_in=mrtrix/\${sub}_tracks_${hu_nb_tracks}_coreg_ifod2_msmtcsd_c-0.1.tck |;
sift_in=mrtrix/\${sub}_sift_${hu_nb_tracks}_coreg_ifod2_msmtcsd_c-0.1.txt |;
tt5_fsl=mrtrix/\${sub}_5tt_coreg.mif.gz |;
${SCRIPT_PATH}/full_pipeline.sh \${sub} ${dwi_sub_dir} ${bvec_sub_dir} ${bval_sub_dir} ${number_tracks} ${dwi_mask_sub_dir} ${brain_sub_dir} ${mrtrix_dir}/\${sub}/mrtrix ${mrtrix_dir}/\${sub}/\${tck_in} ${mrtrix_dir}/\${sub}/\${sift_in} ${mrtrix_dir}/\${sub}/\${tt5_fsl} ${parc_dir} \"${parc_list}\" \${connectome_outdir} ${input_dir} ${SCRIPT_PATH} |;
" 1 4G UKB_net_${hu_nb_tracks}_batch${batch} 10:00:00 "-array=1-5"

