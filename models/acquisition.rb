# frozen_string_literal: true

# Table: acquisitions
# Columns:
#  id                  | integer                     | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  transaction_id      | integer                     |
#  account_id          | integer                     | NOT NULL
#  currency_id         | integer                     | NOT NULL
#  amount              | numeric                     | NOT NULL
#  cost_currency_id    | integer                     |
#  cost_amount         | numeric                     |
#  average_cost_amount | numeric                     |
#  has_cost            | boolean                     | NOT NULL DEFAULT false
#  type                | acquisition_type            | NOT NULL
#  acquired_at         | timestamp without time zone | NOT NULL
#  created_at          | timestamp without time zone | NOT NULL
# Indexes:
#  acquisitions_pkey                                               | PRIMARY KEY btree (id)
#  acquisitions_transaction_id_key                                 | UNIQUE btree (transaction_id)
#  acquisitions_account_id_acquired_at_index                       | btree (account_id, acquired_at)
#  acquisitions_account_id_currency_id_acquired_at_index           | btree (account_id, currency_id, acquired_at)
#  acquisitions_account_id_currency_id_type_acquired_at_index      | btree (account_id, currency_id, type, acquired_at)
#  acquisitions_account_id_has_cost_acquired_at_index              | btree (account_id, has_cost, acquired_at)
#  acquisitions_account_id_has_cost_currency_id_acquired_at_index  | btree (account_id, has_cost, currency_id, acquired_at)
#  acquisitions_account_id_has_cost_currency_id_type_acquired_at_i | btree (account_id, has_cost, currency_id, type, acquired_at)
#  acquisitions_account_id_type_acquired_at_index                  | btree (account_id, type, acquired_at)
#  acquisitions_created_at_account_id_index                        | btree (created_at, account_id)
# Foreign key constraints:
#  acquisitions_account_id_fkey       | (account_id) REFERENCES accounts(id)
#  acquisitions_cost_currency_id_fkey | (cost_currency_id) REFERENCES currencies(id)
#  acquisitions_currency_id_fkey      | (currency_id) REFERENCES currencies(id)
# Referenced By:
#  assets    | assets_acquisition_id_fkey    | (acquisition_id) REFERENCES acquisitions(id)
#  disposals | disposals_acquisition_id_fkey | (acquisition_id) REFERENCES acquisitions(id)

class Acquisition < Sequel::Model
  many_to_one :account
  many_to_one :currency
  many_to_one :cost_currency, class: :Currency
  many_to_one :transaction

  TABLE_HEADERS = ['id', 'type', 'amount', ' ', 'cost', ' ', 'cost_avg', ' ', 'acquired_at'].freeze
  TABLE_ALIGNMENTS = %i[left left right left right left right left left].freeze
  extend TableFormatter

  def before_save
    set_average_cost_amount
    super
  end

  def after_create
    create_asset
    super
  end

  def table_row
    [
      id,
      type,
      amount.to_s('F'),
      currency.symbol,
      cost_amount.round(2).to_s('F'),
      cost_currency.symbol,
      average_cost_amount.round(2).to_s('F'),
      "#{cost_currency.symbol}/#{currency.symbol}",
      acquired_at.strftime('%Y-%m-%d %H:%M:%S')
    ]
  end

  private

  def create_asset
    Asset.create(
      portfolio_id: account.portfolio_id,
      acquisition: self,
      account:,
      currency:,
      amount:,
      cost_currency:,
      cost_amount:,
      average_cost_amount:,
      type:,
      acquired_at:
    )
  end

  def set_average_cost_amount
    return unless average_cost_amount.nil? && has_cost && cost_amount && amount&.positive?

    self.average_cost_amount = cost_amount / amount
  end
end
