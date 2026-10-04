-- Register as a native Aseprite Sprite menu command and Run Command entry.
function init(plugin)
  plugin:newCommand{
    id='AretePaletteLimiter',
    title='Arete Palette Limiter',
    group='sprite_crop',
    onenabled=function() return app.sprite~=nil end,
    onclick=function() require('src.ui').show() end,
  }
end
