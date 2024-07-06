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
      "cancel": ButtonConfig(text: "Cancel", icon: "\uF00D", shortcut: "Escape", backgroundColor: "#FFFFFF"),
      "logout": ButtonConfig(text: "Logout", icon: "\uF2F5", shortcut: "L", backgroundColor: "#FFFFFF"),
      "reboot": ButtonConfig(text: "Reboot", icon: "\uF021", shortcut: "R", backgroundColor: "#FFFFFF"),
      "shutdown": ButtonConfig(text: "Shutdown", icon: "\uF011", shortcut: "S", backgroundColor: "#FFFFFF"),
      "suspend": ButtonConfig(text: "Suspend", icon: "\uF186", shortcut: "U", backgroundColor: "#FFFFFF"),
      "hibernate": ButtonConfig(text: "Hibernate", icon: "\uF0E2", shortcut: "H", backgroundColor: "#FFFFFF"),
      "lock": ButtonConfig(text: "Lock", icon: "\uF023", shortcut: "K", backgroundColor: "#FFFFFF")
    }.toTable,
    window: WindowConfig(width: 800, height: 500, title: "nlogout", backgroundColor: "#FFFFFF"),
    programsToTerminate: @["NimdowStatus"],
    fontFamily: "Arial",
    fontSize: 16,
    fontColor: "#000000",  # Default font color
    buttonWidth: 120,
    buttonHeight: 200,
    buttonPadding: 5
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
  button.widthMode = WidthMode_Fill
  button.heightMode = HeightMode_Fill

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
  container.spacing = config.buttonPadding
  container.padding = config.buttonPadding
  container.widthMode = WidthMode_Fill
  container.heightMode = HeightMode_Fill
  window.add(container)

  var buttonContainer = newLayoutContainer(Layout_Horizontal)
  buttonContainer.widthMode = WidthMode_Fill
  buttonContainer.heightMode = HeightMode_Fill
  buttonContainer.spacing = config.buttonPadding
  container.add(buttonContainer)

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
      var buttonWrapper = newLayoutContainer(Layout_Vertical)
      buttonWrapper.widthMode = WidthMode_Expand
      buttonWrapper.heightMode = HeightMode_Fill
      buttonWrapper.backgroundColor = hexToRgb(config.window.backgroundColor)

      var button = createButton(config.buttons[key], config, actions[key])
      button.widthMode = WidthMode_Fill
      button.heightMode = HeightMode_Fill
      buttonWrapper.add(button)

      buttonContainer.add(buttonWrapper)

  window.onKeyDown = proc(event: KeyboardEvent) =
    let keyString = standardizeKeyName($event.key)
    echo "Standardized key pressed: ", keyString  # Debug output
    for key, cfg in config.buttons:
      let standardizedShortcut = standardizeKeyName(cfg.shortcut)
      echo "Checking against shortcut: ", standardizedShortcut  # Debug output
      if standardizedShortcut == keyString:
        echo "Matched shortcut: ", key  # Debug output
        if key in actions:
          actions[key]()
          return

  window.show()
  app.run()

main()
