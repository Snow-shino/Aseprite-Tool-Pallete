local scriptRoot=app.fs.filePath(app.fs.normalizePath(debug.getinfo(1,'S').source:sub(2)))
package.path=app.fs.joinPath(scriptRoot,'..','?.lua')..';'..app.fs.joinPath(scriptRoot,'..','?','init.lua')..';'..package.path
local ok,err=xpcall(function() dofile(app.fs.joinPath(scriptRoot,'run.lua')) end,debug.traceback)
local result=io.open(app.fs.joinPath(app.fs.tempPath,'arete-palette-limiter-tests.txt'),'wb')
result:write(ok and ('PASS Aseprite '..tostring(app.version)..'\n') or ('FAIL\n'..tostring(err)))
result:close()
if not ok then error(err) end
