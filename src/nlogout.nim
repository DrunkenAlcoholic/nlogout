import std/[os, osproc, strutils, tables, sequtils]
import nigui
import parsetoml

type
  ButtonConfig = object
    text, shortcut, backgroundColor, textColor: string

  WindowConfig = object
    width, height: int
    title, backgroundColor: string

  Config = object
    buttons: Table[string, ButtonConfig]
    buttonOrder: seq[string]
    window: WindowConfig
    programsToTerminate: seq[string]
    fontFamily: string
    fontSize: int
    fontBold: bool
    buttonWidth: int
    buttonHeight: int
    buttonPadding: int
    buttonTopPadding: int
    iconSize: int
    iconTheme: string
    lockScreenApp: string

const
  CONFIG_PATH = getHomeDir() / ".config/nlogout/config.toml"
  ICON_THEME_PATH = getHomeDir() / ".config/nlogout/themes"
  DEFAULT_BUTTON_ORDER = @["cancel", "logout", "reboot", "shutdown", "suspend", "hibernate", "lock"]
  DEFAULT_CONFIG = Config(
    buttons: {
      "cancel": ButtonConfig(text: "Cancel", shortcut: "Escape", backgroundColor: "#f5e0dc", textColor: "#363a4f"),
      "logout": ButtonConfig(text: "Logout", shortcut: "L", backgroundColor: "#cba6f7", textColor: "#363a4f"),
      "reboot": ButtonConfig(text: "Reboot", shortcut: "R", backgroundColor: "#f5c2e7", textColor: "#363a4f"),
      "shutdown": ButtonConfig(text: "Shutdown", shortcut: "S", backgroundColor: "#f5a97f", textColor: "#363a4f"),
      "suspend": ButtonConfig(text: "Suspend", shortcut: "U", backgroundColor: "#7dc4e4", textColor: "#363a4f"),
      "hibernate": ButtonConfig(text: "Hibernate", shortcut: "H", backgroundColor: "#a6da95", textColor: "#363a4f"),
      "lock": ButtonConfig(text: "Lock", shortcut: "K", backgroundColor: "#8aadf4", textColor: "#363a4f")
    }.toTable,
    buttonOrder: DEFAULT_BUTTON_ORDER,
    window: WindowConfig(width: 600, height: 98, title: "nlogout", backgroundColor: "#313244"),
    programsToTerminate: @[""],
    fontFamily: "Noto Sans Mono",
    fontSize: 14,
    fontBold: true,
    buttonWidth: 80,
    buttonHeight: 80,
    buttonPadding: 3,
    buttonTopPadding: 3,
    iconSize: 32,
    iconTheme: "default",
    lockScreenApp: "loginctl lock-session"
  )

proc standardizeKeyName(key: string): string =
  result = key.toLower()
  if result.startsWith("key_"):
    result = result[4..^1]
  if result == "esc": result = "escape"
  elif result == "return": result = "enter"

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

proc loadConfig(): Config =
  result = DEFAULT_CONFIG
  if fileExists(CONFIG_PATH):
    let toml = parsetoml.parseFile(CONFIG_PATH)
    if toml.hasKey("window"):
      let windowConfig = toml["window"]
      result.window.width = windowConfig.getOrDefault("width").getInt(result.window.width)
      result.window.height = windowConfig.getOrDefault("height").getInt(result.window.height)
      result.window.title = windowConfig.getOrDefault("title").getStr(result.window.title)
      result.window.backgroundColor = windowConfig.getOrDefault("background_color").getStr(result.window.backgroundColor)
    
    if toml.hasKey("font"):
      let fontConfig = toml["font"]
      result.fontFamily = fontConfig.getOrDefault("family").getStr(result.fontFamily)
      result.fontSize = fontConfig.getOrDefault("size").getInt(result.fontSize)
      result.fontBold = fontConfig.getOrDefault("bold").getBool(result.fontBold)
    
    if toml.hasKey("button"):
      let buttonConfig = toml["button"]
      result.buttonWidth = buttonConfig.getOrDefault("width").getInt(result.buttonWidth)
      result.buttonHeight = buttonConfig.getOrDefault("height").getInt(result.buttonHeight)
      result.buttonPadding = buttonConfig.getOrDefault("padding").getInt(result.buttonPadding)
      result.buttonTopPadding = buttonConfig.getOrDefault("top_padding").getInt(result.buttonTopPadding)
      result.iconSize = buttonConfig.getOrDefault("icon_size").getInt(result.iconSize)
      result.iconTheme = buttonConfig.getOrDefault("icon_theme").getStr(result.iconTheme)

    var configuredButtons: Table[string, ButtonConfig]
    if toml.hasKey("buttons"):
      let buttonConfigs = toml["buttons"]
      if buttonConfigs.kind == TomlValueKind.Table:
        for key, value in buttonConfigs.getTable():
          if value.kind == TomlValueKind.Table:
            let btnConfig = value.getTable()
            configuredButtons[key] = ButtonConfig(
              text: btnConfig.getOrDefault("text").getStr(DEFAULT_CONFIG.buttons.getOrDefault(key).text),
              shortcut: standardizeKeyName(btnConfig.getOrDefault("shortcut").getStr(DEFAULT_CONFIG.buttons.getOrDefault(key).shortcut)),
              backgroundColor: btnConfig.getOrDefault("background_color").getStr(DEFAULT_CONFIG.buttons.getOrDefault(key).backgroundColor),
              textColor: btnConfig.getOrDefault("text_color").getStr(DEFAULT_CONFIG.buttons.getOrDefault(key).textColor)
            )

    result.buttons = configuredButtons

    if toml.hasKey("button_order"):
      let orderArray = toml["button_order"]
      if orderArray.kind == TomlValueKind.Array:
        result.buttonOrder = @[]
        for item in orderArray.getElems():
          if item.kind == TomlValueKind.String:
            let key = item.getStr()
            if key in configuredButtons:
              result.buttonOrder.add(key)
    elif configuredButtons.len > 0:
      # If no button_order is specified, use all configured buttons
      result.buttonOrder = toSeq(configuredButtons.keys)
    else:
      # If no buttons are configured, use the default order
      result.buttonOrder = DEFAULT_BUTTON_ORDER

    if toml.hasKey("programs_to_terminate"):
      result.programsToTerminate = toml["programs_to_terminate"].getElems().mapIt(it.getStr())

    if toml.hasKey("lock_screen_app"):
      result.lockScreenApp = toml["lock_screen_app"].getStr(result.lockScreenApp)

proc getIconPath(config: Config, buttonKey: string): string =
  result = ICON_THEME_PATH / config.iconTheme / (buttonKey & ".svg")
  if not fileExists(result):
    result = ICON_THEME_PATH / "default" / (buttonKey & ".svg")

proc createButton(cfg: ButtonConfig, config: Config, buttonKey: string, action: proc()): Control =
  var button = newControl()
  button.width = config.buttonWidth
  button.height = config.buttonHeight

  button.onDraw = proc(event: DrawEvent) =
    let canvas = event.control.canvas
    let buttonWidth = button.width.float
    let buttonHeight = button.height.float

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

  for key in config.buttonOrder:
    if key in config.buttons and key in actions:
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