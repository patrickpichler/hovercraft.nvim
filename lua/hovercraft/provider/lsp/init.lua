local hover = require('hovercraft.provider.lsp.hover')

return {
  Hover = hover,

  -- this is done purely for downward compability
  new = function()
    return hover.new()
  end
}
