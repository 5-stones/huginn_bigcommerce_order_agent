module BigcommerceOrderAgent
  module Client
    class Order < AbstractClient
      @uri_base = ':api_version/orders/:order_id'

      def get(id, params = {})
        order = nil

        begin
          response = client.get(uri({ order_id: id }), params)
          order = response.body
        rescue Faraday::Error => e
          raise BigcommerceApiError.new('get order', { order_id: id }, e)
        end

        if order.present?
          order[:products] = get_products(id)
          order[:coupons] = get_coupons(id)
          order[:shipping_addresses] = get_shipping_addresses(id)
          order[:transactions] = get_transactions(id)
          order[:shipments] = get_shipments(id)

          transactions = get_transactions(id)
        end

        return order
      end

      #----------  Sub Record Queries  ----------#

      # Returns the order's line items
      def get_products(order_id, params = {})
        begin
          response = client.get(uri({ order_id: order_id }, 'products'), params)
          return response.body
        rescue Faraday::Error => e
          raise BigcommerceApiError.new('get order products', { order_id: order_id }, e)
        end
      end

      # Returns an array of shipping addresses attached to the order
      def get_shipping_addresses(order_id, params = {})
        begin
          response = client.get(uri({ order_id: order_id }, 'shipping_addresses'), params)
          return response.body
        rescue Faraday::Error => e
          raise BigcommerceApiError.new('get order shipping address', { order_id: order_id }, e)
        end
      end

      # Returns order shipments
      def get_shipments(order_id, params = {})
        begin
          response = client.get(uri({ order_id: order_id }, 'shipments'), params)
          return response.body
        rescue Faraday::Error => e
          raise BigcommerceApiError.new('get order shipments', { order_id: order_id }, e)
        end
      end

      # Returns order-level promotions
      def get_coupons(order_id, params = {})
        begin
          response = client.get(uri({ order_id: order_id }, 'coupons'), params)
          return response.body
        rescue Faraday::Error => e
          raise BigcommerceApiError.new('get order coupons', { order_id: order_id }, e
          )
        end
      end

      # Returns order transactions. NOTE:
      def get_transactions(order_id, params = {})
        begin
          response = client.get(uri({ api_version: 'v3', order_id: order_id }, 'transactions'), params)
          return response.body['data']
        rescue Faraday::Error => e
          raise BigcommerceApiError.new('get order transactions', { order_id: order_id }, e)
        end
      end
    end
  end
end
