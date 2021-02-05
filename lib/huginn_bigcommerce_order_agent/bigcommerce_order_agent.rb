# frozen_string_literal: true

require 'json'

module Agents
  class BigcommerceOrderAgent < Agent
    include WebRequestConcern

    can_dry_run!
    default_schedule 'never'

    # TODO:   Provide a more detailed agent description. Including details of
    # each option and how that option is used
    description <<-MD
      Used to fetch order data from the BigCommerce API.

      The BigCommerce API does not provide a way to quickly fetch the full product
      record in a single request. The `PostAgent` provided by Huginn will do the
      trick, but it requires 6 agents just to _fetch_ the data, and formatters to
      ensure the `body` data in the payload is not lost on each subsequent request.

      This agent is designed to consolidate that process into a single, no-frills
      execution. We fetch the data, and return it as is in a single JSON object.
      It's up to the end user to decide what to do next.


      ### **Data Structures:**

      *  [Orders](https://developer.bigcommerce.com/api-reference/store-management/orders/orders/getanorder#responses)
      *  [Customers](https://developer.bigcommerce.com/api-reference/store-management/customers-v3/customers/customersget#responses)
      *  [Order Products](https://developer.bigcommerce.com/api-reference/store-management/orders/order-products/getallorderproducts#responses)
      *  [Shipping Addresses](https://developer.bigcommerce.com/api-reference/store-management/orders/order-shipping-addresses/getallshippingaddresses#responses)
      *  [Order Shipments](https://developer.bigcommerce.com/api-reference/store-management/orders/order-shipments/getallordershipments#responses)
      *  [Order Coupons](https://developer.bigcommerce.com/api-reference/store-management/orders/order-coupons/getallordercoupons#responses)
      *  [Transactions](https://developer.bigcommerce.com/api-reference/store-management/order-transactions/transactions/gettransactions#responses)

      ### **Agent Payloads:**

      **Success Payload:**

      ```
      {
        order: {
          [...],
          customer: { ... },
          products: { ... },
          coupons: { ... },
          shipping_addresses: { ... },
          transactions: { ... }
        },
        status: 200,
      }
      ```

      **Error Payload:**

      ```
      {
        status: 5XX | 4XX,
        scope: string,
        response_body: {
          status: number,
          code: number,
          title: string,
          type: url,
          errors: { ... }
        },
        request_data: { ... },
      }
      ```
    MD

    def default_options
      {
        'store_hash' => '',
        'client_id' => '',
        'access_token' => '',
        'order_id' => '',
      }
    end

    def validate_options
        unless options['store_hash'].present?
          errors.add(:base, 'store_hash is a required field')
        end

        unless options['client_id'].present?
          errors.add(:base, 'client_id is a required field')
        end

        unless options['access_token'].present?
          errors.add(:base, 'access_token is a required field')
        end

        unless options['order_id'].present?
          errors.add(:base, 'order_id is a required field')
        end
    end

    def working?
      received_event_without_error?
    end

    def check
      initialize_clients
      handle interpolated['payload'].presence || {}
    end

    def receive(incoming_events)
      initialize_clients
      incoming_events.each do |event|
        handle(event)
      end
    end

    def handle(event)
      data = event.payload
      order_id = data['id']

      if (order_id.blank?)
        create_event payload: {
          status: 500,
          message: "'#{order_id}' is not a valid order id",
        }
      end

      begin
        order = @order_client.get(order_id)
        order[:customer] = @customer_client.get(order['customer_id'])

        create_event payload: {
          order: order,
          status: 200,
        }

      rescue BigcommerceApiError => e
        faraday_error = e.original_error

        create_event payload: {
          status: faraday_error.response[:status],
          scope: e.scope,
          response: faraday_error.response[:body],
          request_data: e.data,
        }
      end

    end

    private

    def initialize_clients
        @order_client = initialize_client(:Order)
        @customer_client = initialize_client(:Customer)
    end

    def initialize_client(class_name)
        klass = ::BigcommerceOrderAgent::Client.const_get(class_name.to_sym)
        return klass.new(
            interpolated['store_hash'],
            interpolated['client_id'],
            interpolated['access_token']
        )
    end

  end
end
