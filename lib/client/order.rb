require 'carmen'

module BigcommerceOrderAgent
  module Client
    class Order < AbstractClient
      include Carmen

      @uri_base = ':api_version/orders/:order_id'

      def get(id, params = {})
        order = nil

        begin
          response = client.get(uri({ order_id: id }), params)
          order = response.body
        rescue Faraday::Error => e
          raise BigcommerceApiError.new(
            e.response[:status],
            'get order',
            "Failed to get order #{id}",
            id,
            {
              errors: JSON.parse(e.response[:body])['errors']
            },
            e
          )
        end

        if order.present?
          order[:products] = get_products(id)
          order[:coupons] = get_coupons(id)
          order[:shipping_addresses] = get_shipping_addresses(id)
          order[:transactions] = get_transactions(id)
          order[:shipments] = get_shipments(id)

          order['billing_address']['state_code'] = get_region_code(order['billing_address'])

          transactions = get_transactions(id)
        end

        return order
      end

      #----------  Sub Record Queries  ----------#

      # Returns the order's line items.
      # NOTE: BigCommerce silently paginates this resource. The dfault is 50 items per page,
      # but orders with more than 50 items won't return anything to indicate that there are
      # more items to fetch, so we effectively have to call this recursively until the API
      # returns an empty array. Super fun.
      def get_products(order_id, page_number = 1, page_size = 50)
        begin
          response = client.get(uri({ order_id: order_id }, 'products'), { limit: page_size, page: page_number })
          data = response.body

          if (data.present? && data.length == page_size)
            # If the number of items is the same as the max page size, check for another page
            next_page = get_products(order_id, page_number + 1, page_size)
            # If there are items on the next page, merge them into the current list
            if (next_page.present? && next_page.length > 0)
              data.concat(next_page)
            end
          end

          # return the full list of items for the order
          return data
        rescue Faraday::Error => e
          raise BigcommerceApiError.new(
            e.response[:status],
            'get order products',
            "Failed to get order products #{order_id}",
            order_id,
            {
              errors: JSON.parse(e.response[:body])['errors'],
              product_page_number: page_number,
              page_size: page_size
            },
            e
          )
        end
      end

      # Returns an array of shipping addresses attached to the order
      def get_shipping_addresses(order_id, params = {})
        begin
          response = client.get(uri({ order_id: order_id }, 'shipping_addresses'), params)

          addresses = response.body

          if (addresses)
            addresses.each do |addr|
              addr['state_code'] = get_region_code(addr)
            end
          end

          return addresses
        rescue Faraday::Error => e
          raise BigcommerceApiError.new(
            e.response[:status],
            'get order shipping address',
            "Failed to get order shipping address #{order_id}",
            order_id,
            {
              errors: JSON.parse(e.response[:body])['errors']
            },
            e
          )
        end
      end

      # Returns order shipments
      def get_shipments(order_id, params = {})
        begin
          response = client.get(uri({ order_id: order_id }, 'shipments'), params)
          return response.body
        rescue Faraday::Error => e
          raise BigcommerceApiError.new(
            e.response[:status],
            'get order shipments',
            "Failed to get order shipments #{order_id}",
            order_id,
            {
              errors: JSON.parse(e.response[:body])['errors']
            },
            e
          )
        end
      end

      # Returns order-level promotions
      def get_coupons(order_id, params = {})
        begin
          response = client.get(uri({ order_id: order_id }, 'coupons'), params)
          return response.body
        rescue Faraday::Error => e
          raise BigcommerceApiError.new(
            e.response[:status],
            'get order coupons',
            "Failed to get order coupons #{order_id}",
            order_id,
            {
              errors: JSON.parse(e.response[:body])['errors']
            },
            e
          )
        end
      end

      # Returns order transactions. NOTE:
      def get_transactions(order_id, params = {})
        begin
          response = client.get(uri({ api_version: 'v3', order_id: order_id }, 'transactions'), params)
          return response.body['data']
        rescue Faraday::Error => e
          raise BigcommerceApiError.new(
            e.response[:status],
            'get order transactions',
            "Failed to get order transactions #{order_id}",
            order_id,
            {
              errors: JSON.parse(e.response[:body])['errors']
            },
            e
          )
        end
      end

      # Returns the region (state) code for the provided address
      def get_region_code(address)
        country = Country.named(address['country'])
        state = country.nil? ? nil : country.subregions.named(address['state'])

        #  For cases where a matching state is not found, default to the `state`
        #  value on the address. (This is not uncommon for international addresses)
        return state.nil? ? address['state'] : state.code
      end
    end
  end
end
