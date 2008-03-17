# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

require 'rack/utils'

module Rack
  module Session
    module Abstract
      # ID sets up a basic framework for implementing an id based sessioning
      # service. Cookies sent to the client for maintaining sessions will only
      # contain an id reference. Only #get_session and #set_session should
      # need to be overwritten.
      #
      # All parameters are optional.
      # * :key determines the name of the cookie, by default it is
      #   'rack.session'
      # * :domain and :path set the related cookie values, by default
      #   domain is nil, and the path is '/'.
      # * :expire_after is the number of seconds in which the session
      #   cookie will expire. By default it is set not to provide any
      #   expiry time.
      class ID
        attr_reader :key
        DEFAULT_OPTIONS = {
          :key =>           'rack.session',
          :path =>          '/',
          :domain =>        nil,
          :expire_after =>  nil
        }

        def initialize(app, options={})
          @default_options = self.class::DEFAULT_OPTIONS.merge(options)
          @key = @default_options[:key]
          @default_context = context app
        end

        def call(env)
          @default_context.call(env)
        end

        def context(app)
          Rack::Utils::Context.new self, app do |env|
            load_session env
            response = app.call(env)
            commit_session env, response
            response
          end
        end

        private

        # Extracts the session id from provided cookies and passes it and the
        # environment to #get_session. It then sets the resulting session into
        # 'rack.session', and places options and session metadata into
        # 'rack.session.options'.
        def load_session(env)
          sid           = env.fetch('HTTP_COOKIE','')[/#{@key}=([^,;]+)/,1]
          sid, session  = get_session(env, sid)
          unless session.is_a?(Hash)
            puts 'Session: '+sid.inspect+"\n"+session.inspect if $DEBUG
            raise TypeError, 'Session not a Hash'
          end
          options = @default_options.
            merge({ :id => sid, :by => self, :at => Time.now })

          env['rack.session'] = session
          env['rack.session.options'] = options
        end

        # Acquires the session from the environment and the session id from
        # the session options and passes them to #set_session. It then
        # proceeds to set a cookie up in the response with the session's id.
        def commit_session(env, response)
          options = env['rack.session.options']
          unless options.is_a?(Hash)
            puts 'Options: '+options.inspect if $DEBUG
            raise TypeError, 'Options not a Hash'
          end

          sid, time, z = options.values_at(:id, :at, :by)
          unless self == z
            warn "#{self} not managing this session."
            return
          end

          unless env['rack.session'].is_a?(Hash)
            puts 'Session: '+sid.inspect+"\n"+session.inspect if $DEBUG
            raise TypeError, 'Session not a Hash'
          end
          set_session(env, sid)

          expiry = options[:expire_after] && time+options[:expire_after]
          cookie = Utils.escape(@key)+'='+Utils.escape(sid)
          cookie<< "; domain=#{options[:domain]}" if options[:domain]
          cookie<< "; path=#{options[:path]}" if options[:path]
          cookie<< "; expires=#{expiry}" if expiry

          puts "Cookie: "+cookie.inspect if $DEBUG

          case a = (h = response[1])['Set-Cookie']
          when Array then  a << cookie
          when String then h['Set-Cookie'] = [a, cookie]
          when nil then    h['Set-Cookie'] = cookie
          end
        end

        # Should return [session_id, session]. All thread safety and session
        # retrival proceedures should occur here.
        # If nil is provided as the session id, generation of a new valid id
        # should occur within.
        def get_session(env, sid)
          raise '#get_session needs to be implemented.'
        end

        # All thread safety and session storage proceedures should occur here.
        def set_session(env, sid)
          raise '#set_session needs to be implemented.'
        end
      end
    end
  end
end
