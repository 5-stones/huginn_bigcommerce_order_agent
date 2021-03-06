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

      ### **Options:**
      *  store_hash   - required
      *  client_id    - required
      *  access_token - required
      *  order_id     - required
      *  output_mode  - not required ('clean' or 'merge', defaults to 'clean')


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
        'output_mode' => 'clean',
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

        if options['output_mode'].present? && !options['output_mode'].to_s.include?('{') && !%[clean merge].include?(options['output_mode'].to_s)
          errors.add(:base, "if provided, output_mode must be 'clean' or 'merge'")
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
      new_event = interpolated['output_mode'].to_s == 'merge' ? data.dup : {}

      if (order_id.blank?)
        create_event payload: new_event.merge(
          status: 500,
          message: "'#{order_id}' is not a valid order id",
        )
      end

      begin
        order = @order_client.get(order_id)
        order[:customer] = @customer_client.get(order['customer_id'])

        create_event payload: new_event.merge(
          order: order,
          status: 200,
        )

      rescue BigcommerceApiError => e
        emit_error(e)
      rescue => e
        emit_error(BigcommerceApiError.new(
          500,
          'get order by id',
          e.message,
          order_id,
          { order_id: order_id },
          e
        ))
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

    #  Takes a BigCommerceProductError and emits the underlying data as an error payload
    #  to assist with error reporting. It is recommended that these errors be consolidated
    #  with a Digest Agent and reported as a summary.
    def emit_error(error)
      payload = {
        status: error.status,
        message: error.message,
        scope: error.scope,
        identifier: error.identifier,
        data: error.data,
      }
      Rails.logger.debug({
        error: payload,
        trace: error.backtrace
      })
      create_event({ payload: payload })
    end
  end
end
