require 'net/http'
require 'uri'
require 'yaml'

module Panda
  class << self
    attr_accessor :account_key, :api_domain, :api_port
  
    def api_port
      @api_port ||= 80
      @api_port
    end
  end
  
  class Video
    attr_accessor :vals
    
    def self.new_with_attrs(vals)
      @vals = {}
      vals.each do |k,v|
        @vals[k] = v
        class_eval "def #{k}; @vals[#{k}]; end"
      end
    end
    
    class << self
      def find(token)
        response = request(:get, "/videos/#{token}")
        p = self.new_with_attrs(response[:video])
        return p
      end
  
      def create
        response = request(:post, "/videos")
        p = self.new_with_attrs(response[:video])
        return p
      end
  
      def videos
        response = request(:get, "/videos")
        return response[:videos].map {|v| self.new_with_attrs(v[:video]) }
      end
  
      # Makes request to remote service.
      def request(method, path, params={})
        raise Panda::AccountKeyNotSet if Panda.account_key.nil?
        params[:account_key] = Panda.account_key
        path += ".yaml"
        http = Net::HTTP.new(Panda.api_domain, Panda.api_port)
    
        case method
        when :get
          response = http.request_get("#{path}?account_key=#{Panda.account_key}")
        when :post
          req = Net::HTTP::Post.new(path)
          req.form_data = params
          response = http.request(req)
        end
    
        puts "--> #{response.code} #{response.message} (#{response.body.length})"
        puts response.body
        handle_response(response)
      end
  
      # Handles response and error codes from remote service.
  
      def handle_response(response)
        case response.code.to_i
          when 200...400
            YAML.load(response.body)
          when 401
            raise(Panda::UnauthorizedAccess.new(response))
          when 404
            raise(Panda::ResourceNotFound.new(response))
          when 500...600
            raise(Panda::ServerError.new(response))
          else
            raise(Panda::PandaError.new(response, "Unknown response code: #{response.code}"))
        end
      end
    end
  end
  
  class PandaError < StandardError; end
  
  class ConnectionError < PandaError # :nodoc:
    attr_reader :response

    def initialize(response, message = nil)
      @response = response
      @message  = message
    end

    def to_s
      "Failed with #{response.code} #{response.message if response.respond_to?(:message)}"
    end
  end
  
  class AccountKeyNotSet < PandaError; end
  
  # 4xx Client Error
  class ClientError < ConnectionError; end # :nodoc:
  
  # 401 Unauthorized
  class UnauthorizedAccess < ClientError; end # :nodoc
  
  # 404 Not Found
  class VideoNotFound < ClientError; end # :nodoc:

  # 5xx Server Error
  class ServerError < ConnectionError; end # :nodoc:
end