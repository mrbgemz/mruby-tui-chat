# frozen_string_literal: true

MRuby::Gem::Specification.new("mruby-tui-chat") do |spec|
  spec.license = "0BSD"
  spec.authors = "0x1eef"
  spec.version = "0.1.0"
  spec.description = "A conversation widget for mruby-tui, optimized for AI chat"

  spec.add_dependency "mruby-tui", github: "llmrb/mruby-tui", branch: "main"

  spec.rbfiles = Dir[File.expand_path("mrblib/**/*.rb", __dir__)].sort
end
