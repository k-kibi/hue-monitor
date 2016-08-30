module Cybozu
  LOGIN_FORM_PATH = '/login'
  LOGIN_JSON_PATH = '/api/auth/login.json'
  LOGIN_REDIRECT_PATH = '/api/auth/redirect.do'

  class << self
    def load_settings
      @scheme = Settings.cybozu.scheme
      @domain = Settings.cybozu.domain
      @admin_account = Settings.cybozu.admin_account
      @admin_password = Settings.cybozu.admin_password
    end

    def scheme
      @scheme
    end

    def domain
      @domain
    end

    def admin_account
      @admin_account
    end

    def admin_password
      @admin_password
    end

    def base_url
      "#{@scheme}://#{@domain}"
    end

    def login(connection)
      response = connection.get LOGIN_FORM_PATH
      body = response.body
      raise 'unknown request token' unless /cybozu\.data\.REQUEST_TOKEN = '([^']*)'/ =~ body

      request_token = $1
      request_json = JSON.generate(
        __REQUEST_TOKEN__: request_token,
        keepUsername: false,
        password: admin_password,
        redirect: '',
        username: admin_account
      )

      response = connection.post do |req|
        req.path = LOGIN_JSON_PATH
        req.headers['Referer'] = LOGIN_FORM_PATH
        req.headers['Content-Type'] = 'application/json'
        req.body = request_json
      end
      raise "Login error. response.status: #{response.status}" unless response.status == 200

      response = connection.post do |req|
        req.path = LOGIN_REDIRECT_PATH
        req.body = {
          username: admin_account,
          password: admin_password,
          redirect: "#{base_url}/"
        }
      end
      raise "Login error. response.status: #{response.status}" unless [200, 302].include?(response.status)      
    end
  end
end
