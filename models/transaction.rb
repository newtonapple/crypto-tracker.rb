# frozen_string_literal: true

# Table: transactions
# Columns:
#  id                       | integer                     | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  portfolio_id             | integer                     | NOT NULL
#  account_id               | integer                     | NOT NULL
#  platform_transaction_id  | text                        | NOT NULL
#  from_wallet_id           | integer                     |
#  to_wallet_id             | integer                     |
#  from_currency_id         | integer                     | NOT NULL
#  to_currency_id           | integer                     | NOT NULL
#  fee_currency_id          | integer                     |
#  market_value_currency_id | integer                     |
#  from_amount              | numeric                     |
#  to_amount                | numeric                     |
#  market_value             | numeric                     |
#  fee                      | numeric                     |
#  type                     | transaction_type            | NOT NULL
#  processed                | boolean                     | NOT NULL DEFAULT false
#  completed_at             | timestamp without time zone | NOT NULL
#  created_at               | timestamp without time zone | NOT NULL
#  updated_at               | timestamp without time zone | NOT NULL
# Indexes:
#  transactions_pkey                                         | PRIMARY KEY btree (id)
#  transactions_account_id_type_platform_transaction_id_key  | UNIQUE btree (account_id, type, platform_transaction_id)
#  transactions_account_id_completed_at_type_index           | btree (account_id, completed_at, type)
#  transactions_account_id_from_currency_id_index            | btree (account_id, from_currency_id)
#  transactions_account_id_platform_transaction_id_index     | btree (account_id, platform_transaction_id)
#  transactions_account_id_processed_completed_at_type_index | btree (account_id, processed, completed_at, type)
#  transactions_account_id_processed_type_completed_at_index | btree (account_id, processed, type, completed_at)
#  transactions_account_id_to_currency_id_index              | btree (account_id, to_currency_id)
#  transactions_account_id_type_completed_at_index           | btree (account_id, type, completed_at)
#  transactions_account_id_type_from_currency_id_index       | btree (account_id, type, from_currency_id)
#  transactions_account_id_type_to_currency_id_index         | btree (account_id, type, to_currency_id)
#  transactions_created_at_index                             | btree (created_at)
#  transactions_from_wallet_id_index                         | btree (from_wallet_id)
#  transactions_portfolio_id_completed_at_type_index         | btree (portfolio_id, completed_at, type)
#  transactions_to_wallet_id_index                           | btree (to_wallet_id)
# Foreign key constraints:
#  transactions_account_id_fkey   | (account_id) REFERENCES accounts(id)
#  transactions_portfolio_id_fkey | (portfolio_id) REFERENCES portfolios(id)

class Transaction < Sequel::Model
  many_to_one :portfolio
  many_to_one :account
  many_to_one :from_currency, class: :Currency
  many_to_one :to_currency, class: :Currency
  many_to_one :fee_currency, class: :Currency
  many_to_one :market_value_currency, class: :Currency
  many_to_one :from_wallet, class: :Wallet
  many_to_one :to_wallet, class: :Wallet

  def before_validation
    self.portfolio_id = account.portfolio_id if portfolio_id.nil?
    super
  end

  def process!
    case type
    when 'buy'
      process_acquisition!
    when 'sell'
      process_disposal!
    when 'exchange'
      t.process_disposal!
      t.process_acquisition!
    end
  end

  def to_s
    return super unless from_amount && to_amount && from_currency && to_currency

    output = +''
    col_width = 30
    symbol_width = 8
    if id
      id_col = id.to_s.rjust(15)
      output << id_col
      output << ' | '
    end
    type_col = type.rjust(12)
    from_currency_symbol = "(#{from_currency.symbol})".ljust(symbol_width)
    from_col = format("%20.10f #{from_currency_symbol}", from_amount)
    to_currency_symbol = "(#{to_currency.symbol})".ljust(symbol_width)

    to_col = format("%20.10f #{to_currency_symbol}", to_amount)
    output << "#{type_col} | #{from_col.rjust(col_width)} -> #{to_col.rjust(col_width)}"

    if fee && fee_currency
      fee_currency_symbol = "(#{fee_currency.symbol})".ljust(symbol_width)
      fee_col = format("%13.10f #{fee_currency_symbol}", fee)
      output << " | #{fee_col.rjust(col_width - 3)}"
    else
      output << ' | '.ljust(col_width)
    end

    if market_value && market_value_currency
      market_value_currency_symbol = "(#{market_value_currency.symbol})".ljust(symbol_width)
      market_value_col = format("%20.10f #{market_value_currency_symbol}", market_value)
      output << " | #{market_value_col.rjust(col_width)}"
    else
      output << ' | '.ljust(col_width + 3)
    end

    output << (completed_at ? " | @ #{completed_at}" : ' | '.ljust(col_width))
    output << " | #{platform_transaction_id}" if platform_transaction_id
    output
  end

  def set_amount!(currency, amount)
    if amount.negative?
      self.from_currency = currency
      self.from_amount = amount
    else
      self.to_currency = currency
      self.to_amount = amount
    end
  end

  def classify_trade!
    self.type = classify_trade
  end

  def classify_trade
    return nil unless from_currency && to_currency
    return nil unless from_amount&.negative? && to_amount&.positive?

    return 'exchange' if from_currency.crypto? && to_currency.crypto?
    return 'buy' if from_currency.fiat? && to_currency.crypto?
    return 'sell' if from_currency.crypto? && to_currency.fiat?

    nil
  end

  private

  def process_acquisition!
    return if type == 'exchange' && market_value.nil?

    if form_currency.crypto?
      cost_currency = market_value_currency
      cost_amount = market_value
    else
      cost_currency = from_currency.abs
      cost_amount = from_amount
    end

    Acquisition.create(
      transaction: self,
      account:,
      currency: to_currency,
      amount: to_amount,
      # cost_currency: from_currency,
      # cost_amount: fee ? from_amount.abs + fee.abs : from_amount.abs,
      cost_currency:,
      cost_amount: fee ? cost_amount + fee.abs : cost_amount,
      has_cost: true,
      type:,
      acquired_at: completed_at
    )
    update(processed: true)
  end

  def process_disposal!
    # type is sell
    # to_amount is fiat
    # fee is fiat & negative
    disposed_amount = from_amount.abs # crypto
    fiat_amount = to_amount + (fee || 0)
    fiat_price = fiat_amount / disposed_amount

    assets = Asset.disposal_lots(account:, currency: from_currency, amount: disposed_amount, disposed_at: completed_at)

    assets.each do |asset|
      if disposed_amount >= asset.amount
        amount = asset.amount
        cost_amount = asset.cost_amount
        disposed_amount -= amount
      else
        # partial disposal
        amount = disposed_amount.abs
        cost_amount = amount * asset.average_cost_amount
      end

      sold_amount = fiat_price * amount

      Disposal.create(
        portfolio:,
        account:,
        transaction: self,
        currency: from_currency,
        fiat_currency: to_currency,
        amount:,
        cost_amount:,
        sold_amount:,
        type:,
        acquisition: asset.acquisition,
        disposed_at: completed_at
      )
      asset.update(
        amount: asset.amount - amount,
        cost_amount: asset.cost_amount - cost_amount
      )
    end
  end
end
