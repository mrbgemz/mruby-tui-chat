## About

mruby-tui-chat provides a conversation widget for
[mruby-tui](https://github.com/llmrb/mruby-tui), optimized for
AI chat interfaces. It supports word-wrapped text, role-prefixed
messages, segmented rendering with colours, and scroll.

## Quick start

#### Basic chat

```ruby
chat = TUI::Chat.new
chat.add(:user, "Hello")
chat.add(:assistant, "Hi there!")
```

#### Streaming output

```ruby
chat = TUI::Chat.new
chat.replace_last(:assistant, "")
chat.append(:assistant, "Hello")
chat.append(:assistant, " world")
```

#### Without role labels

```ruby
chat = TUI::Chat.new(show_roles: false)
chat.add(:user, "just the message")
```

## Features

**TUI::Chat.new**<br>
Creates a chat widget with configurable foreground colours
for user, assistant, and text, plus a background colour.

**TUI::Chat#add**<br>
Appends a new message with the given role and text.

**TUI::Chat#append**<br>
Appends text to the last message for the given role, or
creates one if no matching message exists. Used for
streaming output where content arrives incrementally.

**TUI::Chat#replace_last**<br>
Replaces the last message for the given role. Used for
updating a streaming response in place.

**TUI::Chat#scroll_up**<br>
Scrolls the view upward by one rendered row.

**TUI::Chat#scroll_down**<br>
Scrolls the view downward by one rendered row.

## Integration

Add to your mruby build config:

```ruby
MRuby::Build.new("app") do |conf|
  conf.toolchain
  conf.gembox "default"
  conf.gem github: "llmrb/mruby-tui-chat", branch: "main"
end
```

Dependencies are declared in mrbgem.rake:

| Dependency | Purpose |
|---|---|
| mruby-tui | Widget base class, TUI.print, Utils |

## License

BSD Zero Clause
<br>
See LICENSE
