local plugin = {
    "3rd/image.nvim",
    build = false, -- so that it doesn't build the rock https://github.com/3rd/image.nvim/issues/91#issuecomment-2453430239
    tag = "v1.5.1",
    opts = {
        processor = "magick_cli",
    }
}





-- return plugin
-- dummy
return {}

