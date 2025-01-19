# DupeCheck
Audio File duplication checker in shell
#### The problem

I have a relatively large music collection that I try to sync between different devices, this inevitably means that I have a lot of duplicate files, or even have multiple versions across different albums.

#### The solution

This script recursively indexes a folder for files and allows for two methods of duplicate checking, filesize, and metadata.

The filesize is simple enough, it just compares the filesizes of all the files and sees if there are any that have the same exact size.

The metadata checker uses ffprobe to get the artist and track title, it then stores those values and sees if there are any others that have the same values.

When the script has found any copies, you can either manually go through and select y/n for the deletion of each file, where it will always prefer the larger file.

Or you can allow it to do this for you.

### Usage
```
./checker.sh [--dry-run] [--batch-delete] [--keep-fat32] [--always-delete-from <path>] (--same-size|--same-data) <directory>
```
--dry-run will show you what would happen without performing any file actions.

--batch-delete will allow it to make decisions on your behalf, run with --dry-run first to see what it would do.

--keep-fat32 this one is because a while ago I had to convert all the filenames to not have special characters or whitespace so they would work with my Rockbox iPod, and so needed a way to prefer to keep those files over the ones that didn't comply.

--always-delete-from this one is for me when I've downloaded my Tidal library into a folder, then also have ripped CDs which are already in my Tidal library, so it makes sense to delete the Tidal ones, by specifying the path that should always NOT be preffered, you can do this.

--same-size checks for duplicates based on their sizes

--same-data use FFprobe to check if the metadata matches
