class BigcommerceApiError < StandardError
  attr_reader :scope, :data, :original_error

  def initialize(scope, data, original_error)
    @scope = scope
    @data = data
    @original_error = original_error
    super(original_error.message)
  end
end
