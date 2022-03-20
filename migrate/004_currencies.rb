# frozen_string_literal: true

Sequel.migration do
  up do
    create_enum(:currency_type, %w[crypto fiat])

    create_table(:currencies) do
      primary_key :id
      String :name, null: false, index: true, size: 255
      String :symbol, null: false, size: 125
      currency_type :type, null: false
      DateTime :created_at, null: false, index: true
      DateTime :updated_at, null: false, index: true
      unique %i[symbol name type]
    end
  end

  down do
    drop_table(:currencies)
    drop_enum(:currency_type)
  end
end
