/** @jsxImportSource @opentui/solid */
// RA-CODE branding for the OpenCode TUI: replaces the OpenCode logo on the
// home screen through the `home_logo` plugin slot. Loaded via tui.json.

const LEFT = [
  "████   ███       ",
  "█   █ █   █      ",
  "████  █████ ████ ",
  "█  █  █   █      ",
  "█   █ █   █      ",
]

const RIGHT = [
  " ████  ███  ████  █████",
  "█     █   █ █   █ █    ",
  "█     █   █ █   █ ████ ",
  "█     █   █ █   █ █    ",
  " ████  ███  ████  █████",
]

const BOLD = 1

export default {
  id: "ra-code.branding",
  tui: async (api) => {
    api.slots.register({
      order: 0,
      slots: {
        home_logo() {
          const theme = api.theme.current
          return (
            <box>
              {LEFT.map((left, i) => (
                <box flexDirection="row">
                  <text fg={theme.textMuted} selectable={false}>
                    {left}
                  </text>
                  <text fg={theme.text} attributes={BOLD} selectable={false}>
                    {RIGHT[i]}
                  </text>
                </box>
              ))}
            </box>
          )
        },
      },
    })
  },
}
