# frozen_string_literal: true

require 'tty/table'

# TurboTax TXF format
# https://taxdataexchange.org/docs/txf/v042/index.html
module Txf
  module Form8949
    # Form 8949 TXF format
    # https://taxdataexchange.org/docs/txf/v042/form-1099-b.html
    #
    # Form 8949 includes two separate parts for reporting long-term and short-term gains and losses.
    #    Part I for reporting short-term capital gains and losses
    #    Part II for reporting long-term capital gain and losses
    # Short-term sales transactions are further broken down into the following categories:
    #    A – Sales of covered securities for which cost basis is provided to the IRS on Form 1099-B
    #    B – Transactions reported on Form 1099-B but basis is not reported to the IRS
    #    C – Sales of securities for which no Form 1099-B is received.
    # Long-term sales transactions are further broken down into the following categories:
    #    D – Sales of covered securities for which cost basis is provided to the IRS on Form 1099-B
    #    E – Transactions reported on Form 1099-B but basis is not reported to the IRS
    #    F – Sales of securities for which no Form 1099-B is received
    # | Holding Period | Part I with Box A checked  | Part I with Box B checked  | Part I with Box C checked  |
    # | -------------- | -------------------------- | -------------------------- | -------------------------- |
    # | Short-term     | 321                        | 711                        | 712                        |
    # | Holding Period | Part II with Box D checked | Part II with Box E checked | Part II with Box F checked |
    # | -------------- | -------------------------- | -------------------------- | -------------------------- |
    # | Long-term      | 323                        | 713                        | 714                        |

    REFERENCE_NUMBERS_1099B = {
      reported: { 'short_term' => 'N321', 'long_term' => 'N323' },
      unreported: { 'short_term' => 'N711', 'long_term' => 'N713' },
      none: { 'short_term' => 'N712', 'long_term' => 'N714' }
    }.freeze

    def txf(disposals:, name:, date: Date.today, status_1099b: :none)
      date = date.strftime('%m/%d/%Y')
      refs = REFERENCE_NUMBERS_1099B[status_1099b]

      output = +"V042\nA#{name}\nD#{date}\n^\n"
      disposals.each do |d|
        output << "TD\n"
        output << "#{refs[d.capital_gains_treatment]}\n" # reference number
        output << "C1\n" # copy number (multi-copy forms like Schedule C,  max 255)
        output << "L1\n" # line number (multi-line?)
        output << "P#{d.amount.to_s('F')} #{d.currency.symbol}\n" # description
        output << "D#{d.acquired_at.strftime('%m/%d/%Y')}\n" # date acquired
        output << "D#{d.disposed_at.strftime('%m/%d/%Y')}\n" # date sold
        output << "$#{d.cost_amount.round(2).to_s('F')}\n"  # cost basis
        output << "$#{d.sold_amount.round(2).to_s('F')}\n"  # proceeds
        output << "^\n"
      end
      output
    end

    extend self # rubocop:disable Style/ModuleFunction
  end
end
