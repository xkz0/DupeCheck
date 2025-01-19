#!/bin/bash
# Copyright Crabman Stan, 2025


function getFiles {
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$1" -type f -print0)
    printf '%s\n' "${files[@]}"
}

function compareSizes {
    local -A sizes=()
    local found=false
    local dry_run=$1
    local batch_delete=$2
    local keep_fat32=$3
    local delete_from=$4
    local total_freed=0
    shift 4

    # First pass: collect sizes
    for file in "$@"; do
        size=$(stat -c %s "$file")
        if [[ -n "${sizes[$size]}" ]]; then
            existing_file="${sizes[$size]}"
            
            # Check if we should always delete from specific path
            if [[ -n "$delete_from" ]]; then
                if [[ "$file" == ${delete_from}* ]]; then
                    target_file="$file"
                elif [[ "$existing_file" == ${delete_from}* ]]; then
                    target_file="$existing_file"
                    sizes[$size]="$file"
                else
                    target_file="$file"
                fi
            else
                # Always prefer to delete .tmp files
                if [[ "$file" == *.tmp ]]; then
                    target_file="$file"
                elif [[ "$existing_file" == *.tmp ]]; then
                    target_file="$existing_file"
                    sizes[$size]="$file"
                elif [[ "$keep_fat32" = true ]]; then
                    # Check if one file is all uppercase with underscores and the other is normal case with spaces
                    if [[ "$file" =~ ^.*[[:upper:]]+.*_.*$ && ! "$existing_file" =~ ^.*[[:upper:]]+.*_.*$ ]]; then
                        # Current file is uppercase with underscores - keep it
                        target_file="$existing_file"
                        sizes[$size]="$file"
                    elif [[ ! "$file" =~ ^.*[[:upper:]]+.*_.*$ && "$existing_file" =~ ^.*[[:upper:]]+.*_.*$ ]]; then
                        # Existing file is uppercase with underscores - keep it
                        target_file="$file"
                    else
                        # Fall back to problematic character check - prefer files without spaces/special chars
                        if [[ "$file" =~ [[:space:]'"`\&\$\(\)\[\]\{\}\;\:\'\,\<\>\?\/\\] && ! "$existing_file" =~ [[:space:]'"`\&\$\(\)\[\]\{\}\;\:\'\,\<\>\?\/\\] ]]; then
                            target_file="$file"
                        elif [[ ! "$file" =~ [[:space:]'"`\&\$\(\)\[\]\{\}\;\:\'\,\<\>\?\/\\] && "$existing_file" =~ [[:space:]'"`\&\$\(\)\[\]\{\}\;\:\'\,\<\>\?\/\\] ]]; then
                            target_file="$existing_file"
                            sizes[$size]="$file"
                        else
                            target_file="$file"
                        fi
                    fi
                else
                    target_file="$file"
                fi
            fi

            echo "Files $existing_file and $file have the same size"
            if [[ "$dry_run" = true ]]; then
                echo "(Would prompt to delete $target_file)"
                continue
            fi
            
            if [[ "$batch_delete" = true ]]; then
                local file_size=$(stat -c %s "$target_file")
                rm "$target_file"
                total_freed=$((total_freed + file_size))
                echo "$target_file deleted."
            else
                read -p "Delete $target_file? [y/n]: " choice
                if [[ "$choice" = "y" ]]; then
                    local file_size=$(stat -c %s "$target_file")
                    rm "$target_file"
                    total_freed=$((total_freed + file_size))
                    echo "$target_file deleted."
                fi
            fi
            found=true
        else
            sizes[$size]="$file"
        fi
    done

    if [[ "$found" = false ]]; then
        echo "No files have the same size"
    else
        # Convert bytes to human readable format
        if [ $total_freed -gt 1073741824 ]; then
            echo "Total space freed: $(($total_freed / 1073741824)) GB"
        elif [ $total_freed -gt 1048576 ]; then
            echo "Total space freed: $(($total_freed / 1048576)) MB"
        elif [ $total_freed -gt 1024 ]; then
            echo "Total space freed: $(($total_freed / 1024)) KB"
        else
            echo "Total space freed: $total_freed bytes"
        fi
    fi
}

function isAudioFile() {
    local file="$1"
    local ext="${file,,}"  
    [[ "$ext" =~ \.(mp3|m4a|wav|flac|ogg|wma|aac)$ ]]
}

function show_progress {
    local current=$1
    local total=$2
    local percentage=$((current * 100 / total))
    printf "\rProcessing files: %d%%" "$percentage"
}

function compareMetadata {
    unset metadata
    declare -A metadata=()
    local found=false
    local dry_run=$1
    local batch_delete=$2
    local keep_fat32=$3
    local delete_from=$4
    local total_freed=0
    shift 4
    
    local total_files=$#
    local current_file=0

    # First pass: collect metadata
    for file in "$@"; do
        ((current_file++))
        show_progress $current_file $total_files

        # Skip if not an audio file
        if ! isAudioFile "$file"; then
            continue
        fi

        # Extract artist and title using ffprobe
        if ! command -v ffprobe &> /dev/null; then
            echo "ffprobe is required but not installed. Please install ffmpeg."
            return 1
        fi

        # Get artist and title from metadata
        artist=$(ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$file")
        title=$(ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$file")
        
        # Skip if missing metadata
        if [[ -z "$artist" || -z "$title" ]]; then
            echo "Warning: Missing metadata for $file"
            continue
        fi

        key="${artist}|||${title}"
        
        if [[ -n "${metadata[$key]}" ]]; then
            existing_file="${metadata[$key]}"
            size=$(stat -c %s "$file")
            existing_size=$(stat -c %s "$existing_file")
            
           
            if [[ -n "$delete_from" ]]; then
                if [[ "$file" == ${delete_from}* ]]; then
                    target_file="$file"
                elif [[ "$existing_file" == ${delete_from}* ]]; then
                    target_file="$existing_file"
                    metadata[$key]="$file"
                else
                    
                    if [[ $size -gt $existing_size ]]; then
                        target_file="$existing_file"
                        metadata[$key]="$file"
                    else
                        target_file="$file"
                    fi
                fi
            else
                
                if [[ $size -gt $existing_size ]]; then
                    target_file="$existing_file"
                    metadata[$key]="$file"
                else
                    target_file="$file"
                fi
            fi

            echo "Files with same metadata found:"
            echo "  $existing_file ($(($existing_size / 1024)) KB)"
            echo "  $file ($(($size / 1024)) KB)"
            
            if [[ "$dry_run" = true ]]; then
                echo "(Would prompt to delete $target_file)"
                continue
            fi
            
            if [[ "$batch_delete" = true ]]; then
                local file_size=$(stat -c %s "$target_file")
                rm "$target_file"
                total_freed=$((total_freed + file_size))
                echo "$target_file deleted."
            else
                read -p "Delete $target_file? [y/n]: " choice
                if [[ "$choice" = "y" ]]; then
                    local file_size=$(stat -c %s "$target_file")
                    rm "$target_file"
                    total_freed=$((total_freed + file_size))
                    echo "$target_file deleted."
                fi
            fi
            found=true
        else
            metadata[$key]="$file"
        fi
    done
    echo 

    if [[ "$found" = false ]]; then
        echo "No files have the same metadata"
    else
        # Convert bytes to human readable format
        if [ $total_freed -gt 1073741824 ]; then
            echo "Total space freed: $(($total_freed / 1073741824)) GB"
        elif [ $total_freed -gt 1048576 ]; then
            echo "Total space freed: $(($total_freed / 1048576)) MB"
        elif [ $total_freed -gt 1024 ]; then
            echo "Total space freed: $(($total_freed / 1024)) KB"
        else
            echo "Total space freed: $total_freed bytes"
        fi
    fi
}

# Main
dry_run=false
batch_delete=false
keep_fat32=false
compare_mode=""
delete_from=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            dry_run=true
            shift
            ;;
        --batch-delete)
            batch_delete=true
            shift
            ;;
        --keep-fat32)
            keep_fat32=true
            shift
            ;;
        --same-size)
            compare_mode="size"
            shift
            ;;
        --same-data)
            compare_mode="metadata"
            shift
            ;;
        --always-delete-from)
            delete_from="$2"
            shift 2
            ;;
        *)
            directory="$1"
            shift
            ;;
    esac
done

if [[ ! -d "$directory" ]] || [[ -z "$compare_mode" ]]; then
    echo "Usage: $0 [--dry-run] [--batch-delete] [--keep-fat32] [--always-delete-from <path>] (--same-size|--same-data) <directory>"
    exit 1
fi

# Early check for ffprobe if metadata comparison is selected
if [[ "$compare_mode" == "metadata" ]] && ! command -v ffprobe &> /dev/null; then
    echo "Error: ffprobe is required for metadata comparison but is not installed."
    echo "Please install ffmpeg using your package manager:"
    echo "  - For Ubuntu/Debian: sudo apt-get install ffmpeg"
    echo "  - For Fedora: sudo dnf install ffmpeg"
    echo "  - For macOS: brew install ffmpeg"
    echo "  - For Windows: download from https://ffmpeg.org/download.html"
    exit 1
fi

mapfile -t files < <(getFiles "$directory")

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No files found in directory"
    exit 0
fi

case "$compare_mode" in
    "size")
        compareSizes "$dry_run" "$batch_delete" "$keep_fat32" "$delete_from" "${files[@]}"
        ;;
    "metadata")
        compareMetadata "$dry_run" "$batch_delete" "$keep_fat32" "$delete_from" "${files[@]}"
        ;;
esac