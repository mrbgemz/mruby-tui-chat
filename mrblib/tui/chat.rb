# frozen_string_literal: true

module TUI
  ##
  # {TUI::Chat} is a scrollable conversation widget
  # for AI chat interfaces, with word-wrapped text,
  # role-prefixed messages, and auto-scroll.
  class Chat < Widget
    ##
    # @param [Integer, Symbol] user_fg
    # @param [Integer, Symbol] assistant_fg
    # @param [Integer, Symbol] text_fg
    # @param [Integer, Symbol] bg
    # @param [Boolean] roles
    # @param [Hash] labels  Map role symbols to display strings.
    # @param (see TUI::Widget#initialize)
    def initialize(user_fg: :green, assistant_fg: :cyan, text_fg: :white,
                   bg: :default, roles: true, labels: {}, max_width: nil, **kw)
      super(**kw)
      @messages = []
      @scroll = 0
      @user_fg = user_fg
      @assistant_fg = assistant_fg
      @text_fg = text_fg
      @bg = bg
      @roles = roles
      @labels = labels
      @max_width = max_width
    end

    ##
    # Append a message to the conversation.
    #
    # @param [Object] role
    # @param [String, Array<Hash>] text
    # @return [void]
    def add(role, text)
      @messages << {role: role, text: text}
      @scroll = 0
    end

    ##
    # Append text to the last message for the given
    # role, or create one. Used for streaming output.
    #
    # @param [Object] role
    # @param [String, Array<Hash>] text
    # @return [void]
    def append(role, text)
      message = @messages[-1]
      if message && message[:role] == role
        message[:text] = merge_text(message[:text], text)
      else
        @messages << {role: role, text: dup_text(text)}
      end
      @scroll = 0
    end

    ##
    # Replace the last message for the given role.
    # Used for updating a streaming response in place.
    #
    # @param [Object] role
    # @param [String, Array<Hash>] text
    # @return [void]
    def replace_last(role, text)
      message = @messages[-1]
      if message && message[:role] == role
        message[:text] = dup_text(text)
      else
        @messages << {role: role, text: dup_text(text)}
      end
      @scroll = 0
    end

    ##
    # Scroll upward by one rendered row.
    # @return [void]
    def scroll_up
      max_r = total_rows
      body = rh
      @scroll = [@scroll + 1, max_r - body].min if max_r > body
    end

    ##
    # Scroll downward by one rendered row.
    # @return [void]
    def scroll_down
      @scroll = [@scroll - 1, 0].max
    end

    ##
    # Render the visible portion of the conversation.
    # @return [void]
    def render
      return if rw <= 0 || rh <= 0
      paint_background
      rows = rendered_rows
      start = [rows.length - rh - @scroll, 0].max
      visible = rows[start, rh] || []
      visible.each_with_index do |row, dy|
        render_row(row, dy)
      end
      super
    end

    private

    def paint_background
      blank = " " * rw
      rh.times do |dy|
        TUI.print(ax, ay + dy, @text_fg, @bg, blank)
      end
    end

    def role_fg(role)
      role == :user ? @user_fg : @assistant_fg
    end

    def total_rows
      rendered_rows.length
    end

    def wrap(text)
      width = content_width
      lines = []
      TUI::Utils.split(text, "\n", keep_empty: true).each do |paragraph|
        if paragraph.empty?
          lines << ""
          next
        end
        if preformatted?(paragraph)
          append_preformatted(lines, paragraph, width)
          next
        end
        line = +""
        TUI::Utils.split(paragraph).each do |word|
          if line.empty?
            append_word(lines, word, width) { |value| line = value }
          elsif line.length + 1 + word.length <= width
            line << " " << word
          else
            lines << line
            append_word(lines, word, width) { |value| line = value }
          end
        end
        lines << line unless line.empty?
      end
      lines.empty? ? [""] : lines
    end

    def merge_text(current, incoming)
      if current.is_a?(Array) || incoming.is_a?(Array)
        normalize_segments(current) + normalize_segments(incoming)
      else
        current.to_s + incoming.to_s
      end
    end

    def dup_text(text)
      text.is_a?(Array) ? normalize_segments(text) : text.to_s
    end

    def normalize_segments(text)
      return [] if text.nil?
      return [{text: text.to_s, fg: @text_fg, bg: @bg}] unless text.is_a?(Array)
      text.map do |segment|
        {text: segment[:text].to_s, fg: segment[:fg] || @text_fg, bg: segment[:bg] || @bg}
      end
    end

    def render_row(row, dy)
      if row[:segments]
        x = ax + row[:x]
        row[:segments].each do |segment|
          text = segment[:text].to_s
          next if text.empty?
          TUI.print(x, ay + dy, segment[:fg], segment[:bg] || @bg, text)
          x += text.length
        end
      else
        TUI.print(ax + row[:x], ay + dy, row[:fg], @bg, row[:text])
      end
    end

    def preformatted?(paragraph)
      paragraph.start_with?(" ", "\t")
    end

    def append_preformatted(lines, paragraph, width)
      chunks = paragraph.scan(/.{1,#{width}}/)
      if chunks.empty?
        lines << ""
      else
        chunks.each { lines << _1 }
      end
    end

    def append_word(lines, word, width)
      if word.length <= width
        yield(word)
        return
      end
      chunks = word.scan(/.{1,#{width}}/)
      chunks[0...-1].each { lines << _1 }
      yield(chunks[-1] || "")
    end

    def wrapped_rows(role, text)
      if text.is_a?(Array)
        width = content_width
        wrap_segments(text, width)
      else
        fg = @roles ? @text_fg : role_fg(role)
        wrap(text).map { |line| [{text: line, fg:, bg: @bg}] }
      end
    end

    def content_width
      width = [rw - 2, 1].max
      @max_width ? [width, @max_width.to_i].min : width
    end

    def wrap_segments(segments, width)
      lines = segment_lines(segments)
      rows = [[]]
      row_width = 0
      pending_space = nil
      lines.each_with_index do |line, index|
        if preformatted_segment_line?(line)
          append_preformatted_segment_line(rows, line, width)
        else
          row_width = 0
          pending_space = nil
          tokenize_line(line).each do |token|
            text = token[:text]
            next if text.empty?
            if whitespace?(text)
              if row_width.zero?
                row_width = append_chunks(rows, row_width, token, width)
              else
                pending_space = token
              end
              next
            end
            if pending_space && row_width.positive?
              needed = pending_space[:text].length + text.length
              if row_width + needed <= width
                row_width = append_chunks(rows, row_width, pending_space, width)
              else
                rows << []
                row_width = 0
              end
              pending_space = nil
            end
            row_width = append_chunks(rows, row_width, token, width)
          end
        end
        if index < lines.length - 1
          rows << []
          row_width = 0
          pending_space = nil
        end
      end
      rows.empty? ? [[{text: "", fg: @text_fg, bg: @bg}]] : rows
    end

    def segment_lines(segments)
      lines = [[]]
      normalize_segments(segments).each do |segment|
        parts = TUI::Utils.split(segment[:text], "\n", keep_empty: true)
        parts.each_with_index do |part, index|
          lines[-1] << {text: part, fg: segment[:fg], bg: segment[:bg]}
          lines << [] if index < parts.length - 1
        end
      end
      lines
    end

    def tokenize_line(segments)
      tokens = []
      segments.each do |segment|
        append_text_tokens(tokens, segment, segment[:text])
      end
      tokens
    end

    def preformatted_segment_line?(segments)
      text = line_text(segments)
      text.start_with?(" ", "\t", "|")
    end

    def line_text(segments)
      text = +""
      segments.each { |segment| text << segment[:text].to_s }
      text
    end

    def append_preformatted_segment_line(rows, segments, width)
      current = []
      current_width = 0
      segments.each do |segment|
        remaining = segment[:text].to_s
        while remaining.length > 0
          available = width - current_width
          if available <= 0
            rows << current
            current = []
            current_width = 0
            available = width
          end
          chunk = remaining[0, available]
          push_segment(current, segment[:fg], segment[:bg], chunk)
          current_width += chunk.length
          remaining = remaining[chunk.length..] || ""
          if remaining.length > 0
            rows << current
            current = []
            current_width = 0
          end
        end
      end
      rows[-1] = current
    end

    def append_text_tokens(tokens, segment, text)
      text.scan(/[^\s]+|[\s]+/).each do |part|
        tokens << {text: part, fg: segment[:fg], bg: segment[:bg]}
      end
    end

    def whitespace?(text)
      text.strip.empty?
    end

    def append_chunks(rows, row_width, token, width)
      remaining = token[:text]
      current_width = row_width
      while remaining.length > 0
        available = width - current_width
        if available <= 0
          rows << []
          current_width = 0
          available = width
        end
        chunk = remaining[0, available]
        push_segment(rows[-1], token[:fg], token[:bg], chunk)
        current_width += chunk.length
        remaining = remaining[chunk.length..] || ""
        if remaining.length > 0
          rows << []
          current_width = 0
        end
      end
      current_width
    end

    def push_segment(row, fg, bg, text)
      return if text.nil? || text.empty?
      previous = row[-1]
      if previous && previous[:fg] == fg && previous[:bg] == bg
        previous[:text] << text
      else
        row << {text:, fg:, bg:}
      end
    end

    def rendered_rows
      rows = []
      @messages.each do |msg|
        if @roles
          label = @labels[msg[:role]] || msg[:role].to_s
          rows << {x: 0, fg: role_fg(msg[:role]), text: " #{label}:"}
          wrapped_rows(msg[:role], msg[:text]).each do |line|
            rows << {x: 1, segments: [{text: " ", fg: @text_fg, bg: @bg}] + line}
          end
        else
          wrapped_rows(msg[:role], msg[:text]).each do |line|
            rows << {x: 0, segments: line}
          end
        end
        rows << {x: 0, fg: @text_fg, text: ""}
      end
      rows
    end
  end
end
