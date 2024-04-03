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
#  transactions_portfolio_id_completed_at_type_index         | btree (portfolio_id, completed_at, type)
# Foreign key constraints:
#  transactions_account_id_fkey               | (account_id) REFERENCES accounts(id)
#  transactions_fee_currency_id_fkey          | (fee_currency_id) REFERENCES currencies(id)
#  transactions_from_currency_id_fkey         | (from_currency_id) REFERENCES currencies(id)
#  transactions_from_wallet_id_fkey           | (from_wallet_id) REFERENCES account_wallets(id)
#  transactions_market_value_currency_id_fkey | (market_value_currency_id) REFERENCES currencies(id)
#  transactions_portfolio_id_fkey             | (portfolio_id) REFERENCES portfolios(id)
#  transactions_to_currency_id_fkey           | (to_currency_id) REFERENCES currencies(id)
#  transactions_to_wallet_id_fkey             | (to_wallet_id) REFERENCES account_wallets(id)
# Referenced By:
#  transfers | transfers_from_transaction_id_fkey | (from_transaction_id) REFERENCES transactions(id)
#  transfers | transfers_to_transaction_id_fkey   | (to_transaction_id) REFERENCES transactions(id)

class Transaction < Sequel::Model
  many_to_one :portfolio
  many_to_one :account
  many_to_one :from_currency, class: :Currency
  many_to_one :to_currency, class: :Currency
  many_to_one :fee_currency, class: :Currency
  many_to_one :market_value_currency, class: :Currency
  many_to_one :from_wallet, class: :Wallet
  many_to_one :to_wallet, class: :Wallet

  TABLE_HEADERS = [
    'account_id', 'account', 'id', 'type', 'platform_transaction_id',
    'from_amount', ' ', 'to_amount', ' ',
    'market_value', ' ', 'fee', ' ',
    'completed_at', 'processed'
  ].freeze
  TABLE_ALIGNMENTS = %i[right left right right left right left right left right left right left left center].freeze
  extend TableFormatter

  MAX_TRANSFER_DELTA_SECS = 60 * 60 * 24 * 3 # +/- 3 days

  class << self
    # transaton must be of type 'transfer_out'
    def matching_transfer_in(transaction, time_delta_secs = MAX_TRANSFER_DELTA_SECS)
      raise "#{transaction.type} is not a 'transfer_out' type" unless transaction.type == 'transfer_out'

      matching_transfers(transaction, 'transfer_in', time_delta_secs)
        .where(to_amount: -(transaction.to_amount - (transaction.fee || 0)))
    end

    # transaton must be of type 'transfer_in'
    def matching_transfer_out(transaction, time_delta_secs = MAX_TRANSFER_DELTA_SECS)
      raise "#{transaction.type} is not a 'transfer_in' type" unless transaction.type == 'transfer_in'

      matching_transfers(transaction, 'transfer_out', time_delta_secs)
        .where(Sequel.lit('(-to_amount + coalesce(fee, 0)) = ?', transaction.to_amount))
    end

    private

    def matching_transfers(transaction, type, time_delta_secs = MAX_TRANSFER_DELTA_SECS)
      portfolio_id = transaction.portfolio_id
      account_id = transaction.account_id
      from = transaction.completed_at - time_delta_secs
      to = transaction.completed_at + time_delta_secs
      from_currency_id = to_currency_id = transaction.to_currency_id
      where(
        portfolio_id:, type:,
        from_currency_id:, to_currency_id:,
        processed: false, completed_at: from..to
      ).exclude(account_id:)
    end
  end

  def before_validation
    self.portfolio_id = account.portfolio_id if portfolio_id.nil?
    super
  end

  def process!
    case type
    when 'buy', 'interest', 'reward', 'refund'
      process_acquisition!
      update(processed: true)
    when 'sell'
      process_disposal!
      update(processed: true)
    when 'exchange'
      process_disposal!
      process_acquisition!
      update(processed: true)
    when 'loss_bankruptcy_liquidation'
      process_loss_bankruptcy_liquidation!
      update(processed: true)
    when 'transfer_out'
      process_transfer_out!
      update(processed: true)
    when 'transfer_in'
      process_transfer_in!
      update(processed: true)
    end
  end

  def transfer
    @transfer ||= case type
                  when 'transfer_out'
                    Transfer.find(from_account: account, from_transaction: self)
                  when 'transfer_in'
                    Transfer.find(to_account: account, to_transaction: self)
                  end
  end

  def matching_transfers(time_delta_secs = MAX_TRANSFER_DELTA_SECS)
    case type
    when 'transfer_out'
      matching_transfer_in(time_delta_secs)
    when 'transfer_in'
      matching_transfer_out(time_delta_secs)
    else
      raise "#{type} is not a transfer type"
    end
  end

  def matching_transfer_in(time_delta_secs = MAX_TRANSFER_DELTA_SECS)
    self.class.matching_transfer_in(self, time_delta_secs)
  end

  def matching_transfer_out(time_delta_secs = MAX_TRANSFER_DELTA_SECS)
    self.class.matching_transfer_out(self, time_delta_secs)
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

  def table_row
    [
      account_id,
      account.name,
      id,
      type,
      platform_transaction_id.length > 50 ? "#{platform_transaction_id[0..50]}..." : platform_transaction_id,
      from_amount.to_s('F'),
      from_currency.symbol,
      to_amount.to_s('F'),
      to_currency.symbol,
      market_value&.to_s('F'),
      market_value_currency&.symbol,
      fee&.to_s('F'),
      fee_currency&.symbol,
      completed_at ? completed_at.strftime('%Y-%m-%d %H:%M:%S') : '',
      processed
    ]
  end

  private

  def process_acquisition!
    return if type == 'exchange' && market_value.nil?
    return if from_amount.zero?

    if from_currency.crypto? # exchange / interest / reward etc.
      cost_currency = market_value_currency
      cost_amount = market_value
      # add fee to cost
      cost_amount += (market_value / from_amount.abs) * fee.abs if fee
    else # buy
      cost_currency = from_currency
      cost_amount = from_amount.abs
      cost_amount += fee.abs if fee
    end

    Acquisition.create(
      transaction: self,
      account:,
      currency: to_currency,
      amount: to_amount,
      cost_currency:,
      cost_amount:,
      type:,
      acquired_at: completed_at
    )
  end

  # from_amount is the original (crypto) currency amount reclaimed
  # to_amount is the amount of to_currency got back (.e.g USD or USDC for in-kind returns)
  def process_loss_bankruptcy_liquidation!
    total_amount = Asset.disposable_amount(account:, currency: from_currency, disposed_at: completed_at)
    process_disposal!(total_amount) # claim loss on all from_currency assets
    return unless to_currency.crypto?

    # in-kind returns in crypto
    # assumes no fees here, so cost_amount == market_value
    Acquisition.create(
      transaction: self,
      account:,
      currency: to_currency,
      amount: to_amount,
      cost_currency: market_value_currency,
      cost_amount: market_value,
      type: 'exchange',
      acquired_at: completed_at
    )
  end

  def process_disposal!(disposed_amount = from_amount.abs)
    # disposed_amount / from_amount is crypto
    if to_currency.crypto?
      # "exchange" type
      #   to_amount is crypto
      #   market_value contains the fiat value, but does not include the fee
      #   fee is denominated in crypto
      fiat_currency = market_value_currency
      fiat_amount = market_value
      if fee
        fee_amount = fee.abs
        fiat_amount += (market_value / disposed_amount) * fee_amount
        disposed_amount += fee_amount # fee is also being disposed
      end
    else
      # "sell" type
      #  to_amount contains fiat value
      #  fee is fiat & negative
      fiat_currency = to_currency
      # selling into fiat, so we need to deduct the fee
      fiat_amount = to_amount + (fee || 0)
    end

    fiat_price = fiat_amount / disposed_amount

    assets = Asset.disposal_lots(account:, currency: from_currency, amount: disposed_amount, disposed_at: completed_at)

    assets.each do |asset|
      if disposed_amount >= asset.amount
        amount = asset.amount
        cost_amount = asset.cost_amount
        account_cost_amount = asset.account_cost_amount
        disposed_amount -= amount
      else
        # partial disposal
        amount = disposed_amount.abs
        cost_amount = amount * asset.average_cost_amount
        account_cost_amount = amount * asset.account_average_cost_amount
      end

      sold_amount = fiat_price * amount

      Disposal.create(
        portfolio:,
        account:,
        transaction: self,
        currency: from_currency,
        fiat_currency:,
        amount:,
        cost_amount:,
        sold_amount:,
        account_cost_amount:,
        type:,
        acquisition: asset.acquisition,
        account_acquired_at: asset.account_acquired_at,
        disposed_at: completed_at
      )
      asset.update(
        amount: asset.amount - amount,
        cost_amount: asset.cost_amount - cost_amount,
        account_cost_amount: asset.account_cost_amount - account_cost_amount
      )
    end
  end

  def process_transfer_out!
    raise "#{type} is not a 'transfer_out'" unless type == 'transfer_out'

    @transfer = Transfer.find(from_account: account, from_transaction: self)
    return @transfer if @transfer

    matching_transactions = matching_transfer_in.all
    if matching_transactions.empty?
      raise "No matching 'transfer_in' transactions found for #{account.name} transaction #{id}: #{to_currency.name} #{to_amount} @ #{completed_at}"
    end
    raise "Too many matching 'transfer_in' matching transactions found: #{matching_transactions.size}" if matching_transactions.size > 1

    to_transaction = matching_transactions.first

    @transfer = Transfer.create(
      portfolio:,
      from_account: account,
      to_account: to_transaction.account,
      currency: to_currency,
      amount: to_amount.abs + (fee || 0), # to_amount & fee are negative
      from_transaction: self,
      to_transaction:,
      fiat_currency: to_transaction.market_value_currency,
      account_cost_amount: to_transaction.market_value,
      from_completed_at: completed_at,
      to_completed_at: to_transaction.completed_at
    )
  end

  def process_transfer_in!
    raise "#{type} is not a 'transfer_in'" unless type == 'transfer_in'

    @transfer = Transfer.find(to_account: account, to_transaction: self)
    return @transfer if @transfer

    matching_transactions = matching_transfer_out.all
    raise "No matching 'transfer_out' transactions found" if matching_transactions.empty?
    raise "Too many matching 'transfer_out' matching transactions found: #{matching_transactions.size}" if matching_transactions.size > 1

    from_transaction = matching_transactions.first

    @transfer = Transfer.create(
      portfolio:,
      from_account: from_transaction.account,
      to_account: account,
      currency: to_currency,
      amount: to_amount, # to_amount positive & no fee
      from_transaction:,
      to_transaction: self,
      fiat_currency: market_value_currency,
      account_cost_amount: market_value,
      from_completed_at: from_transaction.completed_at,
      to_completed_at: completed_at
    )
  end
end
