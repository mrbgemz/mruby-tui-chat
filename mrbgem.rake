# frozen_string_literal: true

load File.join(__dir__, "mrblib", "tui", "chat", "version.rb")

MRuby::Gem::Specification.new("mruby-tui-chat") do |spec|
  spec.license = "0BSD"
  spec.authors = "0x1eef"
  spec.version = TUI::Chat::VERSION
  spec.description = "A conversation widget for mruby-tui, optimized for AI chat"
  spec.add_dependency "mruby-tui", github: "mrbgemz/mruby-tui", branch: "v0.3.0"
  spec.rbfiles = Dir[File.expand_path("mrblib/**/*.rb", __dir__)].sort
end
