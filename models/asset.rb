# frozen_string_literal: true

# Table: assets
# Columns:
#  id                  | integer                     | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  portfolio_id        | integer                     | NOT NULL
#  account_id          | integer                     | NOT NULL
#  currency_id         | integer                     | NOT NULL
#  cost_currency_id    | integer                     | NOT NULL
#  acquisition_id      | integer                     | NOT NULL
#  type                | acquisition_type            | NOT NULL
#  amount              | numeric                     | NOT NULL
#  cost_amount         | numeric                     | NOT NULL
#  average_cost_amount | numeric                     | NOT NULL
#  acquired_at         | timestamp without time zone | NOT NULL
#  transferred_at      | timestamp without time zone |
#  created_at          | timestamp without time zone | NOT NULL
#  updated_at          | timestamp without time zone | NOT NULL
# Indexes:
#  assets_pkey                                                     | PRIMARY KEY btree (id)
#  assets_acquisition_id_index                                     | btree (acquisition_id)
#  assets_created_at_account_id_index                              | btree (created_at, account_id)
#  assets_portfolio_id_account_id_currency_id_acquired_at_amount_i | btree (portfolio_id, account_id, currency_id, acquired_at, amount)
#  assets_portfolio_id_account_id_currency_id_average_cost_amount_ | btree (portfolio_id, account_id, currency_id, average_cost_amount, acquired_at, amount)
#  assets_portfolio_id_currency_id_acquired_at_index               | btree (portfolio_id, currency_id, acquired_at)
#  assets_portfolio_id_currency_id_transferred_at_index            | btree (portfolio_id, currency_id, transferred_at)
#  assets_updated_at_account_id_index                              | btree (updated_at, account_id)
# Foreign key constraints:
#  assets_account_id_fkey       | (account_id) REFERENCES accounts(id)
#  assets_acquisition_id_fkey   | (acquisition_id) REFERENCES acquisitions(id)
#  assets_cost_currency_id_fkey | (cost_currency_id) REFERENCES currencies(id)
#  assets_currency_id_fkey      | (currency_id) REFERENCES currencies(id)
#  assets_portfolio_id_fkey     | (portfolio_id) REFERENCES portfolios(id)

class Asset < Sequel::Model
  many_to_one :portfolio
  many_to_one :account
  many_to_one :currency
  many_to_one :cost_currency, class: :Currency
  many_to_one :acquisition

  TABLE_HEADERS = ['id', 'type', 'amount', ' ', 'cost', ' ', 'cost_avg', ' ', 'acquired_at'].freeze
  TABLE_ALIGNMENTS = %i[left left right left right left right left left].freeze
  extend TableFormatter

  class << self
    def disposal_lots(account:, currency:, amount:, disposed_at:)
      send("#{account.accounting_method}_disposal_lots", account:, currency:, amount:, disposed_at:)
    end

    def fifo_disposal_lots(account:, currency:, amount:, disposed_at:)
      assets = disposable(account.id, currency.id, disposed_at).order(:acquired_at, :id)

      find_disposal_lots(assets, amount) do |lot|
        assets.where { acquired_at >= lot.acquired_at }
      end
    end

    def lifo_disposal_lots(account:, currency:, amount:, disposed_at:)
      assets = disposable(account.id, currency.id, disposed_at).reverse(:acquired_at, :id)

      find_disposal_lots(assets, amount) do |lot|
        assets.where { acquired_at <= lot.acquired_at }
      end
    end

    def hifo_disposal_lots(account:, currency:, amount:, disposed_at:)
      assets = disposable(account.id, currency.id, disposed_at).order(Sequel.desc(:average_cost_amount), :acquired_at, :id)

      find_disposal_lots(assets, amount) do |lot|
        assets.where { average_cost_amount <= lot.average_cost_amount }
      end
    end

    def disposable(account_id, currency_id, disposed_at)
      where(account_id:, currency_id:).where do
        (Sequel[:amount] > 0) & (acquired_at <= disposed_at) # rubocop:disable Style/NumericPredicate
      end
    end

    private

    def find_disposal_lots(assets, amount)
      lots = []
      lot_ids = []
      lot = assets.first

      return lots unless lot

      amount -= lot.amount
      lots << lot
      lot_ids << lot.id
      while amount.positive?
        next_assets = yield lot
        lot = next_assets.exclude(id: lot_ids).first
        break unless lot

        amount -= lot.amount
        lots << lot
        lot_ids << lot.id
      end

      lots
    end
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
end
