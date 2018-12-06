// Generated by CoffeeScript 2.3.2
var INSTALL_DIR, fs, installed, loaded, os, parseDeps, path, semver, tarInstall, tarUrl;

tarInstall = require('tar-install');

tarUrl = require('tar-url');

semver = require('semver');

path = require('path');

fs = require('fsx');

os = require('os');

// Where versions are installed
INSTALL_DIR = path.join(os.homedir(), '.coffee');

// Installed versions
installed = new Set;

// Loaded transpilers
loaded = {};

exports.init = function() {
  if (fs.isDir(INSTALL_DIR)) {
    return fs.readDir(INSTALL_DIR).forEach(function(name) {
      var version;
      if (version = /-([^-]+)$/.exec(name)) {
        return installed.add(version[1]);
      }
    });
  }
};

// Load coffee-script for a package.
exports.load = async function(pack) {
  var coffee, compile, dep, log, res, url, version;
  dep = parseDeps(pack.devDependencies);
  version = semver.maxSatisfying(Array.from(installed), dep.version);
  ({log} = this);
  if (version) { // Use an installed version.
    if (compile = loaded[version]) {
      return compile;
    }
    coffee = path.join(INSTALL_DIR, dep.name + '-' + version);
  // Install a missing version.
  } else if (url = (await tarUrl(dep.name, dep.version))) {
    res = (await tarInstall(url, INSTALL_DIR));
    coffee = res.path;
    installed.add(version = /-([^-]+)$/.exec(coffee)[1]);
    log(log.lgreen('Installed:'), dep.name + '@' + version); // Invalid version!
  } else {
    log(log.lred('Package error:'), pack.path);
    log(log.lred('Invalid version:'), dep.name + '@' + dep.version);
    return;
  }
  log(log.lyellow('Loading:'), coffee);
  ({compile} = require(coffee));
  loaded[version] = compile;
  return compile;
};

parseDeps = function(deps) {
  var name, version;
  name = 'coffee-script';
  if (version = deps[name]) {
    return {name, version};
  }
  name = 'coffeescript';
  if (version = deps[name]) {
    return {name, version};
  }
  return {
    name,
    version: '*'
  };
};
