// Generated by CoffeeScript 2.2.4
var log, wch;

wch = require('wch');

log = function(...args) {
  return wch.log.coal('[coffee]', ...args);
};

log.verbose = !!process.env.VERBOSE;

huey.log(log, !process.env.NO_COLOR);

module.exports = log;
