import std/[os, os, osproc, tables, strutils,  math]
import nlogout_config
import nigui


proc getDesktopEnvironment(): string =
  let xdgCurrentDesktop = getEnv("XDG_CURRENT_DESKTOP").toLower()
  if xdgCurrentDesktop != "":
    return xdgCurrentDesktop
  
  let desktopSession = getEnv("DESKTOP_SESSION").toLower()
  if desktopSession != "":
    return desktopSession
  
  return "unknown"

proc terminate(sApp: string) =
  discard execCmd("pkill " & sApp)

proc getIconPath(config: Config, buttonKey: string): string =
  result = ICON_THEME_PATH / config.iconTheme / (buttonKey & ".svg")
  if not fileExists(result):
    result = ICON_THEME_PATH / "default" / (buttonKey & ".svg")

proc hexToRgb(hex: string): Color =
  var hexColor = hex.strip()
  if hexColor.startsWith("#"):
    hexColor = hexColor[1..^1]
  if hexColor.len == 6:
    let
      r = byte(parseHexInt(hexColor[0..1]))
      g = byte(parseHexInt(hexColor[2..3]))
      b = byte(parseHexInt(hexColor[4..5]))
    result = rgb(r, g, b)
  else:
    result = rgb(0.byte, 0.byte, 0.byte)

###############################################################################
proc drawRoundedRect(canvas: Canvas, x, y, width, height, radius: float, color: Color) =
  canvas.areaColor = color

  # Draw main rectangle
  canvas.drawRectArea(x.int, y.int + radius.int, width.int, (height - radius*2).int)
  canvas.drawRectArea(x.int + radius.int, y.int, (width - radius*2).int, height.int)

  # Draw corners
  let segments = 90  # Use more segments for smoother corners
  for i in 0..segments:
    let angle = i.float / segments.float * PI / 2
    let px = radius * cos(angle)
    let py = radius * sin(angle)

    # Top-left corner
    canvas.drawRectArea(
      (x + radius - px).int,
      (y + radius - py).int,
      1, 1
    )

    # Top-right corner
    canvas.drawRectArea(
      (x + width - radius + px - 1).int,
      (y + radius - py).int,
      1, 1
    )

    # Bottom-left corner
    canvas.drawRectArea(
      (x + radius - px).int,
      (y + height - radius + py - 1).int,
      1, 1
    )

    # Bottom-right corner
    canvas.drawRectArea(
      (x + width - radius + px - 1).int,
      (y + height - radius + py - 1).int,
      1, 1
    )

  # Fill in the gaps
  canvas.drawRectArea(x.int, y.int + radius.int, radius.int, 1)
  canvas.drawRectArea(x.int + width.int - radius.int, y.int + radius.int, radius.int, 1)
  canvas.drawRectArea(x.int, y.int + height.int - radius.int - 1, radius.int, 1)
  canvas.drawRectArea(x.int + width.int - radius.int, y.int + height.int - radius.int - 1, radius.int, 1)


###############################################################################

#proc drawRoundedRect(canvas: Canvas, x, y, width, height, radius: float, color: Color) =
#  canvas.areaColor = color
  
#  # Draw main rectangle
#  canvas.drawRectArea(x.int + radius.int, y.int, (width - radius*2).int, height.int)
#  canvas.drawRectArea(x.int, y.int + radius.int, width.int, (height - radius*2).int)
  
#  # Draw corners
#  let segments = 400 # Increase number of segments for smoother corners
#  for i in 0..segments:
#    let angle1 = i.float / segments.float * PI / 2
#    let angle2 = (i + 1).float / segments.float * PI / 2
    
#    # Helper function to draw a segment with slight overlap
#    proc drawSegment(centerX, centerY: float, flipX, flipY: bool) =
#      let x1 = centerX + (if flipX: 1 else: -1) * radius * cos(angle1)
#      let y1 = centerY + (if flipY: 1 else: -1) * radius * sin(angle1)
#      let x2 = centerX + (if flipX: 1 else: -1) * radius * cos(angle2)
#      let y2 = centerY + (if flipY: 1 else: -1) * radius * sin(angle2)
      
#      let rectX = min(x1, x2).floor.int
#      let rectY = min(y1, y2).floor.int
#      let rectWidth = (max(x1, x2) - min(x1, x2)).ceil.int + 2  # +2 for overlap
#      let rectHeight = (max(y1, y2) - min(y1, y2)).ceil.int + 2  # +2 for overlap
      
#      canvas.drawRectArea(rectX, rectY, rectWidth, rectHeight)
    
#    # Top-left corner
#    drawSegment(x + radius, y + radius, false, false)
    
#    # Top-right corner
#    drawSegment(x + width - radius, y + radius, true, false)
    
#    # Bottom-left corner
#    drawSegment(x + radius, y + height - radius, false, true)
    
#    # Bottom-right corner
#    drawSegment(x + width - radius, y + height - radius, true, true)

##################################################################################

proc createButton(cfg: ButtonConfig, config: Config, buttonKey: string, action: proc()): Control =
  var button = newControl()
  button.width = config.buttonWidth
  button.height = config.buttonHeight

  button.onDraw = proc(event: DrawEvent) =
    let canvas = event.control.canvas
    let buttonWidth = button.width.float
    let buttonHeight = button.height.float

    if config.roundedCorners:
      drawRoundedRect(canvas, 0, 0, buttonWidth, buttonHeight, config.cornerRadius.float, hexToRgb(cfg.backgroundColor))
    else:
      canvas.areaColor = hexToRgb(cfg.backgroundColor)
      canvas.drawRectArea(0, 0, buttonWidth.int, buttonHeight.int)

    canvas.fontFamily = config.fontFamily
    canvas.fontSize = config.fontSize.float
    canvas.fontBold = config.fontBold
    canvas.textColor = hexToRgb(cfg.textColor)

    var y = config.buttonTopPadding.float

    # Draw icon
    let iconPath = getIconPath(config, buttonKey)
    if fileExists(iconPath):
      var icon = newImage()
      icon.loadFromFile(iconPath)
      let iconX = (buttonWidth - config.iconSize.float) / 2
      let iconY = y
      canvas.drawImage(icon, iconX.int, iconY.int, config.iconSize, config.iconSize)
      y += config.iconSize.float + 5  # Add some padding after the icon

    # Draw text
    let textWidth = canvas.getTextWidth(cfg.text).float
    let textX = (buttonWidth - textWidth) / 2
    canvas.drawText(cfg.text, textX.int, y.int)
    y += config.fontSize.float + 5  # Add some padding after the text

    # Draw shortcut
    let shortcutText = "(" & cfg.shortcut & ")"
    let shortcutWidth = canvas.getTextWidth(shortcutText).float
    let shortcutX = (buttonWidth - shortcutWidth) / 2
    canvas.drawText(shortcutText, shortcutX.int, y.int)

  button.onClick = proc(event: ClickEvent) =
    action()

  return button


proc main() =
  let config = loadConfig()
  app.init()

  var window = newWindow()
  window.width = config.window.width
  window.height = config.window.height
  window.title = config.window.title

  var container = newLayoutContainer(Layout_Vertical)
  container.widthMode = WidthMode_Fill
  container.heightMode = HeightMode_Fill

  container.onDraw = proc (event: DrawEvent) =
    let canvas = event.control.canvas
    canvas.areaColor = hexToRgb(config.window.backgroundColor)
    canvas.drawRectArea(0, 0, window.width, window.height)

  window.add(container)

  # Top spacer
  var spacerTop = newControl()
  spacerTop.widthMode = WidthMode_Fill
  spacerTop.heightMode = HeightMode_Expand
  container.add(spacerTop)

  # Button container
  var buttonContainer = newLayoutContainer(Layout_Horizontal)
  buttonContainer.widthMode = WidthMode_Fill
  buttonContainer.height = config.buttonHeight + (2 * config.buttonPadding)

  buttonContainer.onDraw = proc (event: DrawEvent) =
    let canvas = event.control.canvas
    canvas.areaColor = hexToRgb(config.window.backgroundColor)
    canvas.drawRectArea(0, 0, buttonContainer.width, buttonContainer.height)
    
  container.add(buttonContainer)

  # Left spacer in button container
  var spacerLeft = newControl()
  spacerLeft.widthMode = WidthMode_Expand
  spacerLeft.heightMode = HeightMode_Fill
  buttonContainer.add(spacerLeft)

  proc logout() {.closure.} =
    for program in config.programsToTerminate:
      terminate(program)
    let desktop = getDesktopEnvironment()
    terminate(desktop)
    quit(0)

  let actions = {
    "cancel": proc() {.closure.} = app.quit(),
    "logout": logout,
    "reboot": proc() {.closure.} = discard execCmd("systemctl reboot"),
    "shutdown": proc() {.closure.} = discard execCmd("systemctl poweroff"),
    "suspend": proc() {.closure.} = discard execCmd("systemctl suspend"),
    "hibernate": proc() {.closure.} = discard execCmd("systemctl hibernate"),
    "lock": proc() {.closure.} = 
      if config.lockScreenApp != "":
        discard execCmd(config.lockScreenApp)
      else:
        discard execCmd("loginctl lock-session")
  }.toTable

  for i, key in config.buttonOrder:
    if key in config.buttons and key in actions:
      if i > 0:  # Add spacing between buttons, but not before the first button
        var spacing = newControl()
        spacing.width = config.buttonPadding
        buttonContainer.add(spacing)
      
      var button = createButton(config.buttons[key], config, key, actions[key])
      buttonContainer.add(button)

  # Right spacer in button container
  var spacerRight = newControl()
  spacerRight.widthMode = WidthMode_Expand
  spacerRight.heightMode = HeightMode_Fill
  buttonContainer.add(spacerRight)

  # Bottom spacer
  var spacerBottom = newControl()
  spacerBottom.widthMode = WidthMode_Fill
  spacerBottom.heightMode = HeightMode_Expand
  container.add(spacerBottom)

  window.onKeyDown = proc(event: KeyboardEvent) =
    let keyString = standardizeKeyName($event.key)
    for key, cfg in config.buttons:
      let standardizedShortcut = standardizeKeyName(cfg.shortcut)
      if standardizedShortcut == keyString:
        if key in actions:
          actions[key]()
          return

  window.show()
  app.run()

main()
