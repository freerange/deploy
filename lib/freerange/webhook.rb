require 'net/http'
require 'json'

module Freerange

  module Webhook
    def self.post(url, params = {}, data = {})
      begin
        query = params.merge(:payload => data.to_json)
        Net::HTTP.post_form(URI.parse(url), query)
      rescue Exception => e
        puts "ERROR posting to deploy_webhook_url = #{url} #{e}"
      end
    end
  end

end
