path = require 'path'
wch = require 'wch'
fs = require 'fsx'

plugin = wch.plugin()

coffee = require './coffee'
coffee.log = plugin.log

plugin.on 'run', ->
  coffee.init()

  files = plugin.watch 'src',
    fields: ['name', 'exists', 'new', 'mtime_ms']
    include: ['**/*.coffee']
    exclude: ['__*__']

  files
    .filter (file) -> file.exists
    .read compile
    .save (file) -> file.dest
    .then (dest, file) ->
      wch.emit 'file:build', {file: file.path, dest}

  files
    .filter (file) -> !file.exists
    .delete getDest
    .then (dest, file) ->
      wch.emit 'file:delete', {file: file.path, dest}

plugin.on 'add', (root) ->
  root.dest = path.dirname root.main or 'js/index'
  root.getDest = getDest
  root.compile = coffee.load root
  return

module.exports = plugin

#
# Helpers
#

{log} = plugin

getDest = (file) ->
  path.join @path, @dest, file.name.replace /\.coffee$/, '.js'

compile = (input, file) ->
  file.dest = @getDest file
  try mtime = fs.stat(file.dest).mtime.getTime()
  return if mtime and mtime > file.mtime_ms

  if typeof @compile isnt 'function'
    @compile = await @compile

  if log.verbose
    log.pale_yellow 'Transpiling:', file.path

  try output = @compile input,
    filename: file.path
    header: true
    bare: true

  catch err
    loc = err.location
    wch.emit 'file:error',
      file: file.path
      message: err.message
      location: [
        [loc.first_line, loc.first_column]
        [loc.last_line or loc.first_line, loc.last_column + 1]
      ]

    if log.verbose
      log.red 'Failed to compile:', file.path
      log.gray err.message
    return
