require 'rubygems'
require 'sinatra'
require 'haml'
require 'archive/zip'
require 'logger'

require 'frf_client'

module Clio
	INDEXES = [Models::DateIndex, Models::HashtagIndex, Models::AllIndex]

	class App < Sinatra::Base
		BASE_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..'))
		RESULT_PATH = File.join(BASE_PATH, 'result')
		STATIC_PATH = File.join(BASE_PATH, 'templates')
		ARCHIVES_PATH = File.join(BASE_PATH, 'public', 'zip')

		def App.log; 
			@log ||= Logger.new(File.join(BASE_PATH, 'logs', 'clio.log'))
		end

        error do
            e = env['sinatra.error']
            App.log.error e.message + "\n\t" + e.backtrace.join("\n\t")

			haml :error
        end

		get '/' do
			haml :index
		end
		
		post '/' do
			user = params[:username]
			feed = params[:feed] || user
			key = params[:key]
		
			save_path = File.join(RESULT_PATH, user, feed)
			
			App.log.info "Starting to extract #{user}/#{feed}"

			# 1. extract feed, saving entry files and indexing entries to DB
			Models::Index.filter(:user => user, :feed => feed).delete
			indexes = INDEXES.map{|klass| klass.create(:user => user, :feed => feed, :created_at => Time.now)}

			App.log.info "#{user}/#{feed}: indexes created"

			FriendFeedClient.extract_feed(
				:login => user, 
				:key => key, 
				:feed => feed, 
				:path => save_path,
				:indexes => indexes)

			App.log.info "#{user}/#{feed}: feed extracted"

			# 2. save indexes to files
			Models::Index.filter(:user => user, :feed => feed).each do |idx|
				idx.to_file(File.join(save_path, 'data', 'indexes'))
			end
			
			App.log.info "#{user}/#{feed}: indexes saved"
			
			# 3. copy static content
			Dir[File.join(STATIC_PATH, '**', '*.*')].each do |src|
				tgt = src.sub(STATIC_PATH, save_path)
				FileUtils.makedirs File.dirname(tgt)
				FileUtils.cp src, tgt
			end

			App.log.info "#{user}/#{feed}: templates copied"
			
			# 4. zip
			random = (1..6).map{|i| rand(9)}.join
			Archive::Zip.archive(File.join(ARCHIVES_PATH, "#{feed}-#{random}.zip"), save_path)
			
			App.log.info "#{user}/#{feed}: results archived"

			# 5. show link to result
			@link = "/zip/#{feed}-#{random}.zip"
			haml :result
		end
	end
end
