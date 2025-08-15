#!/bin/bash

SOURCE1="sub-41635233/ses-1"
SOURCE2="sub-06798423/ses-0/func"
SOURCE3="sub-06798423/ses-0/fmap"
SOURCE4="sub-06172311/ses-0/func"
SOURCE5="sub-06172311/ses-0/fmap"
SOURCE6="sub-55536840" ## missing bval and bvec files for dwi. only got one session and no func. so quarantining everything
DESTINATION="../../quarantine_ROSMAP/"

for SOURCE in "$SOURCE1" "$SOURCE2" "$SOURCE3" "$SOURCE4" "$SOURCE5" "$SOURCE6"; do
    if [ -d "$SOURCE" ]; then
        echo "Copying $SOURCE to $DESTINATION"
        rsync -avr --copy-links "$SOURCE" "$DESTINATION"
    else
        echo "Source directory $SOURCE does not exist."
    fi
done

for SOURCE in "$SOURCE1" "$SOURCE2" "$SOURCE3" "$SOURCE4" "$SOURCE5" "$SOURCE6"; do
    if [ -d "$SOURCE" ]; then
        datalad remove "$SOURCE" --reckless kill
    fi
done
find "." -type l -name "*Sag3DMEGREND_T2starw*" > "ME_toremove.txt"

find "." -type l -name "*Sag3DMEGRE_T2starw*" >> "ME_toremove.txt"

while IFS= read -r line; do
    if [ -L "$line" ]; then
        echo "Removing $line using datalad"
        datalad remove "$line" --reckless kill
    else
        echo "$line is not a valid symlink."
    fi
done < "ME_toremove.txt"
