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
  needs :session, :request, :result => nil, :query => nil

  external :style, <<-CSS
  body { font-family:sans-serif;}
  table { border: 1px solid gray; border-spacing: 0; }
  td, th { 
    border: 1px solid gray; 
    padding: .5em .25em;
    vertical-align: top;
    text-align: left;
    max-width: 80em;
  }
  th { background: #ededed; }

  pre { margin: 0; 
    max-height: 20em; overflow-y: auto;
    max-width: 60em; overflow-x: auto;
    }
  CSS

  def page_title
    "Coho"
  end
  
  def logo
    img :src => "coho_salmon.jpg", :width => (831/2), :height => (347/2), :align=>"left"
    br; br; br
    h1 "Coho!"
    i do
      text "Swimming upstream in the "
      a "Cohuman API", :href => "http://developer.cohuman.com"
    end
    br :clear => true, :style => "clear:both;"
  end

  def body_content
    ribbon
    logo
    hr
    button_form "/authorize", "Sign In To Cohuman"
    if @session[:access_token]
      button_form "/logout", "Sign Out"
      button_form "/tasks", "List Tasks"
      button_form "/users", "List Users"
      button_form "/projects", "List Projects"
    end
    if @query or @result
      hr
      table do
        if @query
          tr do
            th "Query:"
            td { pre @query }
          end
        end
        if @result
          tr { th "Result", :colspan => 2 }
          tr { td(:colspan => 2) { pre {
            out = ""
            PP.pp(@result, out)
            text out
          } } }
        end
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
        th name, :colspan => 2
      end
      if hash.empty?
        td(:colspan => 2) {
          rawtext nbsp*5 
          text "[empty]"
          rawtext nbsp*5 
        }
      else
        hash.each_pair do |k,v|
          tr do
            td k.to_s
            td do
              if v
                pre do
                  out = ""
                  PP.pp(v, out)
                  text out
                end
              else
                rawtext nbsp
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
  
  # thanks to https://github.com/blog/273-github-ribbons
  def ribbon
    rawtext <<-HTML
    <a href="http://github.com/alexch/coho"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://assets1.github.com/img/7afbc8b248c68eb468279e8c17986ad46549fb71?repo=&url=http%3A%2F%2Fs3.amazonaws.com%2Fgithub%2Fribbons%2Fforkme_right_darkblue_121621.png&path=" alt="Fork me on GitHub"></a>
    HTML
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

def render_page(query = nil, result = nil)
  Page.new(:session => session, :request => request, :query => query, :result => result).to_html
end

enable :sessions

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

get "/logout" do
  if session[:access_token].nil?
    redirect "/"
    return
  end
  
  url = api_url("/logout")
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

def api_url(path)
  path.gsub!(/^\//,'') # removes leading slash from path
  url = "http://api.cohuman.com/#{path}"
end

def get_and_render(path)
  url = api_url(path)
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
