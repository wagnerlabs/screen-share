# screen-share

`ss` opens a windowed macOS Screen Sharing login for another local account by
creating a localhost SSH tunnel to that account.

## Install

```sh
mkdir -p ~/.local/bin && curl -fsSL https://raw.githubusercontent.com/wagnerlabs/screen-share/main/ss -o ~/.local/bin/ss && chmod +x ~/.local/bin/ss
```

Make sure `~/.local/bin` is on your `PATH`.

## Requirements

- macOS.
- Remote Login (SSH) enabled in System Settings.
- Screen Sharing or Remote Management enabled in System Settings.
- Each target account permitted for Remote Login and Screen Sharing or Remote
  Management.

## Usage

```sh
ss <shortname>   # open or focus a Screen Sharing session for that local account
ss -l            # list active sessions
ss -k <user>     # stop one user's session tunnel
ss -K            # stop all session tunnels started by ss
ss -h            # show help
```

The target account must be different from the account running `ss`.

