Routes          = require 'angular/routes.coffee'
AppConfig       = require 'shared/services/app_config.coffee'
Session         = require 'shared/services/session.coffee'
Records         = require 'shared/services/records.coffee'
EventBus        = require 'shared/services/event_bus.coffee'
AbilityService  = require 'shared/services/ability_service.coffee'
ModalService    = require 'shared/services/modal_service.coffee'
IntercomService = require 'shared/services/intercom_service.coffee'
I18n            = require 'shared/services/i18n.coffee'

{ scrollTo, updateCover, setCurrentComponent } = require 'shared/helpers/layout.coffee'
{ viewportSize, trackEvents }          = require 'shared/helpers/window.coffee'
{ signIn, subscribeToLiveUpdate }      = require 'shared/helpers/user.coffee'
{ broadcastKeyEvent, registerHotkeys } = require 'shared/helpers/keyboard.coffee'
{ setupAngular }                       = require 'angular/setup.coffee'

$controller = ($scope, $injector) ->
  $injector.get('$router').config(Routes.concat(AppConfig.plugins.routes))

  $scope.currentComponent = 'nothing yet'
  $scope.renderSidebar    = viewportSize() == 'extralarge'
  $scope.isLoggedIn       = -> AbilityService.isLoggedIn()
  $scope.isEmailVerified  = -> AbilityService.isEmailVerified()
  $scope.keyDown          = (event) -> broadcastKeyEvent($scope, event)
  $scope.loggedIn = ->
    $scope.pageError = null
    $scope.refreshing = true
    $injector.get('$timeout') -> $scope.refreshing = false
    IntercomService.boot()
    subscribeToLiveUpdate()

  setupAngular($scope, $injector)

  EventBus.listen $scope, 'toggleSidebar', (_, show) -> $scope.renderSidebar = true if show
  EventBus.listen $scope, 'loggedIn',                -> $scope.loggedIn()
  EventBus.listen $scope, 'updateCoverPhoto',        -> updateCover()
  EventBus.listen $scope, 'pageError', (_, error) ->
    $scope.pageError = error
    ModalService.forceSignIn() if !AbilityService.isLoggedIn() and error.status == 403
  EventBus.listen $scope, 'currentComponent', (_, options) ->
    $scope.pageError = null
    $scope.links = options.links or {}
    setCurrentComponent(options)

  signIn(AppConfig.bootData, AppConfig.bootData.current_user_id, $scope.loggedIn)

  return

$controller.$inject = ['$scope', '$injector']
angular.module('loomioApp').controller 'RootController', $controller
