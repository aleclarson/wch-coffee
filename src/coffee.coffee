tarInstall = require 'tar-install'
tarUrl = require 'tar-url'
semver = require 'semver'
path = require 'path'
wch = require 'wch'
fs = require 'fsx'
os = require 'os'

# Where versions are installed
INSTALL_DIR = path.join os.homedir(), '.coffee'

# Installed versions
installed = new Set

# Loaded transpilers
loaded = {}

exports.init = ->
  if fs.isDir INSTALL_DIR
    fs.readDir(INSTALL_DIR).forEach (name) ->
      if version = /-([^-]+)$/.exec(name)[1]
        installed.add version

# Load coffee-script for a package.
exports.load = (root) ->
  dep = parseDeps root.devDependencies
  version = semver.maxSatisfying Array.from(installed), dep.version

  if version # Use an installed version.
    return compile if compile = loaded[version]
    coffee = path.join INSTALL_DIR, dep.name + '-' + version

  # Install a missing version.
  else if url = await tarUrl dep.name, dep.version
    res = await tarInstall url, INSTALL_DIR
    coffee = res.path
    installed.add version = /-([^-]+)$/.exec(coffee)[1]
    @log.pale_green 'Installed:', dep.name + '@' + version

  else # Invalid version!
    @log.pale_red 'Package error:', root.path
    @log.pale_red 'Invalid version:', dep.name + '@' + dep.version
    return

  @log.pale_yellow 'Loading:', coffee
  {compile} = require coffee
  loaded[version] = compile
  return compile

parseDeps = (deps) ->

  name = 'coffee-script'
  if version = deps[name]
    return {name, version}

  name = 'coffeescript'
  if version = deps[name]
    return {name, version}
  return {name, version: '*'}
