require 'rubygems'
require 'bundler'
require 'sinatra'
require 'erector'
require 'erector/widgets/page'
require 'pp'
require 'json'
require 'oauth'
require 'oauth/consumer'

require './page'

class Rack::Request
  def site
    url = scheme + "://"
    url << host

    if scheme == "https" && port != 443 ||
        scheme == "http" && port != 80
      url << ":#{port}"
    end

    url
  end
end  

class Cohuman
  def self.credentials
    @credentials ||= if ENV['COHUMAN_API_KEY']
      {:key => ENV['COHUMAN_API_KEY'], :secret => ENV['COHUMAN_API_SECRET']}
    else
      begin
        here = File.expand_path(File.dirname(__FILE__))
        YAML.load( File.read( "#{here}/config/cohuman.yml") )
      rescue Errno::ENOENT
        nil
      end
    end
  end

  def self.consumer
    @consumer ||= OAuth::Consumer.new( credentials[:key], credentials[:secret], {
      :site => 'http://api.cohuman.com',
      :request_token_path => '/api/token/request',
      :authorize_path => '/api/authorize',
      :access_token_path => '/api/token/access'
      })
  end
  
  def self.api_url(path)
    path.gsub!(/^\//,'') # removes leading slash from path
    url = "http://api.cohuman.com/#{path}"
  end
  
end

def render_page(query = nil, result = nil)
  Page.new(:session => session, :request => request, :query => query, :result => result).to_html
end

enable :sessions

get "/" do
  render_page
end

get "/authorize" do
  if Cohuman.credentials
    request_token = Cohuman.consumer.get_request_token(:oauth_callback=>"#{request.site}/authorized")
    session[:request_token] = request_token
    redirect request_token.authorize_url
  else
    erector {
      h1 "Configuration error"
      ul {
        li {
          text "Please set the environment variables "
          code "COHUMAN_API_KEY"
          text " and " 
          code "COHUMAN_API_SECRET"
        }
        li {
          text " or create "
          code "config/cohuman.yml"
        }
      }
      p "For a Heroku app, do it like this:"
      pre <<-PRE
heroku config:add COHUMAN_API_KEY=asldjasldkjal
heroku config:add COHUMAN_API_SECRET=asdfasdfasdf
      PRE
    }
  end
end

get "/authorized" do
  request_token = session[:request_token]
  access_token = request_token.get_access_token
  session.delete :request_token  # comment this line out if you want to see the request token in the session table
  session[:access_token] = access_token
  redirect "/"
end

get "/logout" do
  if session[:access_token].nil?
    redirect "/"
    return
  end
  
  url = Cohuman.api_url("/logout")
  response = session[:access_token].post(url, {"Content-Type" => "application/json"})
  result = begin
    JSON.parse(response.body)
  rescue
    {
      :response => "#{response.code} #{response.message}",
      :headers => response.to_hash,
      :body => response.body
    }
  end
  
  session.delete(:access_token)
  session.delete(:request_token)

  render_page(url, result)
end

def get_and_render(path)
  url = Cohuman.api_url(path)
  response = session[:access_token].get(url, {"Content-Type" => "application/json"})
  result = JSON.parse(response.body)
  render_page(url, result)
end

get "/tasks" do
  get_and_render "/tasks"
end

get "/users" do
  get_and_render "/users?limit=0"
end

get "/projects" do
  get_and_render "/projects?limit=0"
end
