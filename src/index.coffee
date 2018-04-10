tarInstall = require 'tar-install'
tarUrl = require 'tar-url'
semver = require 'semver'
huey = require 'huey'
path = require 'path'
wch = require 'wch'
fs = require 'fsx'
os = require 'os'

exports.run = ->
  if fs.isDir INSTALL_DIR
    fs.readDir(INSTALL_DIR).forEach (name) ->
      if version = /-([^-]+)$/.exec(name)[1]
        installed.add version

exports.add = (root) ->
  packPath = path.join root, 'package.json'
  pack = JSON.parse fs.readFile packPath

  dep = getVersion pack.devDependencies
  coffee = await loadTranspiler dep.name, dep.version

  src = path.join root, 'src'
  dest = path.join root, path.dirname pack.main or 'js/index'
  stream = wch.stream src,
    clock: false
    fields: ['name', 'exists', 'new', 'mtime_ms']
    include: ['**/*.coffee']
    exclude: ['__*__']

  stream.on 'data', (file) ->

    if file.exists
      transpile file, getDest(dest, file.name), coffee
      return

    # Remove the associated .js file
    fs.removeFile getDest dest, file.name
    return

  stream.on 'error', onError
  streams.set root, stream
  return

exports.remove = (root) ->
  streams.get(root).destroy()
  streams.delete root

exports.end = ->
  streams.forEach (stream) ->
    stream.destroy()
  streams.clear()

#
# Internal
#

# Where versions are installed
INSTALL_DIR = path.join os.homedir(), '.coffee'

# Installed versions
installed = new Set

# Loaded transpilers
loaded = new Map

# Active file streams
streams = new Map

log = (...args) ->
  wch.log.coal '[coffee]', ...args
log.verbose = !!process.env.VERBOSE
huey.log log, !process.env.NO_COLOR

transpile = (file, dest, coffee) ->
  try mtime = fs.stat(dest).mtimeMs
  return if mtime and mtime > file.mtime_ms

  if log.verbose
    log.pale_yellow 'Transpiling:', file.path

  input = fs.readFile file.path
  try output = coffee.compile input,
    filename: file.path
    header: true
    bare: true

  catch err
    loc = err.location
    wch.emit 'compile:error',
      file: file.path
      message: err.message
      location: [
        [loc.first_line, loc.first_column]
        [loc.last_line or loc.first_line, loc.last_column]
      ]

    if log.verbose
      log.red 'Failed to compile:', file.path
      log.gray err.stack
    return

  fs.writeDir path.dirname dest
  fs.writeFile dest, output

  wch.emit 'compile', {file: file.path, dest}
  return

getDest = (dir, name) ->
  path.join dir, name.replace /\.coffee$/, '.js'

getVersion = (deps) ->

  name = 'coffee-script'
  if version = deps[name]
    return {name, version}

  name = 'coffeescript'
  if version = deps[name]
    return {name, version}
  return {name, version: '*'}

# Find matching version or install it
loadTranspiler = (name, version) ->
  match = semver.maxSatisfying Array.from(installed), version
  if match # Use an installed version.
    return coffee if coffee = loaded.get match
    pack = path.join INSTALL_DIR, name + '-' + match
    version = match

  else # Install the missing version.
    url = await tarUrl name, version
    if url is null
      return log.pale_red 'Invalid version:', version
    res = await tarInstall url, INSTALL_DIR
    pack = res.path
    installed.add version = /-([^-]+)$/.exec(pack)[1]
    log.pale_green 'Installed:', name + '@' + version

  log.pale_yellow 'Loading:', pack
  coffee = require pack
  loaded.set version, coffee
  return coffee

onError = (err) ->
  if log.verbose
  then log.pale_red err.name + ':', err.message
  else log err.stack
