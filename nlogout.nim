import std/[os, osproc, strutils, tables, sequtils]
import nigui
import parsetoml

type
  ButtonConfig = object
    text, icon, shortcut, backgroundColor: string

  Config = object
    buttons: Table[string, ButtonConfig]
    window: WindowConfig
    programsToTerminate: seq[string]
    fontFamily: string
    fontSize: int
    fontColor: string
    buttonWidth: int
    buttonHeight: int
    buttonPadding: int

  WindowConfig = object
    width, height: int
    title, backgroundColor: string

const
  CONFIG_PATH = getHomeDir() / ".config/nlogout/config.toml"
  DEFAULT_CONFIG = Config(
    buttons: {
      "cancel": ButtonConfig(text: "Cancel", icon: "\uF00D", shortcut: "Escape", backgroundColor: "#f5e0dc"),
      "logout": ButtonConfig(text: "Logout", icon: "\uF2F5", shortcut: "L", backgroundColor: "#cba6f7"),
      "reboot": ButtonConfig(text: "Reboot", icon: "\uF021", shortcut: "R", backgroundColor: "#f5c2e7"),
      "shutdown": ButtonConfig(text: "Shutdown", icon: "\uF011", shortcut: "S", backgroundColor: "#f5a97f"),
      "suspend": ButtonConfig(text: "Suspend", icon: "\uF186", shortcut: "U", backgroundColor: "#7dc4e4"),
      "hibernate": ButtonConfig(text: "Hibernate", icon: "\uF0E2", shortcut: "H", backgroundColor: "#a6da95"),
      "lock": ButtonConfig(text: "Lock", icon: "\uF023", shortcut: "K", backgroundColor: "#8aadf4")
    }.toTable,
    window: WindowConfig(width: 600, height: 98, title: "nlogout", backgroundColor: "#FFFFFF"),
    programsToTerminate: @[""],
    fontFamily: "Open Sans",
    fontSize: 16,
    fontColor: "#363a4f",  # Default font color
    buttonWidth: 80,
    buttonHeight: 80,
    buttonPadding: 3
  )
  BUTTON_ORDER = ["cancel", "logout", "reboot", "shutdown", "suspend", "hibernate", "lock"]

proc standardizeKeyName(key: string): string =
  var standardized = key.toLower()
  if standardized.startsWith("key_"):
    standardized = standardized[4..^1]
  case standardized
  of "esc": result = "escape"
  of "return": result = "enter"
  else: result = standardized

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
    result = rgb(0.byte, 0.byte, 0.byte)  # Default to black if invalid hex

proc loadConfig(): Config =
  result = DEFAULT_CONFIG
  if fileExists(CONFIG_PATH):
    let toml = parsetoml.parseFile(CONFIG_PATH)
    if toml.hasKey("window"):
      let windowConfig = toml["window"]
      result.window.width = windowConfig.getOrDefault("width").getInt(800)
      result.window.height = windowConfig.getOrDefault("height").getInt(500)
      result.window.title = windowConfig.getOrDefault("title").getStr("nlogout")
      result.window.backgroundColor = windowConfig.getOrDefault("background_color").getStr("#FFFFFF")
    
    if toml.hasKey("buttons"):
      let buttonConfigs = toml["buttons"]
      for key in BUTTON_ORDER:
        if buttonConfigs.hasKey(key):
          let btnConfig = buttonConfigs[key]
          result.buttons[key] = ButtonConfig(
            text: btnConfig.getOrDefault("text").getStr(result.buttons[key].text),
            icon: btnConfig.getOrDefault("icon").getStr(result.buttons[key].icon),
            shortcut: standardizeKeyName(btnConfig.getOrDefault("shortcut").getStr(result.buttons[key].shortcut)),
            backgroundColor: btnConfig.getOrDefault("background_color").getStr(result.buttons[key].backgroundColor)
          )
    
    if toml.hasKey("programs_to_terminate"):
      result.programsToTerminate = toml["programs_to_terminate"].getElems().mapIt(it.getStr())
    
    if toml.hasKey("font"):
      let fontConfig = toml["font"]
      result.fontFamily = fontConfig.getOrDefault("family").getStr(result.fontFamily)
      result.fontSize = fontConfig.getOrDefault("size").getInt(result.fontSize)
      result.fontColor = fontConfig.getOrDefault("color").getStr(result.fontColor)
    
    if toml.hasKey("button"):
      let buttonConfig = toml["button"]
      result.buttonWidth = buttonConfig.getOrDefault("width").getInt(result.buttonWidth)
      result.buttonHeight = buttonConfig.getOrDefault("height").getInt(result.buttonHeight)
      result.buttonPadding = buttonConfig.getOrDefault("padding").getInt(result.buttonPadding)

proc createButton(cfg: ButtonConfig, config: Config, action: proc()): Control =
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
    canvas.fontBold = true
    canvas.textColor = hexToRgb(config.fontColor)

    let lines = [cfg.icon, cfg.text, "(" & cfg.shortcut & ")"]
    let lineHeight = config.fontSize.float * 1.0
    let totalHeight = lineHeight * lines.len.float
    var y = (buttonHeight - totalHeight) / 2

    for line in lines:
      let textWidth = canvas.getTextWidth(line).float
      let x = (buttonWidth - textWidth) / 2
      canvas.drawText(line, x.int, y.int)
      y += lineHeight

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
    "lock": proc() {.closure.} = discard execCmd("loginctl lock-session")
  }.toTable

  for key in BUTTON_ORDER:
    if key in config.buttons and key in actions:
      var button = createButton(config.buttons[key], config, actions[key])
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
