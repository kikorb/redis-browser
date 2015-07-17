module RedisBrowser
  class Browser
    def initialize(conn = {})
      @conn = conn
    end

    def split_key(key)
      if key =~ /^(.+?)(:+|\/+|\.+).+$/
        [$1, $2]
      else
        [key, nil]
      end
    end

    def keys(namespace = nil)
      if namespace.to_s.strip.empty?
        pattern = "*"
        namespace = ""
      else
        pattern = namespace + "*"
      end

      redis.keys(pattern).inject({}) do |acc, key|
        key.slice!(namespace) if namespace

        ns, sep = split_key(key)

        unless ns.strip.empty?
          acc[ns] ||= {
            :name => ns,
            :full => namespace + ns + sep.to_s,
            :count => 0
          }
          acc[ns][:count] += 1
        end

        acc
      end.values.sort_by {|e| e[:name] }
    end

    def get_keys(key)
      key ||= ""
      key << "*" unless key.end_with?("*")

      values = redis.keys(key).map do |k|
        {:name => k, :full => k}
      end

      {values: values}
    end

    def delete(pattern)
      redis.del(redis.keys(pattern))
    end

    def get(key, opts = {})
      keys = keys(key)
      if keys.length > 1
        data = get_keys(key)
      elsif keys.present?
        full = keys.first[:full]
        data = {value: redis.get(full), type: "string", full: full}
      else
        data = {value: redis.get(key), type: "string", full: key}
      end
      data
    end

    def ping
      redis.ping == "PONG"
      {:ok => 1}
    rescue => ex
      {:error => ex.message}
    end

    def redis
      @redis ||= begin
        r = Redis::Store.new(@conn)
        auth = @conn['auth']
        r.auth(auth) if auth
        r
      end
    end
  end
end
