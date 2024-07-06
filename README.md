# nlogout

`nlogout` is a GUI application that provides a configurable logout/power management menu. It uses a `config.toml` file located in the user's `.config/nlogout` directory to customize the application's appearance and functionality, the application is written in Nim.

## Configuration

The `config.toml` file allows you to configure the following aspects of the `nlogout` application:

### Window

- `width`: The width of the application window (in pixels).
- `height`: The height of the application window (in pixels).
- `title`: The title of the application window.
- `background_color`: The background color of the application window (in hex format).

### Font

- `family`: The font family used in the application.
- `size`: The font size used in the application.

### Buttons

- `width`: The width of the buttons (in pixels).
- `height`: The height of the buttons (in pixels).
- `padding`: The padding around the buttons (in pixels).

Each button can be configured with the following options:

- `text`: The text displayed on the button.
- `icon`: The Unicode icon displayed on the button.
- `shortcut`: The keyboard shortcut associated with the button.
- `color`: The text color of the button (in hex format).
- `background_color`: The background color of the button (in hex format).

The available buttons are:

- `cancel`
- `logout`
- `reboot`
- `shutdown`
- `suspend`
- `hibernate`
- `lock`

Additionally, the `programs_to_terminate` setting specifies a list of programs that should be terminated when logging out, this ensures there is only one instance when logging back in.

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/DrunkenAlcoholic/nlogout.git
   ```
2. Install the required dependencies, including the `nigui` library for creating the GUI.
   ```bash
   nimble install nigui@#head
   nimble install parsetoml
   ```
3. Compile the application
   ```bash
   nim c -d:release nlogout.nim
   ```
4. Copy the config.toml to ~/.config/nlogout   
   


## Usage

1. Customize the `config.toml` file in the `.config/nlogout` directory to match your preferences.
2. Run the `nlogout` application.
3. Click on the desired button to perform the corresponding action (logout, reboot, shutdown, etc.).

## Contributing

If you find any issues or have suggestions for improvements, please feel free to open an issue or submit a pull request.
```
