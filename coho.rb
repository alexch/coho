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
    h1 { 
      img :src => "coho_salmon.jpg", :width => (831/2), :height => (347/2)
      text "Coho!"
    }
    hr
    button_form "/authorize", "Sign In To Cohuman"
    if @session[:access_token]
      button_form "/clear", "Sign Out"
      button_form "/tasks", "List Tasks"
      button_form "/users", "List Users"
    end
    hr
    if @result
      h2 "Result"
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
          if v
            td do
              pre do
                out = ""
                PP.pp(v, out)
                text out
              end
            end
          end
        end
      end
    end
  end

  def button_form action, label
    form :action => action, :method => "get" do
      input :type=> :submit, :value => label
    end
  end
end

def credentials
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

def consumer
  @consumer ||= OAuth::Consumer.new( credentials[:key], credentials[:secret], {
    :site => 'http://api.cohuman.com',
    :request_token_path => '/api/token/request',
    :authorize_path => '/api/authorize',
    :access_token_path => '/api/token/access'
    })
end

def render_page(result = nil)
  Page.new(:session => session, :request => request, :result => result).to_html
end

enable :sessions, :logging

get "/" do
  render_page
end

get "/authorize" do
  if credentials
    request_token = consumer.get_request_token(:oauth_callback=>"#{request.site}/authorized")
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

get "/clear" do
  session.delete(:access_token)
  session.delete(:request_token)
  redirect "/"
end

def get_and_render(path)
  path.gsub!(/^\//,'') # removes leading slash from path
  url = "http://api.cohuman.com/#{path}"
  response = session[:access_token].get(url, {"Content-Type" => "application/json"})
  result = JSON.parse(response.body)
  render_page(result)
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
