require 'rubygems'
require 'bundler'
require 'sinatra'
require 'erector'
require 'erector/widgets/page'
require 'pp'
require 'json'
require 'oauth'
require 'oauth/consumer'

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

class Page < Erector::Widgets::Page
  needs :session, :request, :result => nil

  external :style, <<-CSS
  table { border: 1px solid gray; border-spacing: 0; }
  td, th { border-bottom: 1px solid gray; border-right: 1px solid gray; padding: 1px;}

  td pre { width: 50em;}
  td { overflow-x: auto; }
  CSS

  def page_title
    "Coho"
  end

  def body_content
    h1 "Coho!"
    hr
    login_form
    if @session[:access_token]
      button_form "/tasks", "Tasks"
    end
    hr
    if @result
      pre do
        out = ""
        PP.pp(@result, out)
        text out
      end
    end
    hr
    session_table
    hr
    env_table
    hr
  end

  def session_table
    hash_table("Session", @session)
  end

  def env_table
    hash_table "Rack Environment", @request.env
  end

  def hash_table(name, hash)
    table do
      tr do
        th name, :colspan=>2
      end
      hash.each_pair do |k,v|
        tr do
          td k.to_s
          td { pre v.inspect } if v
        end
      end
    end
  end

  def button_form action, label
    form :action => action, :method => "get" do
      input :type=> :submit, :value => label
    end
  end
  
  def login_form
    button_form "/authorize", "Sign In To Cohuman"
  end
end

def credentials
  if ENV['COHUMAN_API_KEY']
    {:key => ENV['COHUMAN_API_KEY'], :secret => ENV['COHUMAN_API_SECRET']}
  else
    here = File.expand_path(File.dirname(__FILE__))
    YAML.load( File.read( "#{here}/config/cohuman.yml") )
  end
end

def consumer
  @consumer ||= OAuth::Consumer.new( credentials[:key], credentials[:secret], {
    :site => 'http://api.cohuman.com',
    :request_token_path => '/api/token/request',
    :authorize_path => '/api/authorize',
    :access_token_path => '/api/token/access'
    })
end

enable :sessions, :logging

get "/" do
  Page.new(:session => session, :request => request).to_html
end

get "/authorize" do
  request_token = consumer.get_request_token(:oauth_callback=>"#{request.site}/authorized")
  session[:request_token] = request_token
  redirect request_token.authorize_url
end
    
get "/authorized" do
  request_token = session[:request_token]
  access_token = request_token.get_access_token
  # session[:request_token] = nil  # do this later, after we're more debugged
  session[:access_token] = access_token
  redirect "/"
end

get "/tasks" do
  response = session[:access_token].get("http://api.cohuman.com/tasks", {"Content-Type" => "application/json"})
  result = JSON.parse(response.body)
  Page.new(:session => session, :request => request, :result => result).to_html
end
