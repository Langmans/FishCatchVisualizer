---@meta
-- What LibSharedMedia-3.0 has at run time beyond its own file's functions: CallbackHandler embeds
-- RegisterCallback in it (LibSharedMedia-3.0.lua, lib.callbacks = CallbackHandler:New(lib)).

---@class LibSharedMedia-3.0
local LibSharedMedia = {}

---Calls `callback(event, ...)` on the library's events, keyed by `target`. LibSharedMedia_Registered
---comes with the media type and the key of what was registered.
---@param target table
---@param event string
---@param callback function
function LibSharedMedia.RegisterCallback(target, event, callback) end
