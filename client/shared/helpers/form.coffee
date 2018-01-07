EventBus       = require 'shared/services/event_bus.coffee'
AbilityService = require 'shared/services/ability_service.coffee'
Records        = require 'shared/services/records.coffee'
Session        = require 'shared/services/session.coffee'
FlashService   = require 'shared/services/flash_service.coffee'

{ signIn }            = require 'shared/helpers/user.coffee'
{ fieldFromTemplate } = require 'shared/helpers/poll.coffee'
{ scrollTo }          = require 'shared/helpers/layout.coffee'

# a helper to aid submitting forms throughout the app
module.exports =
  submitForm: (scope, model, options = {}) ->
    submit(scope, model, options)

  submitOutcome: (scope, model, options = {}) ->
    submit(scope, model, _.merge(
      flashSuccess: "poll_common_outcome_form.outcome_#{actionName(model)}"
      failureCallback: ->
        scrollTo '.lmo-validation-error__message', container: '.poll-common-modal'
      successCallback: (data) ->
        EventBus.emit scope, 'outcomeSaved', data.outcomes[0].id
    , options))

  submitStance: (scope, model, options = {}) ->
    submit(scope, model, _.merge(
      flashSuccess: "poll_#{model.poll().pollType}_vote_form.stance_#{actionName(model)}"
      prepareFn: ->
        EventBus.emit scope, 'processing'
      successCallback: (data) ->
        model.poll().clearStaleStances()
        scrollTo '.poll-common-card__results-shown'
        EventBus.emit scope, 'stanceSaved'
        signIn(data, data.stances[0].participant_id, -> EventBus.emit scope, 'loggedIn') unless Session.user().emailVerified
      cleanupFn: ->
        EventBus.emit scope, 'doneProcessing'
    , options))

  submitPoll: (scope, model, options = {}) ->
    submit(scope, model, _.merge(
      flashSuccess: "poll_#{model.pollType}_form.#{model.pollType}_#{actionName(model)}"
      prepareFn: =>
        EventBus.emit scope, 'processing'
        switch model.pollType
          # for polls with default poll options (proposal, check)
          when 'proposal', 'count'
            model.pollOptionNames = _.pluck fieldFromTemplate(model.pollType, 'poll_options_attributes'), 'name'
          # for polls with user-specified poll options (poll, dot_vote, ranked_choice, meeting
          else
            EventBus.broadcast scope, 'addPollOption'
      failureCallback: ->
        scrollTo '.lmo-validation-error__message', container: '.poll-common-modal'
      successCallback: (data) ->
        _.invoke Records.documents.find(model.removedDocumentIds), 'remove'
        poll = Records.polls.find(data.polls[0].key)
        poll.removeOrphanOptions()
        EventBus.emit scope, 'nextStep', poll
      cleanupFn: ->
        EventBus.emit scope, 'doneProcessing'
    , options))

  upload: (scope, model, options = {}) ->
    (files) ->
      if _.any files
        prepare(scope, model, options)
        options.submitFn(files[0], options.uploadKind).then(
          success(scope, model, options),
          failure(scope, model, options)
        ).finally(
          cleanup(scope, model, options)
        )

submit = (scope, model, options = {}) ->
  # fetch draft from server and listen for changes to it
  if model.hasDrafts and model.isNew() and AbilityService.isLoggedIn()
    model.fetchAndRestoreDraft()
    EventBus.watch scope, model.draftFields, model.planDraftFetch, true

  submitFn  = options.submitFn  or model.save
  confirmFn = options.confirmFn or (-> false)
  (prepareArgs) ->
    return if scope.isDisabled
    prepare(scope, model, options, prepareArgs)
    if confirm(confirmFn(model))
      submitFn(model).then(
        success(scope, model, options),
        failure(scope, model, options),
      ).finally(
        cleanup(scope, model, options)
      )
    else
      cleanup(scope, model, options)

prepare = (scope, model, options, prepareArgs) ->
  FlashService.loading(options.loadingMessage)
  options.prepareFn(prepareArgs) if typeof options.prepareFn is 'function'
  EventBus.emit scope, 'processing'
  scope.isDisabled = true
  model.setErrors()

confirm = (confirmMessage) ->
  if confirmMessage and typeof window.confirm == 'function'
    window.confirm(confirmMessage)
  else
    true

success = (scope, model, options) ->
  (data) ->
    FlashService.dismiss()
    if options.flashSuccess?
      flashKey     = if typeof options.flashSuccess is 'function' then options.flashSuccess() else options.flashSuccess
      FlashService.success flashKey, calculateFlashOptions(options.flashOptions)
    scope.$close()                if !options.skipClose? and typeof scope.$close is 'function'
    model.cancelDraftFetch()      if typeof model.cancelDraftFetch is 'function'
    options.successCallback(data) if typeof options.successCallback is 'function'

failure = (scope, model, options) ->
  (response) ->
    FlashService.dismiss()
    options.failureCallback(response)                       if typeof options.failureCallback is 'function'
    response.json().then (r) -> model.setErrors(r.errors)   if _.contains([401,422], response.status)
    EventBus.emit scope, errorTypes[response.status] or 'unknownError',
      model: model
      response: response

cleanup = (scope, model, options = {}) ->
  ->
    options.cleanupFn(scope, model) if typeof options.cleanupFn is 'function'
    EventBus.emit scope, 'doneProcessing'
    scope.isDisabled = false

calculateFlashOptions = (options) ->
  _.each _.keys(options), (key) ->
    options[key] = options[key]() if typeof options[key] is 'function'
  options

actionName = (model) ->
  if model.isNew() then 'created' else 'updated'

errorTypes =
  400: 'badRequest'
  401: 'unauthorizedRequest'
  403: 'forbiddenRequest'
  404: 'resourceNotFound'
  422: 'unprocessableEntity'
  500: 'internalServerError'
