import os
import json
import datalad.api as dl
import glob
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

JSON_TEMPLATE = {
    "Modality": "MR",
    "MagneticFieldStrength": 3,
    "ImagingFrequency": 127.791,
    "Manufacturer": "Philips",
    "ManufacturersModelName": "Achieva",
    "InstitutionName": "University_of_Chicago",
    "InstitutionalDepartmentName": "MRI",
    "DeviceSerialNumber": "24076",
    "StationName": "PHILIPS-F398EB2",
    "BodyPartExamined": "BRAIN",
    "PatientPosition": "HFS",
    "SoftwareVersions": "3.2.1_3.2.1.0",
    "MRAcquisitionType": "2D",
    "SeriesDescription": "T2_map_5_echoes",
    "ProtocolName": "WIP_T2_map_5_echoes_SENSE",
    "ScanningSequence": "RM",
    "SequenceVariant": "SK",
    "ImageType": ["ORIGINAL", "PRIMARY", "T2", "MAP", "T2", "UNSPECIFIED"],
    "SeriesNumber": 701,
    "AcquisitionNumber": 7,
    "SliceThickness": 3,
    "SpacingBetweenSlices": 3,
    "RepetitionTime": 6.3848,
    "FlipAngle": 90,
    "CoilString": "SENSE-Head-8",
    "PartialFourier": 0.0284091,
    "PercentPhaseFOV": 79.6875,
    "EchoTrainLength": 5,
    "PhaseEncodingSteps": 176,
    "AcquisitionMatrixPE": 176,
    "ReconMatrixPE": 512,
    "PixelBandwidth": 115.083,
    "PhaseEncodingAxis": "i",
    "ImageOrientationPatientDICOM": [
        1,
        0,
        0,
        0,
        1,
        0
    ],
    "InPlanePhaseEncodingDirectionDICOM": "ROW",
    "ConversionSoftware": "dcm2niix",
    "ConversionSoftwareVersion": "v1.0.20190902"
}


def rename_scans():
    # acq had peculiar name, so it carried over to raw. fixing that
    anat_dir = Path(os.getcwd()) / 'sub-78014537' / 'ses-0' / 'anat'
    nii_files = sorted(anat_dir.glob('*acq-UC201202211311260078014537*_T2w.nii.gz'))

    renamed_files = []
    for nii_file in nii_files:
        new_name = str(nii_file).replace("acq-UC201202211311260078014537", "acq-UC20120221")
        new_path = Path(new_name)
        if nii_file != new_path:
            nii_file.rename(new_path)
        renamed_files.append(new_path)
    return renamed_files


def create_adhoc_json(nii_files):
    # and those acqs for sub-78014537 didnt have jsons. creating them now
    for nii_file in nii_files:
        json_path = nii_file.with_suffix('').with_suffix('.json')  # Remove .gz and then .nii
        json_data = JSON_TEMPLATE.copy()

        with open(json_path, 'w') as f:
            json.dump(json_data, f, indent=4)


def adjust_echotimes(nii_file):
    # now adjusting echo times of all ME T2s of UC20120221
    with open(nii_file, 'r') as f:
        data = json.load(f)

    if 'echo-1' in nii_file:
        data['EchoNumber'] = 1
        data['EchoTime'] = 0.02
    elif 'echo-2' in nii_file:
        data['EchoNumber'] = 2
        data['EchoTime'] = 0.04
    elif 'echo-3' in nii_file:
        data['EchoNumber'] = 3
        data['EchoTime'] = 0.06
    elif 'echo-4' in nii_file:
        data['EchoNumber'] = 4
        data['EchoTime'] = 0.08
    elif 'echo-5' in nii_file:
        data['EchoNumber'] = 5
        data['EchoTime'] = 0.1

    with open(nii_file, 'w') as f:
        json.dump(data, f, indent=4)


def main():
    
    files = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'anat', '*UC20120221*T2w.json')))
    for ii, file in enumerate(files):
        dl.unlock(file)
        
    print("Starting renaming of sub-78014537...")
    renamed_files = rename_scans()
    print("Renaming complete.")

    print("Creating JSON files...")
    print(renamed_files)
    create_adhoc_json(renamed_files)

    print("JSON creation complete.")
        
    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(adjust_echotimes, files)


if __name__ == "__main__":
    main()
