local utils = require 'mp.utils'

local globals = {
    main_script_name = "",
    thumbs_dir = "",
    thumbnail_width = 0,
    thumbnail_height = 0,
    generate_thumbnails_with_mpv = false,
    tmp_path = "",
    ffmpeg_image_args = {},
    ffmpeg_video_args = {},
}

local thumbnail_stack = {} -- stack of { path, hash } objects
local failed = {} -- hashes of failed thumbnails, to avoid redoing them

function file_exists(path)
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

function init_thumbnails_generator(main_script_name, thumbs_dir, thumbnail_width, tumbnail_height, generate_thumbnails_with_mpv)
    globals.main_script_name = main_script_name
    globals.thumbs_dir = thumbs_dir
    globals.thumbnail_width = tonumber(thumbnail_width)
    globals.thumbnail_height = tonumber(tumbnail_height)
    globals.generate_thumbnails_with_mpv = generate_thumbnails_with_mpv == "true"
    globals.tmp_path = utils.join_path(globals.thumbs_dir, "tmp")
    local h, w = globals.thumbnail_height, globals.thumbnail_width
    globals.ffmpeg_image_args = {
        "ffmpeg",
        "-i", path,
        "-vf", string.format("scale=iw*min(1\\,min(%d/iw\\,%d/ih)):-2", w, h) .. "," .. string.format("pad=%d:%d:(%d-iw)/2:(%d-ih)/2:color=0x00000000", w, h, w, h),
        "-map", "v:0", "-f", "rawvideo", "-pix_fmt", "bgra", "-c:v", "rawvideo",
        "-y", "-loglevel", "quiet",
        globals.tmp_path
    }
    globals.ffmpeg_video_args = {
        "ffmpeg",
        "-i", path,
        "-vf", "thumbnail," .. globals.ffmpeg_image_args[5],
        "-map", "v:0", "-f", "rawvideo", "-pix_fmt", "bgra", "-c:v", "rawvideo",
        "-frames:v", "1",
        "-y", "-loglevel", "quiet",
        globals.tmp_path
    }
end

function generate_thumbnail(input_path, hash)
    local output_path = utils.join_path(globals.thumbs_dir,
        string.format("%s_%d_%d", hash, globals.thumbnail_width, globals.thumbnail_height)
    )
    if file_exists(output_path) then return true end
    local args
    local extension = string.match(input_path, "%.([^.]+)$")
    if extension == "mkv" or extension == "mp4" or extension == "avi" then 
        args = globals.ffmpeg_video_args
    else
        args = globals.ffmpeg_image_args
    end
    args[3] = input_path
    local res = utils.subprocess({ args = args, cancellable = false })
    --atomically generate the output to avoid loading half-generated thumbnails (results in crashes)
    if res.status == 0 then
        if os.rename(globals.tmp_path, output_path) then
            return true
        end
    end
    return false
end

-- shitty custom event loop because I can't figure out a better way
-- works pretty well though
function handle_events(wait)
    e = mp.wait_event(wait)
    while e.event ~= "none" do
        if e.event == "shutdown" then
            return false
        elseif e.event == "client-message" then
            if e.args[1] == "push-thumbnail-to-stack" then
                thumbnail_stack[#thumbnail_stack + 1] = { path = e.args[2], hash = e.args[3] }
            elseif e.args[1] == "init-thumbnails-generator" then
                init_thumbnails_generator(e.args[2], e.args[3], e.args[4], e.args[5], e.args[6])
            end
        end
        e = mp.wait_event(0)
    end 
    return true
end

function mp_event_loop()
    while true do
        if not handle_events(1e20) then return end
        while #thumbnail_stack > 0 do
            local input = thumbnail_stack[#thumbnail_stack]
            if not failed[input.hash] then
                local res = generate_thumbnail(input.path, input.hash)
                if res then
                    mp.commandv("script-message-to", "gallery", "thumbnail-generated", input.hash)
                else
                    failed[input.hash] = true
                end
            end
            thumbnail_stack[#thumbnail_stack] = nil
            if not handle_events(0) then return end
        end
    end
end

-- broadcast to every script in case the user modified the "gallery" script filename
mp.commandv("script-message", "gallery-thunbnails-generator-registered", mp.get_script_name())
