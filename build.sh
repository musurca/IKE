#!/bin/bash
# IKE - BUILD SCRIPT

# The final path of the compiled, minified file
IKE_BUILD_PATH="./release"
IKE_RELEASE_NAME="ike_min.lua"
IKE_DEBUG_NAME="ike_debug.lua"

# The path to the source files
IKE_SRC_PATH="./src"

# Edit these lines to add new source files to the build.
# Files are added in the order that they are listed.
IKE_LOADER_INCLUDE=("00_localize.lua" "01_md5.lua" "02_util.lua" "03_pbem.lua")
IKE_WIZARD_INCLUDE=("04_wizard.lua")

# -------DO NOT EDIT BELOW THIS LINE--------
IKE_STARTTURN="xx_startturn.lua"
IKE_LOADERINIT="xx_loader.lua"
IKE_COMMENTS="xx_comments.lua"
IKE_FINALINIT="xx_finalinit.lua"

if [ "$1" = "debug" ]; then
    IKE_FINAL_PATH="$IKE_BUILD_PATH/$IKE_DEBUG_NAME"
else
    IKE_FINAL_PATH="$IKE_BUILD_PATH/$IKE_RELEASE_NAME"
fi

mkdir tmp
if [ -d $IKE_BUILD_PATH ]; then
    if [ -f $IKE_FINAL_PATH ]; then
        rm $IKE_FINAL_PATH
    fi
else
    mkdir $IKE_BUILD_PATH
fi

# build IKE loader
for f in ${IKE_LOADER_INCLUDE[@]}; do
    cat $IKE_SRC_PATH/$f >> tmp/header.lua
done
cat tmp/header.lua > tmp/loader.lua
cat $IKE_SRC_PATH/$IKE_STARTTURN >> tmp/loader.lua
if [ "$1" = "debug" ]; then
    cat tmp/loader.lua > tmp/loader_min.lua
else
    luamin -f tmp/loader.lua > tmp/loader_min.lua
fi

# build the escape string for loading
python3 escape.py tmp/loader_min.lua tmp/loader_escaped.txt

# build IKE wizard
for f in ${IKE_WIZARD_INCLUDE[@]}; do
    cat $IKE_SRC_PATH/$f >> tmp/header.lua
done
cat $IKE_SRC_PATH/$IKE_LOADERINIT >> tmp/header.lua
cat tmp/loader_escaped.txt >> tmp/header.lua
cat $IKE_SRC_PATH/$IKE_FINALINIT >> tmp/header.lua

# combine into final compiled minified lua
if [ "$1" = "debug" ]; then
    cat tmp/header.lua > tmp/final_min.lua
else
    luamin -f tmp/header.lua > tmp/final_min.lua
fi

cat $IKE_SRC_PATH/$IKE_COMMENTS > $IKE_FINAL_PATH
cat tmp/final_min.lua >> $IKE_FINAL_PATH

echo "Success! IKE has been compiled to $IKE_FINAL_PATH."

# clear the temporary directory
rm -rf tmp

