#!/bin/bash
# WARNING: this script REWRITES ".vscode/settings.json" FILE.
# All previos settings will be REMOVED in the file ".vscode/settings.json"

includes=""

function check_file_exists() {
  if [ ! -f "$1" ]; then
    echo "File $1 doesn't exist! Build project first \"idf.py build\", after use this script" >&2
    exit 1
  fi
}

function confirm() {
  while true; do
    read -p "$1 (y/Y): " answer
    case "$answer" in
      [yY])
        break
        ;;
    esac
  done
}

function find_includes() {
  local dir="$1"

  if [ ! -d "$dir" ]; then
    echo "Error: $dir is not directory"
    return 1
  fi

  for item in "$dir"/*; do
    if [ -d "$item" ]; then
      if [[ "$item" =~ .*/include$ ]]; then
        includes="$includes:$item"
      fi

      find_includes "$item"
    fi
  done
}

function get_config_value() {
  local file="$1"
  local key="$2"

  if [ ! -f "$file" ]; then
    echo "Error: the file $file doesn't exist"
    return 1
  fi

  value=$(grep "^$key=" "$file" | cut -d'=' -f2)
  if [ -z "$value" ]; then
    echo "Error: the key $key doesn't find in the file $file"
    return 1
  fi

  # Remove a symbols "
  value=${value%\"}
  value=${value#\"}

  echo "$value"
}

function get_target_includes() {
    INCLUDES="$1"
    TARGET_ESP="$2"

    ESP32XX_INCLUDE="esp32xx"

    # filter target dependents includes
    dependent_includes=""

    IFS=':' read -r -a INCLUDES <<< "$INCLUDES"
    for item in "${INCLUDES[@]}"; do
    if [[ "$item" =~ .*/$TARGET_ESP.* ]]; then
        dependent_includes="$dependent_includes:$item"
    fi
    done

    # Make include list only for target MCU
    target_includes=""
    IFS=':' read -r -a dependent_includes <<< "$dependent_includes"
    for item in "${dependent_includes[@]}"; do
    if [[ "$item" =~ .*/$TARGET_ESP/.* ]]; then
        target_includes="$target_includes:$item"
    fi
    done

    # Add to the target includes common includes(esp32XX)
    for item in "${dependent_includes[@]}"; do
    if [[ "$item" =~ .*/$ESP32XX_INCLUDE/.* ]]; then
        target_includes="$target_includes:$item"
    fi
    done

    # Remove first ":"
    target_includes=${target_includes:1}

    echo $target_includes
}

function get_filtered_includes() {
  local includes="$1"
  local target="$2"
  local exclude_word="esp32"

  # Get path without "esp32"
  IFS=':' read -r -a includes_for_exclude <<< "$includes"
  filtered_includes=""
  for item in "${includes_for_exclude[@]}"; do
    if [[ ! "$item" =~ .*$exclude_word.* ]]; then
      filtered_includes="$filtered_includes:$item"
    fi
  done

  # Remove first ":"
  filtered_includes=${filtered_includes:1}

  # Get paths, for targeted MCU
  target_includes=$(get_target_includes "$includes" "$target")

  # Merge paths
  combined_includes="$filtered_includes:$target_includes"

  # Remove first ":"
  combined_includes=${combined_includes:1}

  echo "$combined_includes"
}

check_file_exists "build/config/sdkconfig.h"

if [ "$1" = "-y" ]; then
  echo -n
else
  confirm "WARNING: this script REWRITES ".vscode/settings.json" FILE. Continue?"
fi


CONFIG_FILE="sdkconfig"
MCU_TARGET="CONFIG_IDF_TARGET"
ARCH_TARGET="CONFIG_IDF_TARGET_ARCH"

# Get all includes
find_includes $IDF_PATH/components

# Add include path for Xtensa arch
arch=$(get_config_value $CONFIG_FILE $ARCH_TARGET)
if [[ $arch == "xtensa" ]]; then
  includes="$includes:$IDF_PATH/components/xtensa/deprecated_include"
fi

includes="$includes:$IDF_PATH/components/freertos/config/include/freertos/"
includes="$includes:`pwd`/build/config/sdkconfig.h"

# Get target MCU name
target=$(get_config_value $CONFIG_FILE $MCU_TARGET)

# Get filtered include path list
combined_includes=$(get_filtered_includes "$includes" "$target")

# For debuging
if [[ 1 -eq 0 ]]; then
  echo "Filtered includes:"
  IFS=':' read -r -a items <<< "$combined_includes"
  for item in "${items[@]}"; do
    echo "$item"
  done
fi

# Make JSON
json="{
  \"C_Cpp.default.includePath\": [

"
IFS=':' read -r -a items <<< "$combined_includes"
for item in "${items[@]}"; do
  json+="\"$item\","
done

# Remove last commas
json=${json%?}

json="$json
  ],
  \"C_Cpp.default.defines\": [
    \"__XTENSA__"

if [[ $arch == "xtensa" ]]; then
  json="$json 1\""
else
  json="$json 0\""
fi

json="$json
  ]
}"

# Install include paths
# WARNING: REWRITES ".vscode/settings.json" FILE
mkdir -p .vscode
echo "$json" > .vscode/settings.json.tmp
jq . .vscode/settings.json.tmp > .vscode/settings.json
rm .vscode/settings.json.tmp

echo "Include paths installed for this project"
