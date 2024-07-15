# nlogout Configuration Guide

This guide explains all the configuration options available in the `config.toml` file for nlogout. The configuration file is located at `~/.config/nlogout/config.toml`.

## Table of Contents

1. [Window Configuration](#window-configuration)
2. [Font Configuration](#font-configuration)
3. [Button Configuration](#button-configuration)
4. [Individual Button Configuration](#individual-button-configuration)
5. [Button Order](#button-order)
6. [Programs to Terminate](#programs-to-terminate)
7. [Custom Lock Screen Application](#custom-lock-screen-application)

## Window Configuration

The `[window]` section controls the overall appearance of the nlogout window.

```toml
[window]
width = 740
height = 118
title = "nlogout"
background_color = "#FFFFFF"
```

- `width`: Width of the window in pixels
- `height`: Height of the window in pixels
- `title`: Window title (may be used by some window managers)
- `background_color`: Background color of the window in hex format

## Font Configuration

The `[font]` section determines the text appearance across all buttons.

```toml
[font]
family = "Open Sans"
size = 16
bold = true
```

- `family`: Font family name
- `size`: Font size in points
- `bold`: Whether to use bold font (true/false)

## Button Configuration

The `[button]` section sets global properties for all buttons.

```toml
[button]
width = 100
height = 100
padding = 3
top_padding = 5
icon_size = 32
icon_theme = "sardi-purple"
```

- `width`: Width of each button in pixels
- `height`: Height of each button in pixels
- `padding`: Padding between buttons in pixels
- `top_padding`: Padding at the top of each button in pixels
- `icon_size`: Size of the icon in pixels
- `icon_theme`: Name of the icon theme folder in `~/.config/nlogout/themes/`

## Individual Button Configuration

Each button can be customized individually under its own section. Available buttons are:
- `cancel`
- `logout`
- `reboot`
- `shutdown`
- `suspend`
- `hibernate`
- `lock`

Example configuration for a button:

```toml
[buttons.cancel]
text = "Cancel"
background_color = "#f5e0dc"
text_color = "#363a4f"
shortcut = "Escape"
```

- `text`: Text displayed on the button
- `background_color`: Background color of the button in hex format
- `text_color`: Text color of the button in hex format
- `shortcut`: Keyboard shortcut for the button action

Repeat this section for each button you want to include.

## Button Order

You can specify the order of buttons using the `button_order` key:

```toml
button_order = ["cancel", "lock", "suspend", "hibernate", "logout", "reboot", "shutdown"]
```

List the buttons in the order you want them to appear. If this key is omitted, all configured buttons will be displayed in the order they are defined in the config file.

## Programs to Terminate

Specify programs to terminate before logging out:

```toml
programs_to_terminate = ["example_program1", "example_program2"]
```

List the names of programs that should be terminated when logging out.

## Custom Lock Screen Application

You can set a custom lock screen application:

```toml
lock_screen_app = "i3lock -c 000000"
```

Specify the command to run your preferred lock screen application. If this is not set, the default `loginctl lock-session` will be used.

---

Remember that all settings have default values, so you only need to include the options you want to customize in your `config.toml` file. Any omitted settings will use the built-in defaults.

For icon themes, place your SVG icons in a folder within `~/.config/nlogout/themes/`. The folder name should match the `icon_theme` specified in your configuration.

Example icon structure:
```
~/.config/nlogout/themes/sardi-purple/
    ├── cancel.svg
    ├── logout.svg
    ├── reboot.svg
    ├── shutdown.svg
    ├── suspend.svg
    ├── hibernate.svg
    └── lock.svg
```

Ensure that your icon theme folder contains an SVG file for each button you're using, named exactly as the button key (e.g., `cancel.svg`, `logout.svg`, etc.).