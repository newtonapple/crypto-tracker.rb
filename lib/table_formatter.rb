# frozen_string_literal: true

require 'tty/table'

module TableFormatter
  def render_table(rows, format: :unicode, header: self::TABLE_HEADERS, alignments: self::TABLE_ALIGNMENTS, &block)
    if block
      tb = table(rows, header:, &block)
      tb.render(format, alignments:)
    else
      table(rows, header:).render(format, alignments:)
    end
  end

  def table(rows, header: self::TABLE_HEADERS)
    table = TTY::Table.new(header:)
    if block_given?
      rows.each do |r|
        row = yield(r)
        table << row
        # table << yield(r)
      end
    else
      rows.each do |r|
        table << r.table_row
      end
    end
    table
  end
end
