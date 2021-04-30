class BigcommerceApiError < StandardError
  attr_reader :status, :scope, :identifier, :data, :original_error

  def initialize(status, scope, message, identifier, data, original_error)
    @status = status
    @scope = scope
    @identifier = identifier
    @data = data
    @original_error = original_error

    super(message)
  end
end
