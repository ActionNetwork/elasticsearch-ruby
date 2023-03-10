module Elasticsearch
  module Transport
    module Transport
      module HTTP

        # Alternative HTTP transport implementation, using the [_Curb_](https://rubygems.org/gems/curb) client.
        #
        # @see Transport::Base
        #
        class Curb
          include Base

          # Performs the request by invoking {Transport::Base#perform_request} with a block.
          #
          # @return [Response]
          # @see    Transport::Base#perform_request
          #
          def perform_request(method, path, params={}, body=nil, headers=nil, opts={})
            super do |connection, _url|
              connection.connection.url = connection.full_url(path, params)
              body = body ? __convert_to_json(body) : nil
              body, headers = compress_request(body, headers)

              case method
                when 'HEAD'
                when 'GET', 'POST', 'PUT', 'DELETE'
                  connection.connection.set :nobody, false

                  connection.connection.put_data = body if body

                  if headers
                    if connection.connection.headers
                      connection.connection.headers.merge!(headers)
                    else
                      connection.connection.headers = headers
                    end
                  end

                else raise ArgumentError, "Unsupported HTTP method: #{method}"
              end

              connection.connection.http(method.to_sym)

              response_headers = {}
              response_headers['content-type'] = 'application/json' if connection.connection.header_str =~ /\/json/

              Response.new connection.connection.response_code,
                           decompress_response(connection.connection.body_str),
                           response_headers
            end
          end

          # Builds and returns a connection
          #
          # @return [Connections::Connection]
          #
          def __build_connection(host, options={}, block=nil)
            client = ::Curl::Easy.new

            headers = options[:headers] || {}
            headers.update('User-Agent' => "Curb #{Curl::CURB_VERSION}")

            client.headers = headers
            client.url     = __full_url(host)

            if host[:user]
              client.http_auth_types = host[:auth_type] || :basic
              client.username = host[:user]
              client.password = host[:password]
            end

            client.instance_eval(&block) if block

            Connections::Connection.new :host => host, :connection => client
          end

          # Returns an array of implementation specific connection errors.
          #
          # @return [Array]
          #
          def host_unreachable_exceptions
            [
              ::Curl::Err::HostResolutionError,
              ::Curl::Err::ConnectionFailedError,
              ::Curl::Err::GotNothingError,
              ::Curl::Err::RecvError,
              ::Curl::Err::SendError,
              ::Curl::Err::TimeoutError
            ]
          end

          private

          def user_agent_header(client)
            @user_agent ||= begin
              meta = ["RUBY_VERSION: #{RUBY_VERSION}"]
              if RbConfig::CONFIG && RbConfig::CONFIG['host_os']
                meta << "#{RbConfig::CONFIG['host_os'].split('_').first[/[a-z]+/i].downcase} #{RbConfig::CONFIG['target_cpu']}"
              end
              meta << "Curb #{Curl::CURB_VERSION}"
              "elasticsearch-ruby/#{VERSION} (#{meta.join('; ')})"
            end
          end
        end

      end
    end
  end
end
