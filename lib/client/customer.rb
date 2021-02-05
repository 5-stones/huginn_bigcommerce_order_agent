module BigcommerceOrderAgent
  module Client
    class Customer < AbstractClient
      @uri_base = 'v3/customers'

      # The v3 customer endpoint only returns a customer array. In the context of
      # this agent, however, we only want one customer, so we intentionally return
      # data[0]
      def get(id, params = {})
        begin
          response = client.get(uri, { 'id:in' => id, 'include' => 'attributes,formfields' })
          return response.body['data'][0]
        rescue Faraday::Error::ClientError => e
          raise BigcommerceApiError.new(
            'get order', "Failed to get order #{id}", { order_id: id }, e
          )
        end
      end

    end
  end
end
