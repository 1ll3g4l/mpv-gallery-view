Gallery-view script for [mpv](https://github.com/mpv-player/mpv). Shows thumbnails of entries in the plyalist in a grid view.

# Important

* **The default thumbnail directory is probably not appropriate for your system.** See Installation for instructions on how to change it.
* **Make sure that the thumbnail directory exists for auto-generation to work.**
* **Also make sure to have ffmpeg in your PATH.** Or use mpv for thumbnails generation (not recommended : slower, no transparency transparency), see settings.

# Installation

Copy `scripts/gallery.lua` to your mpv scripts directory.

If you want on-demand thumbnail generation, copy `scripts/gallery-thumbgen.lua` too. You can make multiple copies of it (with different names) to potentially speed up generation, they will register themselves automatically.

If you want to customize the script (in particular the thumbnail directory), copy `lua-settings/gallery.conf` and modify it to your liking.

The gallery view is bound to `g` by default but can be rebound in input.conf with `t script-message gallery-view`.

# Thumbnail generation

By default, thumbnails are generated on-demand, and reused throughout mpv instances.

Thumbnails can also be generated offline by running this shell snippet (modify according to your needs):
```
w=192
h=108
thumb_dir=~/.mpv_thumbs_dir/
IFS="
"
for i in $(find . -name '*png'); do
    hash=$(printf %s $(realpath $i) | sha256sum | cut -c1-12)
    # prepend "thumbnail" to the filters when generating video thumbnails
    ffmpeg -i $i -vf "scale=iw*min(1\,min($w/iw\,$h/ih)):-2,pad=$w:$h:($w-iw)/2:($h-ih)/2:color=0x00000000" -y -f rawvideo -pix_fmt bgra -c:v rawvideo -frames:v 1 -loglevel quiet "$thumb_dir"/"$hash"_"$w"_"$h"
done
```

# TODO

* Add some kind of checkerboard pattern behind transparent thumbnails (ideally with an ffmpeg filter) (?).
* Basic mouse support.
* Remove entry from playlist and gallery.
* Show filename under thumbnail.

# Limitations

Ad-hoc thumbnail library (yet another), which is not shared by any other program.

Management of the thumbnails is left to the user. In particular, stale thumbnails (whose file has been (re)moved) are not deleted by the script. This can be fixed by deleting thumbnails which have not been accessed since N days, with a systemd timer for example.

Thumbnails are raw bgra, which is somewhat wasteful. With the default settings, a thumbnail uses 81KB (around 13k thumbnails in a GB).
