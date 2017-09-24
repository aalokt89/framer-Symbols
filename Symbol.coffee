copySourceToTarget = (source, target=false) ->
  if source.children.length > 0
    for subLayer in source.descendants
      target[subLayer.name] = subLayer.copySingle()

      target[subLayer.name].props = subLayer.props
      target[subLayer.name].name = subLayer.name

      if subLayer.__framerInstanceInfo.framerClass == "TextLayer"
        target[subLayer.name].textAlign = subLayer.props.styledTextOptions.alignment

      if subLayer.__framerInstanceInfo.framerClass == "SVGLayer"
        target[subLayer.name]._DefinedPropertiesValuesKey = subLayer._DefinedPropertiesValuesKey
        target[subLayer.name]._element = subLayer._element
        target[subLayer.name]._elementHTML = subLayer._elementHTML

      if subLayer.parent is source
        target[subLayer.name].parent = target
      else
        target[subLayer.name].parent = target[subLayer.parent.name]

copyStatesFromTarget = (source, target, stateName, animationOptions=false) ->
  targets = []

  for layer in target.descendants
    targets[layer.name] = layer

  for subLayer in source.descendants
    subLayer.states["#{stateName}"] = targets[subLayer.name].states["default"]

    if animationOptions
      subLayer.states["#{stateName}"].animationOptions = animationOptions

Layer::addSymbolState = (stateName, target, animationOptions=false) ->
  @.states["#{stateName}"] = target.states["default"]
  @.states["#{stateName}"].x = @.x
  @.states["#{stateName}"].y = @.y

  if animationOptions
    @.states["#{stateName}"].animationOptions = animationOptions

  copyStatesFromTarget(@, target, stateName, animationOptions)
  target.destroy()

Layer::replaceWithSymbol = (symbol) ->
  symbol.point = @.point
  symbol.parent = @.parent

  for stateName in symbol.stateNames
    symbol.states["#{stateName}"].point = @.point
  @.destroy()

exports.Symbol = (layer, states=false, events=false) ->
  class Symbol extends Layer
    constructor: (options={}) ->
      options.backgroundColor ?= layer.backgroundColor
      options.image ?= layer.image
      options.opacity ?= layer.props.opacity
      options.borderWidth ?= layer.props.borderWidth
      options.borderColor ?= layer.props.borderColor
      options.borderRadius ?= layer.props.borderRadius
      options.shadowSpread ?= layer.props.shadowSpread
      options.shadowX ?= layer.props.shadowX
      options.shadowY ?= layer.props.shadowY
      options.shadowBlur ?= layer.props.shadowBlur
      options.shadowColor ?= layer.props.shadowColor
      options.scale ?= layer.props.scale
      options.scaleX ?= layer.props.scaleX
      options.scaleY ?= layer.props.scaleY
      options.rotation ?= layer.props.rotation
      options.rotationX ?= layer.props.rotationX
      options.rotationY ?= layer.props.rotationY
      options.originX ?= layer.props.originX
      options.originY ?= layer.props.originY
      options.skewX ?= layer.props.skewX
      options.skewY ?= layer.props.skewY

      options.x ?= false
      options.y ?= false

      super options

      @.props = layer.props

      @.name = options.name
      @.size = options.size
      @.image = options.image
      @.backgroundColor = options.backgroundColor
      @.opacity = options.opacity
      @.borderWidth = options.borderWidth
      @.borderColor = options.borderColor
      @.borderRadius = options.borderRadius
      @.shadowSpread = options.shadowSpread
      @.shadowX = options.shadowX
      @.shadowY = options.shadowY
      @.shadowBlur = options.shadowBlur
      @.shadowColor = options.shadowColor
      @.scale = options.scale
      @.scaleX = options.scaleX
      @.scaleY = options.scaleY
      @.rotation = options.rotation
      @.rotationX = options.rotationX
      @.rotationY = options.rotationY
      @.originX = options.originX
      @.originY = options.originY
      @.skewX = options.skewX
      @.skewY = options.skewY

      @.x = options.x
      @.y = options.y

      @.customProps = options.customProps

      @.states['default'].x = @.x
      @.states['default'].y = @.y

      copySourceToTarget(layer, @)

      if states
        for stateName, stateProps of states
          @.addSymbolState(stateName, stateProps.template, stateProps.animationOptions)

      if events
        for trigger, action of events
          if _.isFunction(action)
            if Events[trigger]
              @on Events[trigger], action
          else
            if @[trigger]
              for triggerName, actionProps of action
                if Events[triggerName]
                  @[trigger].on Events[triggerName], actionProps

      # Reset position for each state to position defined in options
      for stateName in @.stateNames
        @.states["#{stateName}"].x = options.x
        @.states["#{stateName}"].y = options.y

      @.on Events.StateSwitchStart, (from, to) ->
        for child in @.descendants
          if child.constructor.name == "TextLayer"
            child.states[to].text = child.text
            child.states[to].textAlign = child.props.styledTextOptions.alignment
            child.states[to].width = child.width
            child.states[to].height = child.height

            if Object.keys(child.template).length > 0
              child.states[to].template = child.template

          else
            if child.image && (child.states[to].image != child.image)
              child.states[to].image = child.image

          child.animate to

    layer.destroy()

# A backup for the deprecated way of calling the class
exports.createSymbol = (layer, states) -> exports.Symbol(layer, states)
