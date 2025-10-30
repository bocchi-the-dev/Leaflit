#
# Copyright (C) 2025 ぼっち <ayumi.aiko@outlook.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#!/bin/bash

# functions:

function abort() {
    echo "$1" >&2;
    exit 1;
}

function downloadRequestedFile() {
    local link="$1"
    local save_path="$2"
    [[ -z "$link" || -z "$save_path" ]] && return 1
    if [ "$1" == "--skip" ]; then
        link="$2"
        save_path="$3"
        aria2c -x 8 -s 8 -o "${save_path}" "${link}" &>>./src/log && return 0
        return 1
    else
        for ((tries = 1; tries <= 4; tries++)); do
            echo "📥 Trying to download requested file | Attempt: $tries" &>>./src/log
            if aria2c -x 8 -s 8 -o "${save_path}" "${link}" &>>./src/log; then
                echo "✅ Successfully downloaded file after $tries attempt(s)" &>>./src/log
                return 0
            fi
            echo "❌ Failed to download the file | Attempt: $tries" &>>./src/log
        done
        echo "⚠️ Failed to download the file after $((tries - 1)) attempts." &>>./src/log
        return 1;
    fi
}

function getLatestReleaseFromGithub() {
    local githubReleaseURL="$1"
    [ -z "$githubReleaseURL" ] && abort "Error: No GitHub release URL provided."
    local latestRelease=$(curl -s "$githubReleaseURL" | grep -oP '"browser_download_url": "\K[^"]+')
    [ -z "$latestRelease" ] && abort "Error: Could not retrieve the latest release URL."
    echo "$latestRelease"
}

function changeYAMLValues() {
    local key="$1"
    local value="$2"
    local file="$3"
    # do checks and put ts shyt in log
    [[ -z "$file" || ! -f "$file" ]] && abort "Error: No file specified or the file is not found."
    # ok lets go
    grep -Eq "^[[:space:]]*${key}:" "$file" && sed -i -E "s|(^[[:space:]]*${key}:)[[:space:]]*.*|\1 ${value}|" "$file"
}

function buildAndSignThePackage() {
    local extracted_dir_path="$1"
    local app_path="$2"
    local skipSign="$3"
    local apkFileName
    local signed_apk
    local apk_file
    local sign_output
    # Ensure valid directory with apktool.yml
    [[ ! -d "$extracted_dir_path" || ! -f "$extracted_dir_path/apktool.yml" ]] && abort "Invalid Apkfile path: $extracted_dir_path"
    # Extract APK filename
    apkFileName=$(grep "apkFileName" "$extracted_dir_path/apktool.yml" | cut -d ':' -f 2 | tr -d ' "')
    apk_file="${extracted_dir_path}/dist/${apkFileName}"
    # Modify apktool.yml.
    changeYAMLValues "targetSdkVersion" "${androidSDKVersion}" "${extracted_dir_path}/apktool.yml"
    # Build APK
    java -jar ./src/bin/apktool.jar build "$extracted_dir_path" &>/dev/null || abort "Apktool build failed for $extracted_dir_path"
    [[ ! -f "$apk_file" ]] && abort "No APK found in $extracted_dir_path/dist/"
    # Handle default value for skipSign
    [[ -z "$skipSign" ]] && skipSign=false
    # Sign APK
    if [[ "$skipSign" == "false" ]]; then
        if [[ -f "$MY_KEYSTORE_PATH" && -n "$MY_KEYSTORE_ALIAS" && -n "$MY_KEYSTORE_PASSWORD" && -n "$MY_KEYSTORE_ALIAS_KEY_PASSWORD" ]]; then
            sign_output=$(java -jar ./src/bin/signer.jar \
                --apk "$apk_file" \
                --ks "$MY_KEYSTORE_PATH" \
                --ksAlias "$MY_KEYSTORE_ALIAS" \
                --ksPass "$MY_KEYSTORE_PASSWORD" \
                --ksKeyPass "$MY_KEYSTORE_ALIAS_KEY_PASSWORD")
        else
            sign_output=$(java -jar ./src/bin/signer.jar --apk "$apk_file")
        fi
        signed_apk=$(echo "$sign_output" \
            | grep 'file:.*-aligned-.*\.apk' \
            | sed -n '2p' \
            | grep -oP 'file: \K.*?-aligned-.*?\.apk' \
            | sed 's|.*\(src/.*\)|\1|')
        if [[ ! -f "$signed_apk" ]]; then
            signed_apk=$(echo "$sign_output" \
                | grep 'file:.*-aligned-.*\.apk' \
                | sed -n '1p' \
                | grep -oP 'file: \K.*?-aligned-.*?\.apk' \
                | sed 's|.*\(src/.*\)|\1|')
        fi
        [[ ! -f "$signed_apk" ]] && abort "No signed APK found from signing output."
    else
        signed_apk="$apk_file"
    fi
    mv "$signed_apk" "$app_path/" || abort "Failed to move APK to target location: $app_path"
    rm -rf "$extracted_dir_path/build" "$extracted_dir_path/dist/" "$extracted_dir_path/original/"
}
# compatibility? it just works all on all oneui versions
# tested on oneui 3.1 btw!

# gbl scp vars:
maxGIFLoadables=19 # 0..19
gifIndexSuffix="preload_gif_"
overlayGIFIndexPath="./src/app/customGIFLoader/res/raw"
gifIndex=0
dpts=(
    "https://api.github.com/repos/iBotPeaches/Apktool/releases/latest"
    "https://api.github.com/repos/patrickfav/uber-apk-signer/releases/latest"
)
dptsPath=(
    "./src/bin/apktool.jar"
    "./src/bin/signer.jar"
)
dptsNames=(
    "Apktool"
    "UberAPKSigner"
)

# anyways:
[ ! -f "./src/app/customGIFLoader/AndroidManifest.xml" ] && abort "- Leaflit overlay not found, exiting.";

# dpts: sys:
for j in aria2c java curl; do
    command -v ${j} &>/dev/null || abort "Error: ${j} is not installed. Please install ${j} and try again."
done

# chck dpts:
mkdir -p ./src/bin/
for (( i = 0; i < 2; i++ )); do
    if [ ! -f "${dptsPath[${i}]}" ]; then
        if downloadRequestedFile "${dpts[${i}]}" "${dptsPath[${i}]}"; then
            echo "- ${dptsNames[${i}]} downloaded successfully.";
        else
            abort "Error: Failed to download ${dptsNames[${i}]}."s
        fi
    fi
done

if [ "$1" == "--auto" ]; then
    source "./src/leaflit.conf"
    # failed to load the dawn config file.
    [[ -z "${gifPaths[@]}" ]] && abort "Error: No GIF paths found in leaflit.conf"
    for (( i=0; i<=$maxGIFIndex; i++ )); do
        echo "- File found, proceeding.";
        cp "${gifPaths[${i}]}" "${overlayGIFIndexPath}/${gifIndexSuffix}${gifIndex}.gif"
        echo "- Copied ${gifPaths[${i}]} to ${overlayGIFIndexPath}/${gifIndexSuffix}${gifIndex}.gif";
        (( gifIndex++ ))
    done
else
    # just do whatever it takes man!
    androidSDKVersion=28
    skipAPKSign=false
    echo "- Leaflit overlay found, proceeding.";
    printf "How many GIFs do you want to load? (0-%s): " "$maxGIFLoadables"
    read userInput
    if ! [[ "$userInput" =~ ^[0-9]+$ ]] ; then
        abort "Error: Not a number"
    elif [ "$userInput" -lt 1 ] || [ "$userInput" -gt "$maxGIFLoadables" ]; then
        abort "Error: Number out of range (1-$maxGIFLoadables)"
    elif [ -z "$userInput" ]; then
        abort "Error: No input"
    else
        echo "- User input accepted, proceeding.";
        for (( i=0; i<=$userInput; i++ )); do
            printf "Enter the path for GIF #%s: " "$i"
            read gifPath
            if [ ! -f "$gifPath" ]; then
                abort "Error: File not found"
            else
                echo "- File found, proceeding.";
                cp "$gifPath" "${overlayGIFIndexPath}/${gifIndexSuffix}${gifIndex}.gif"
                echo "- Copied $gifPath to ${overlayGIFIndexPath}/${gifIndexSuffix}${gifIndex}.gif";
                (( gifIndex++ ))
            fi
        done
        echo "- All done! You can now build the overlay with your preferred method.";
    fi
fi

# build the overlay. testKEYSIGNED!
echo "- The overlay will get signed using testkey from Uber Apk Signer, please use your own key!"
buildAndSignThePackage "./src/app/customGIFLoader/" "./src" "$skipAPKSign"
echo "- Please copy the tsukika.misc.aodservice.customUserGIFS.autogenerated__rro.apk from src/ to your device and put it inside /product or /vendor overlay!"
echo "Thank me later :)"

## https://tenor.com/view/anime-vtuber-cute-anime-girl-excited-anime-girl-excited-gif-gif-5278977548408975334
