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
    include: ['**/*.coffee']
    exclude: ['__*__']

  stream.on 'data', (file) ->
    transpile file.name, src, dest, coffee

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

transpile = (name, src, dest, coffee) ->
  file = path.join src, name
  if log.verbose
    log.pale_yellow 'Transpiling:', file

  input = fs.readFile file
  try
    output = coffee.compile input,
      filename: file
      header: true
      bare: true
  catch err
    {message, location} =err
    location = [
      [location.first_line, location.first_column]
      [location.last_line or location.first_line, location.last_column]
    ]
    wch.emit 'compile:error', {file, message, location}
    if log.verbose
      log.red 'Failed to compile:', file
      log.gray error.stack
    return

  dest = path.join dest, name.replace /\.coffee$/, '.js'
  fs.writeDir path.dirname dest
  fs.writeFile dest, output

  wch.emit 'compile', {file, dest}
  return

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
