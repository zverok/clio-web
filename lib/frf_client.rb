# encoding: utf-8
require 'simplehttp'
require 'base64'
require 'fileutils'
require 'core_ext'

require 'json'
#require 'rutils/datetime/datetime'

def parse_time(str)
    str =~ /(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)Z/
    Time.local($1, $2, $3, $4, $5, $6)
end

class FriendFeedClient
    def initialize(user, key)
        @user, @key = user, key
    end
    
    def feed(name, params)
        request("feed/#{name}", params)
    end
    
    def userpic(user, size='large')
        raw_request("picture/#{user}", 'size' => size)
    end

    def request(method, params = {})
        response = JSON.parse(raw_request(method, params))
        response['errorCode'] && raise(RuntimeError, response['errorCode']) 
        response
    end
    
    def raw_request(method, params = {})
        http = SimpleHttp.new construct_url(method, params)
        http.basic_authentication @user, @key if @key
        
        # somehow internal SimpleHttp's redirection following fails
        http.register_response_handler(Net::HTTPRedirection){|request, response, shttp| 
	 		SimpleHttp.get response['location'] 
	 	}
        http.get
    end

    def construct_url(method, params)
        #"/v2/#{method}?" + params.map{|k, v| "#{k}=#{v}"}.join('&')
        "http://friendfeed-api.com/v2/#{method}?" + params.map{|k, v| "#{k}=#{v}"}.join('&')
    end
    
    def self.extract_feed(options)
        frf = new(options[:login], options[:key])
        path = options[:path]
        indexes = options[:indexes]
        
        # extract userpic
        userpic = frf.userpic(options[:feed])
        File.write File.join(path, 'images', 'userpic.jpg'), userpic
        
        # extract entries
        s = 0
        page = 100
        while true
            data = frf.feed(options[:feed], :start => s, :num => page)
            break if data['entries'].empty?
            
            latest = nil
            data['entries'].each do |e|
                ename = e['url'].gsub("http://friendfeed.com/#{options[:feed]}/", '').gsub("/", '__')
                e['name'] = ename
                e['dateFriendly'] = parse_time(e['date']).strftime('%d %B %Y в %H:%M')
                (e['comments'] || []).each{|c| c['dateFriendly'] = parse_time(c['date']).strftime('%d %B %Y в %H:%M')}
                (e['likes'] || []).each{|c| c['dateFriendly'] = parse_time(c['date']).strftime('%d %B %Y в %H:%M')}
                e['likes'] && e['likes'] = e['likes'].sort_by{|l| l['date']}.reverse

                name = File.join(path, 'data', 'entries', ename + ".js")
                File.write(name, e.to_json)
                indexes.each{|i| i.put e}
                latest = e
            end
            #puts "Loaded %i entries, starting from %i" % [page, s]
            #puts latest['dateFriendly']
            
            s += page
            if s > 10_000
                #puts "10k entries limitation. That's all."
                break
            end
        end
    end
end
