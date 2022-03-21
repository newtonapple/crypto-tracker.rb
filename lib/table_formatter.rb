# frozen_string_literal: true

require 'tty/table'

module TableFormatter
  def render_table(rows, format: :unicode, header: self::TABLE_HEADERS, alignments: self::TABLE_ALIGNMENTS)
    table(rows, header:).render(format, alignments:)
  end

  def table(rows, header: self::TABLE_HEADERS)
    table = TTY::Table.new(header:)
    rows.each do |r|
      table << r.table_row
    end
    table
  end
end
