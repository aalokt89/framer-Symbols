removeIds = (htmlString) ->
  ids = Utils.getIdAttributesFromString(htmlString)
  for id in ids
    htmlString = htmlString.replace(/ id="(.*?)"/g, "") ;
  return htmlString

copySourceToTarget = (source, target = false) ->
  if source.children.length > 0
    for subLayer in source.descendants
      if subLayer.constructor.name is "SVGLayer"
        if subLayer.html? and subLayer.svg?
          delete subLayer.svg
        subLayer.html = removeIds(subLayer.html)
        target[subLayer.name] = subLayer.copy()
      else if subLayer.constructor.name is "SVGPath" or subLayer.constructor.name is "SVGGroup"
        svgCopy = subLayer._svgLayer.copy()
        target[subLayer.name] = svgCopy
      else
        target[subLayer.name] = subLayer.copySingle()

      target[subLayer.name].name = subLayer.name

      if subLayer.parent is source
        target[subLayer.name].parent = target
      else
        target[subLayer.name].parent = target[subLayer.parent.name]

      if target[subLayer.name].constructor.name isnt "SVGLayer"
        target[subLayer.name].constraintValues = subLayer.constraintValues
        target[subLayer.name].layout()

      # Create reference to the symbol instance
      target[subLayer.name]._instance = target

# Copies default-state of target and applies it to the symbol's descendants
copyStatesFromTarget = (source, target, stateName, animationOptions = false) ->
  targets = []

  for layer in target.descendants
    targets[layer.name] = layer

  for subLayer in source.descendants
    if subLayer.constructor.name is "SVGLayer"
      delete targets[subLayer.name].states.default.html

    if subLayer.constructor.name is "SVGPath" or subLayer.constructor.name is "SVGGroup"
      subLayer._svgLayer.states["#{stateName}"] = targets[subLayer.name]._svgLayer.states.default

    subLayer.states["#{stateName}"] = targets[subLayer.name].states.default

    if animationOptions
      subLayer.states["#{stateName}"].animationOptions = animationOptions

      # Also add the animationOptions to the "parent" SVGLayer of a SVGPath or SVGGroup
      if subLayer.constructor.name is "SVGPath" or subLayer.constructor.name is "SVGGroup"
        subLayer._svgLayer.states["#{stateName}"].animationOptions = animationOptions

Layer::replaceWithSymbol = (symbol) ->
  throw "Error: layer.replaceWithSymbol(symbolInstance) is deprecated - use symbolInstance.replaceLayer(layer) instead."
  # symbol.replaceLayer @

exports.Symbol = (layer, states = false, events = false) ->
  class Symbol extends Layer
    constructor: (@options = {} ) ->
      @options.x ?= 0
      @options.y ?= 0
      @options.replaceLayer ?= false

      super _.defaults @options, layer.props

      for child in layer.descendants
        @[child.name] = child

        for key, props of @options
          if key is child.name
            for prop, value of props
              @[key][prop] = value

      @.customProps = @options.customProps

      copySourceToTarget(layer, @)
      copyStatesFromTarget(@, layer, 'default', false)

      if @options.replaceLayer
        @.replaceLayer @options.replaceLayer

      # Apply states to symbol if supplied
      if states
        for stateName, stateProps of states
          # Filter animationOptions out of states and apply them to symbol
          if stateName is "animationOptions"
            @.animationOptions = stateProps
            for descendant in @.descendants
              descendant.animationOptions = @.animationOptions
          else
            # If there's no template supplied
            if !stateProps.template
              throw "Error: You need to supply a template-layer for each state."
            # Add the new symbol-state
            else
              @.addSymbolState(stateName, stateProps.template, stateProps.animationOptions)

          # Change the x,y position of a symbol inside commonStates
          if typeof stateProps.x != 'undefined'
            @.states["#{stateName}"].x = stateProps.x
          if typeof stateProps.y != 'undefined'
            @.states["#{stateName}"].y = stateProps.y

      # Apply events to symbol if supplied
      if events
        for trigger, action of events
          # if event listener is applied to the symbol-instance
          if _.isFunction(action)
            if Events[trigger]
              @on Events[trigger], action
          # if event listener is applied to a symbol's descendant
          else
            if @[trigger]
              for triggerName, actionProps of action
                if Events[triggerName]
                  @[trigger].on Events[triggerName], actionProps

      # Prevent weird glitches by switching SVGs to "default" state directly
      for child in @.descendants
        if child.constructor.name is "SVGLayer" or child.constructor.name is "SVGPath" or child.constructor.name is "SVGGroup"
          child.stateSwitch "default"

      # Handle the stateSwitch for all descendants
      @.on Events.StateSwitchStart, (from, to) ->
        for child in @.descendants
          # Special handling for TextLayers
          if child.constructor.name == "TextLayer"
            child.states[to].text = child.text
            child.states[to].textAlign = child.props.styledTextOptions.alignment
            child.states[to].width = child.width
            child.states[to].height = child.height

            if child.template && Object.keys(child.template).length > 0
              child.states[to].template = child.template

          else
            if child.image && (child.states[to].image != child.image)
              child.states[to].image = child.image

          # Kickstart the stateSwitch
          child.animate to

    # Destroy default template layer
    layer.destroy()

    # Destroy state template layers
    if states
      for stateName, stateProps of states
        if stateProps.template
          stateProps.template.destroy()

    # Adds a new state
    addSymbolState: (stateName, target, animationOptions = false) ->
      # Delete x,y props from templates default state
      delete target.states.default[prop] for prop in ['x', 'y']

      # Create a new state for the symbol and assign remaining props
      @.states["#{stateName}"] = target.states.default

      # Assign animationOptions to the state if supplied
      if animationOptions
        @.states["#{stateName}"].animationOptions = animationOptions

      copyStatesFromTarget(@, target, stateName, animationOptions)

    # Replacement for replaceWithSymbol()
    replaceLayer: (layer) ->
      @.parent = layer.parent
      @.x = layer.x
      @.y = layer.y
      @.states.default.x = @.x
      @.states.default.y = @.y

      layer.destroy()

# A backup for the deprecated way of calling the class
exports.createSymbol = (layer, states, events) -> exports.Symbol(layer, states, events)
