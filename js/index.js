// Generated by CoffeeScript 2.3.2
var coffee, fs, path, wch;

path = require('path');

wch = require('wch');

fs = require('fsx');

coffee = require('./coffee');

// TODO: Add config method for specifying src/dest paths.
// TODO: Add config option for copying non-coffee files into dest.
module.exports = function(log) {
  var build, clear, compile, shortPath, watchOptions;
  coffee.log = log;
  coffee.init();
  shortPath = function(path) {
    return path.replace(process.env.HOME, '~');
  };
  compile = async function(input, file) {
    var err, loc, mtime;
    try {
      mtime = fs.stat(file.dest).mtime.getTime();
    } catch (error) {}
    if (mtime && mtime > file.mtime_ms) {
      return;
    }
    if (typeof this.compile !== 'function') {
      this.compile = (await this.compile);
    }
    log('Transpiling:', shortPath(file.path));
    try {
      return this.compile(input, {
        filename: file.path,
        header: true,
        bare: true
      });
    } catch (error) {
      err = error;
      loc = err.location;
      wch.emit('file:error', {
        file: file.path,
        message: err.message,
        range: [[loc.first_line, loc.first_column], [loc.last_line || loc.first_line, loc.last_column + 1]]
      });
      log(log.red('Failed to transpile:'), shortPath(file.path));
    }
  };
  build = wch.pipeline().read(compile).save(function(file) {
    return file.dest;
  }).each(function(dest, file) {
    return wch.emit('file:build', {
      file: file.path,
      dest
    });
  });
  clear = wch.pipeline().delete(function(file) {
    return file.dest;
  }).each(function(dest, file) {
    return wch.emit('file:delete', {
      file: file.path,
      dest
    });
  });
  watchOptions = {
    only: ['*.coffee'],
    skip: ['**/__*__/**'],
    fields: ['name', 'exists', 'new', 'mtime_ms'],
    crawl: true
  };
  return {
    attach: function(pack) {
      pack.sources = [];
      // Wait for the project to be loaded.
      return process.nextTick(function() {
        pack.compile = coffee.load(pack);
        if (!pack.sources.length) {
          pack.sources.push(['src', path.dirname(pack.main || 'js/.')]);
        }
        // Create a watch stream for each src->dest pair.
        return pack.sources.forEach(function([src, dest]) {
          var changes;
          if (!fs.isDir(path.join(pack.path, src))) {
            log.warn('Directory does not exist:', path.join(pack.path, src));
            return;
          }
          changes = pack.stream(src, watchOptions);
          return changes.on('data', function(file) {
            var action;
            if (file.name === '/') {
              return;
            }
            file.dest = path.join(pack.path, dest, file.name.replace(/\.coffee$/, '.js'));
            action = file.exists ? build : clear;
            return action.call(pack, file).catch(function(err) {
              log(log.red('Error while processing:'), file.path);
              return console.error(err.stack);
            });
          });
        });
      });
    },
    methods: {
      compile: function(src, dest) {
        this.sources.push([src, dest]);
        return this;
      }
    }
  };
};
