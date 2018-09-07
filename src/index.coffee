path = require 'path'
wch = require 'wch'
fs = require 'fsx'

coffee = require './coffee'

# TODO: Add config method for specifying src/dest paths.
# TODO: Add config option for copying non-coffee files into dest.
module.exports = (log) ->
  coffee.log = log
  coffee.init()

  shortPath = (path) ->
    path.replace process.env.HOME, '~'

  compile = (input, file) ->
    try mtime = fs.stat(file.dest).mtime.getTime()
    return if mtime and mtime > file.mtime_ms

    if typeof @compile isnt 'function'
      @compile = await @compile

    log 'Transpiling:', shortPath file.path
    try @compile input,
      filename: file.path
      header: true
      bare: true

    catch err
      loc = err.location
      wch.emit 'file:error',
        file: file.path
        message: err.message
        range: [
          [loc.first_line, loc.first_column]
          [loc.last_line or loc.first_line, loc.last_column + 1]
        ]

      log log.red('Failed to transpile:'), shortPath file.path
      return

  build = wch.pipeline()
    .read compile
    .save (file) -> file.dest
    .each (dest, file) ->
      wch.emit 'file:build', {file: file.path, dest}

  clear = wch.pipeline()
    .delete (file) -> file.dest
    .each (dest, file) ->
      wch.emit 'file:delete', {file: file.path, dest}

  watchOptions =
    only: ['*.coffee']
    skip: ['**/__*__/**']
    fields: ['name', 'exists', 'new', 'mtime_ms']
    crawl: true

  attach: (pack) ->
    pack.sources = []

    # Wait for the project to be loaded.
    process.nextTick ->
      pack.compile = coffee.load pack

      if !pack.sources.length
        pack.sources.push ['src', path.dirname pack.main or 'js/.']

      # Create a watch stream for each src->dest pair.
      pack.sources.forEach ([src, dest]) ->
        if !fs.isDir path.join(pack.path, src)
          log.warn 'Directory does not exist:', path.join(pack.path, src)
          return

        changes = pack.stream src, watchOptions
        changes.on 'data', (file) ->
          return if file.name is '/'

          file.dest = path.join pack.path, dest,
            file.name.replace /\.coffee$/, '.js'

          action = if file.exists then build else clear
          action.call(pack, file).catch (err) ->
            log log.red('Error while processing:'), file.path
            console.error err.stack

  methods:

    compile: (src, dest) ->
      @sources.push [src, dest]
      return this
