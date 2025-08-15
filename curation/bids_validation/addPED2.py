import glob
import datalad.api as dl
import os
import json

def addPED(input):
    with open(input, "r", encoding="utf-8") as infile:
        data = json.load(infile)

    if 'PhaseEncodingDirection' not in data:
        print(f"Adding PhaseEncodingDirection to {input}")
        if 'RIRC' in input:
            if 'AP' in input:
                data['PhaseEncodingDirection'] = 'j-'
            elif 'PA' in input:
                data['PhaseEncodingDirection'] = 'j'

        if 'UC' in input:
            data['PhaseEncodingDirection'] = 'j-'

        if 'MG2012' in input:
            data['PhaseEncodingDirection'] = 'j-'
        
    with open(input, "w", encoding="utf-8") as outfile:
        json.dump(data, outfile, indent=4)


def addTRT(input):
    wfs = 18.049
    with open(input, "r", encoding="utf-8") as infile:
        data = json.load(infile)

    if 'TotalReadoutTime' not in data:
        print(f"Adding TotalReadoutTime to {input}")

        if 'UC' in input:
            calculate_TotalReadoutTime(data, wfs, 'UC')

        if 'MG2012' in input:
            calculate_TotalReadoutTime(data, wfs, 'MG')

    with open(input, "w", encoding="utf-8") as outfile:
        json.dump(data, outfile, indent=4)

def calculate_TotalReadoutTime(in_meta,wfs,scanner):
    '''
    This is for a philips EPI sequence.
    See https://support.brainvoyager.com/brainvoyager/functional-analysis-preparation/29-pre-processing/78-epi-distortion-correction-echo-spacing-and-bandwidth
    and https://github.com/PennBBL/qsiprep/blob/master/qsiprep/interfaces/fmap.py#L469
    '''
    if 'MagneticFieldStrength' in in_meta:
        fstrength = in_meta['MagneticFieldStrength']
    else:
        if scanner == 'BNK':
            fstrength = 1.5
        elif scanner in ['UC','MG']:
            fstrength = 3
        else:
            raise IOError('field strength indetectable')
    wfd_ppm = 3.4  # water-fat diff in ppm
    g_ratio_mhz_t = 42.57  # gyromagnetic ratio for proton (1H) in MHz/T
    wfs_hz = fstrength * wfd_ppm * g_ratio_mhz_t
    
    trt = wfs / wfs_hz
    in_meta['WaterFatShift'] = wfs
    in_meta['TotalReadoutTime'] = trt
    
    return in_meta

def main():

    paths_txt = "/home/gabridele/backup/ROSMAP_proc/raw/code/curation/validation/fmaplessfunc_paths.txt"

    # --- READ PATHS AND ADD *.json ---
    with open(paths_txt, "r", encoding="utf-8") as infile:
        paths = [line.strip() for line in infile if line.strip()]

    json_paths = []
    for path in paths:
        json_paths.extend(glob.glob(path + "*.json"))
    for i, path in enumerate(json_paths):
        print(f"Path {i+1}: {path}")
        dl.unlock(path)
        addPED(path)
        addTRT(path)
    # # --- SAVE OUTPUT ---
    # with open(output_txt, "w", encoding="utf-8") as outfile:
    #     outfile.write("\n".join(json_paths))

    # print(f"Done! Wrote {len(json_paths)} JSON search paths to {output_txt}")

if __name__ == "__main__":
    main()
