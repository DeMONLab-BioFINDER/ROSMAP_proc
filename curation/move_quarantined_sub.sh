#!/bin/bash

SOURCE_DIR="/home/gabridele/backup/ROSMAP_proc/raw/sub-41635233/ses-1/dwi"

rsync -avr --copy-links "$SOURCE_DIR" .