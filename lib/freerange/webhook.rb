require 'net/http'
require 'json'

module Freerange

  module Webhook
    def self.post(url, data)
      begin
        Net::HTTP.post_form(URI.parse(url),{"payload" => data.to_json})
      rescue Exception => e
        puts "ERROR posting to deploy_webhook_url = #{url} #{e}"
      end
    end
  end

end
