require 'huginn_agent'
require 'json'

# load clients
HuginnAgent.load 'client/abstract_client'
HuginnAgent.load 'client/customer'
HuginnAgent.load 'client/order'

# load errors
HuginnAgent.load 'errors/bigcommerce_api_error'

HuginnAgent.register 'huginn_bigcommerce_order_agent/bigcommerce_order_agent'
