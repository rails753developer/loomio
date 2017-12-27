gulp     = require 'gulp'
paths    = require './tasks/paths'
sequence = require 'gulp-run-sequence'

execjs   = require './tasks/execjs'
angular  = require './tasks/angular'
vue      = require './tasks/vue'

minify   = require './tasks/minify'
extra    = require './tasks/extra'

gulp.task 'angular:vendor',          angular.vendor
gulp.task 'angular:require',         angular.require
gulp.task 'angular:browserify',      angular.browserify
gulp.task 'angular:bundle',          (done) -> sequence('angular:require', 'angular:browserify', -> done())
gulp.task 'angular:core:haml',       angular.core.haml
gulp.task 'angular:core:scss',       angular.core.scss
gulp.task 'angular:plugin:haml',     angular.plugin.haml
gulp.task 'angular:plugin:scss',     angular.plugin.scss
gulp.task 'angular:fonts',           extra.fonts
gulp.task 'angular:emoji',           extra.emoji
gulp.task 'angular:moment_locales',  extra.moment_locales
gulp.task 'angular:minify:js',       minify.app.js
gulp.task 'angular:minify:css',      minify.app.css
gulp.task 'angular:minify:bundle',   minify.app.bundle
gulp.task 'angular:minify', ['angular:minify:js', 'angular:minify:bundle', 'angular:minify:css']

gulp.task 'angular:bundle:dev', [
  'angular:fonts',
  'angular:bundle',
  'angular:core:haml',
  'angular:core:scss',
  'angular:plugin:haml',
  'angular:plugin:scss',
  'angular:vendor',
  'angular:emoji',
  'angular:moment_locales'
]
gulp.task 'angular:bundle:prod', (done) -> sequence('angular:bundle:dev', 'angular:minify', -> done())

gulp.task 'vue:bundle:dev',  vue.bundle.development
gulp.task 'vue:bundle:prod', vue.bundle.production

gulp.task 'execjs:dev',      extra.execjs.development
gulp.task 'execjs:prod',     extra.execjs.production

gulp.task 'bundle:dev',  ['angular:bundle:dev', 'vue:bundle:dev', 'execjs:dev']
gulp.task 'bundle:prod', ['angular:bundle:prod', 'vue:bundle:prod', 'execjs:prod']
gulp.task 'dev',         -> sequence('bundle:dev', require('./tasks/watch'))

gulp.task 'protractor:core',    require('./tasks/protractor/core')
gulp.task 'protractor:plugins', require('./tasks/protractor/plugins')

gulp.task 'protractor',     -> sequence('angular:bundle:dev', 'protractor:now')
gulp.task 'protractor:now', -> sequence('protractor:core', 'protractor:plugins')
